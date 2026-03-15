---
name: gh-pr-watch
description: Auto-monitor a PR, fix review comments, push fixes, and reply to reviewers. Use with `/loop 1m /gh-pr-watch` for continuous monitoring.
argument-hint: "[PR_NUMBER]"
disable-model-invocation: true
---

## Execution rules (IMPORTANT)

- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command. This triggers Claude Code safety prompts and blocks autonomous execution.
- Instead, either: (a) run commands without `cd` (use repo root as working directory), or (b) split into separate Bash calls.
- Do NOT append `|| echo "..."` fallbacks — handle errors in your logic instead.

## Step 1: Determine PR number

- If `$ARGUMENTS` contains a number, use it as the PR number.
- Otherwise, detect from current branch: `gh pr view --json number -q .number`
- If no PR found, stop and report error.

## Step 2: Check PR state

Run: `gh pr view <PR#> --json state,url,title,mergedAt -q '{state: .state, url: .url, title: .title}'`

- If `MERGED`:
  1. Print "PR #<N> merged!"
  2. Clean up branches:
     - Get the merged branch name: `gh pr view <PR#> --json headRefName -q .headRefName`
     - Get the base branch name: `gh pr view <PR#> --json baseRefName -q .baseRefName`
     - Switch to the base branch: `git checkout <base-branch> && git pull origin <base-branch>`
       - If checkout fails due to untracked files conflicting, temporarily move them to `/tmp/backup-scripts/`, complete checkout+pull, then copy them back.
     - Delete the local branch: `git branch -d <branch-name>` (use `-D` if `-d` fails)
     - Delete the remote branch: `git push origin --delete <branch-name>`
     - Print "Cleaned up local and remote branch: <branch-name>"
  3. Use `CronList` to find the scheduled task for this watch, and `CronDelete` to remove it. Done.
- If `CLOSED`: print "PR #<N> closed", then use `CronList` to find the scheduled task for this watch, and `CronDelete` to remove it. Done.
- If `OPEN`: continue to next step.

## Step 3: Fetch all comments and reviews

Run these commands to gather feedback:
```bash
# Inline review comments (on specific lines of code)
gh api repos/{owner}/{repo}/pulls/<PR#>/comments --jq '.[] | {id, body, path, line, original_line, diff_hunk, created_at, user: .user.login, in_reply_to_id}'

# Top-level reviews (APPROVED, CHANGES_REQUESTED, COMMENTED)
gh api repos/{owner}/{repo}/pulls/<PR#>/reviews --jq '.[] | {id, body, state, user: .user.login, submitted_at: .submitted_at}'

# General PR conversation comments
gh pr view <PR#> --json comments --jq '.comments[] | {id: .id, body: .body, author: .author.login, createdAt: .createdAt}'
```

Get the current git user: `gh api user --jq .login`

