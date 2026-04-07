---
name: gh-pr-watch
description: Monitor a PR for new review comments and merge-gate blockers. When actionable feedback is found, delegate to /codex:rescue for fixing. Use with `/loop 1m /gh-pr-watch` for continuous monitoring.
argument-hint: "[PR_NUMBER]"
disable-model-invocation: false
---

## Execution rules (IMPORTANT)

- This skill is a **monitor only**. It detects new review feedback and merge-gate blockers, then hands off to `codex exec` for fixing. It does NOT fix code itself.
- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command.
- Do NOT append `|| echo "..."` fallbacks — handle errors in your logic instead.

## Step 1: Determine PR number

- If `$ARGUMENTS` contains a number, use it as the PR number.
- Otherwise, detect from current branch: `gh pr view --json number -q .number`
- If no PR found, stop and report error.

## Step 1.5: (reserved, no action needed)

## Step 2: Check PR state and merge gates

Run: `gh pr view <PR#> --json state,url,title,mergedAt,isDraft,reviewDecision,mergeable,mergeStateStatus,statusCheckRollup,headRefOid -q '{state: .state, url: .url, title: .title, isDraft: .isDraft, reviewDecision: .reviewDecision, mergeable: .mergeable, mergeStateStatus: .mergeStateStatus, headRefOid: .headRefOid, statusCheckRollup: .statusCheckRollup}'`

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

For open PRs, record these merge-gate signals for delegation:
- `headRefOid`
- `isDraft`
- `reviewDecision`
- `mergeable`
- `mergeStateStatus`
- `statusCheckRollup`

Treat these as actionable gate blockers:
- Any failed/error/cancelled/timed_out/action-required check result in `statusCheckRollup`
- Any required check that remains blocked with clear evidence it needs intervention
- `reviewDecision: CHANGES_REQUESTED`
- A non-clean merge gate state such as `BLOCKED`, `DIRTY`, `BEHIND`, `UNKNOWN`, or any value that clearly means the PR cannot merge yet

Do not treat checks that are merely still running as actionable feedback by themselves. Those should be observed, not delegated.
Do not delegate on `isDraft: true` alone. Record it as context for Codex only when another actionable blocker already exists.

## Step 3: Fetch comments, reviews, and gate evidence (detection only)

Run these commands to gather feedback:
```bash
# Get repo owner/name
gh repo view --json owner,name -q '{owner: .owner.login, name: .name}'

# Inline review comments (on specific lines of code)
gh api 'repos/{owner}/{repo}/pulls/<PR#>/comments?per_page=100' --paginate --jq '.[] | {id, body, path, line, original_line, diff_hunk, created_at, user: .user.login, in_reply_to_id}'

# Top-level reviews (APPROVED, CHANGES_REQUESTED, COMMENTED)
gh api 'repos/{owner}/{repo}/pulls/<PR#>/reviews?per_page=100' --paginate --jq '.[] | {id, body, state, user: .user.login, submitted_at: .submitted_at}'

# General PR conversation comments
gh api 'repos/{owner}/{repo}/issues/<PR#>/comments?per_page=100' --paginate --jq '.[] | {id, body, author: .user.login, createdAt: .created_at}'
```

Get the current git user: `gh api user --jq .login`

Important pagination rule:
- Never trust the default first page for reviews/comments. GitHub often returns only 30 items by default.
- Always fetch all pages first, then sort by timestamp before deciding whether new feedback exists.
- Use `submitted_at` for reviews, `created_at` for inline comments, and `createdAt` for PR conversation comments.
- If you only need the newest review for a quick check, still use `--paginate`, for example:

```bash
gh api 'repos/{owner}/{repo}/pulls/<PR#>/reviews?per_page=100' --paginate \
  --jq 'sort_by(.submitted_at) | last | {id, state, submitted_at, user: .user.login}'
```

Filter out:
- Comments authored by yourself (the bot/current user)
- Comments that have already been addressed (check if there's a reply from you containing "Fixed in" or "fixed" below the comment)

Count how many **new, unaddressed** comments/reviews exist.

Also determine whether there are actionable gate blockers from Step 2.

## Step 4: Decide — delegate or wait

### If new feedback or actionable gate blockers found → delegate to /codex:rescue

Invoke the `/codex:rescue` skill with a prompt that includes the PR number and a summary of the review feedback to fix. For example:

```
/codex:rescue PR #<PR#> 收到 review 反馈需要修复：<summary of findings>。请修复代码、提交、push，然后回复 reviewer。
```

After invoking, print:
```
[PR Watch #<N>] <X> new comments detected | <G> actionable gate blockers detected | delegated to /codex:rescue for fix cycle | waiting for next interval...
```

### If no new feedback or actionable gate blockers → wait

Print:
```
[PR Watch #<N>] no new comments or actionable gate blockers | waiting...
```

Then exit this iteration. The `/loop` will re-invoke after the configured interval.