Filter out:
- Comments authored by yourself (the bot/current user)
- Comments that have already been addressed (check if there's a reply from you containing "Fixed in" or "fixed" below the comment)

Track which comments are new vs already processed by checking your existing replies.

### 3.1: Parse review checklist

Scan all review comment bodies (especially top-level reviews) for a `CHECKLIST` block. The format is:
```
CHECKLIST
<item>: PASS - <description>
<item>: FAIL - <description>
<item>: N/A - <description>
```

Extract all items with `FAIL` status. Each FAIL item has:
- **item name** (e.g. `tests`, `safety`, `security`, `correctness`, `concurrency`, `memory`, `performance`, `parity`)
- **failure description** (the text after `FAIL - `)

These FAIL items are treated as actionable tasks with the same priority as review comments — they MUST be addressed.

## Step 4: Analyze actionable feedback

**ALL review comments must be processed — nothing is skipped.**

Categorize each new comment/review:

### Category A — Direct code fixes (auto-fixable)
- GitHub `suggestion` code blocks → apply the exact suggestion
- "rename X to Y", "change X to Y", "typo: X should be Y"
- "remove this line", "delete this", "unused import"
- "add missing X" with clear specification
- Review state `CHANGES_REQUESTED` with specific instructions
- Inline comments pointing to specific file:line with clear ask

### Category B — Requires analysis (fixable with thought)
- "this could cause a bug because..." → read context, understand issue, fix
- "handle the case where..." → add missing logic
- "this is inefficient" → optimize the specific code
- Performance, security, or correctness concerns with enough context to act
- **Code issues in files NOT in the PR diff** — if the reviewer points out a real bug or improvement in related code, fix it in this PR too. Do not dismiss with "not in scope".

### Category C — Verification or discussion (respond substantively)
- If the reviewer claims code is wrong → **verify against SDK docs, official headers, or authoritative sources** before responding. Reply with concrete evidence (file paths, code snippets, official definitions).
- Questions like "why did you choose X?" → provide a substantive technical explanation, not just "noted".
- Architectural or design discussions → give your technical analysis and recommendation.

### Category D — Checklist FAIL items
Items from the review checklist (Step 3.1) with `FAIL` status. These require concrete fixes:
- `tests: FAIL` → add or update tests covering the changed code paths
- `safety: FAIL` → fix fail-open paths, add guards, ensure fail-closed behavior
- `security: FAIL` → fix injection, auth, crypto, or other security regressions
- `correctness: FAIL` → fix logic errors, edge cases, or wrong behavior
- `concurrency: FAIL` → fix race conditions, shared-state hazards
- `memory: FAIL` → fix leaks, unbounded growth, missing cleanup
- `performance: FAIL` → fix unbounded latency, CPU waste, or resource issues
- `parity: FAIL` → fix behavioral inconsistencies between old and new code
- Other FAIL items → read the failure description and fix accordingly

**Checklist FAIL items are NOT optional.** The PR cannot pass the policy gate until all FAIL items are resolved. Treat them with the same urgency as `CHANGES_REQUESTED` reviews.

**No comment should ever receive a dismissive "skip" reply. Every comment gets either a code fix or a substantive evidence-based response.**

## Step 5: Fix code

For each actionable item (Category A, B, and D):

1. **Read** the relevant file(s) to understand full context
2. **Analyze** what needs to change — consider side effects
3. **Apply** the fix using Edit tool
4. **Verify** the change makes sense in context (read surrounding code)
5. Stage and commit:
   ```bash
   git add <specific-files>
   git commit -m "fix: <brief description of what was fixed>"
   ```

Rules:
- One commit per logical fix (batch related small fixes together)
- NEVER amend commits, NEVER skip hooks, NEVER force push
- If a fix is risky or unclear, skip it and flag it for human review
- If fixing requires changes across multiple files, make sure all related changes are in one commit
- Run any quick validation if applicable (e.g., syntax check, type check)

## Step 6: Push all fixes

After all fixes are committed:
```bash
git push origin HEAD
```

If push fails due to remote changes:
```bash
git pull --rebase origin HEAD && git push origin HEAD
```

If rebase conflicts occur, STOP and report — never force push.

## Step 7: Reply to reviewers

For each fixed comment, reply on the PR so the reviewer knows it's addressed:

**For inline review comments** (has `path` and `line`):
```bash
gh api repos/{owner}/{repo}/pulls/<PR#>/comments/<comment_id>/replies -f body="Fixed (<short-sha>): <one-line description>"
```

**For top-level review with CHANGES_REQUESTED**:
```bash
gh pr comment <PR#> --body "Review comments addressed, fixes pushed:
$(git log --oneline -<N> | head -<N>)

Please re-review."
```

**For general conversation comments**:
```bash
gh pr comment <PR#> --body "Fixed (<short-sha>): <one-line description>"
```

**For Category C (verification/discussion) comments** — reply with evidence:
```bash
gh pr comment <PR#> --body "<substantive response with evidence: SDK references, file paths, code snippets, or technical analysis>"
```

**For Category D (checklist FAIL items)** — reply with a summary of all checklist fixes:
```bash
gh pr comment <PR#> --body "Checklist FAIL items fixed:

$(for each fixed FAIL item:)
- **<item>**: <one-line description of fix> (<short-sha>)

Please re-review."
```

## Step 8: Print status and exit

Print a concise status line:
```
[PR Watch #<N>] <X> comments processed | <Y> fixes pushed | <Z> replied with evidence | checklist: <F> FAIL fixed | waiting for next review...
```

Or if nothing new:
```
[PR Watch #<N>] no new comments | waiting...
```

Then exit this iteration. The `/loop` will re-invoke after the configured interval.
