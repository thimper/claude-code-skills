---
name: gh-pr
description: Create a PR targeting the auto-detected base branch, with optional issue linking and automatic review monitoring.
argument-hint: "[issue-numbers] [optional-context]"
disable-model-invocation: true
---

## Execution rules (IMPORTANT)

- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command. This triggers Claude Code safety prompts and blocks autonomous execution.
- Instead, either: (a) run commands without `cd` (use repo root as working directory), or (b) split into separate Bash calls.
- Do NOT append `|| echo "..."` fallbacks — handle errors in your logic instead.

## Step 0: Detect base branch

Determine the PR target branch using this priority:
1. If `$ARGUMENTS` contains `--base <branch>`, use that branch and remove it from arguments.
2. Read `.claude/workspace.json` → use `base_branch` field if it exists.
3. Detect by git history — find which remote branch the current branch was forked from:
   - Run `git fetch --all` first.
   - For each remote branch (`git branch -r --format='%(refname:short)' | grep '^origin/' | grep -v HEAD`), skip the current branch's own remote (e.g. skip `origin/feat/foo` if current branch is `feat/foo`).
   - Compute `git merge-base HEAD <remote-branch>` for each candidate.
   - Pick the remote branch whose merge-base commit is closest to HEAD (i.e. has the fewest commits between merge-base and HEAD, computed via `git rev-list --count <merge-base>..HEAD`).
   - Strip the `origin/` prefix and use it as the base branch.
4. Fall back to the repo's default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

Store the result as `BASE_BRANCH` for all subsequent steps.

## Step 1: Parse arguments

Parse the remaining arguments — extract any numbers (separated by spaces, commas, or both) as GitHub issue numbers. Everything else is optional context.
- If NO issue numbers were provided, ask: "Link issue numbers? (enter numbers, or press enter to skip)"
  - If user provides numbers, use them as issue numbers.
  - If user presses enter / says no / says skip, continue without issue numbers.

## Step 2: Check uncommitted changes

Check if there are uncommitted changes (`git status`).
- If there are staged or unstaged tracked file changes, or untracked files that look project-relevant: list them and ask "Commit these changes first? (y/n)"
  - If yes: stage the relevant files, commit (ask for commit message or auto-generate), then continue.
  - If no: continue without committing.

## Step 3: Rebase onto the base branch before pushing

- Run `git fetch origin $BASE_BRANCH`
- Run `git rebase origin/$BASE_BRANCH`
- **If there are conflicts:** Automatically resolve them following these rules:
  1. For each conflicting file, read the full conflict markers carefully.
  2. **Keep ALL changes from both sides** — merge both the base branch changes and the current branch changes together. Never discard either side's code.
  3. If both sides modified the same lines, integrate both changes logically (e.g. keep both new functions, combine both modifications). When in doubt, keep both versions.
  4. After resolving each file, `git add` it, then `git rebase --continue`.
  5. Repeat until the rebase completes.
  6. After all conflicts are resolved, briefly list what was merged (files and summary) so I can verify.
- **If successful (no conflicts):** Continue to Step 4.

## Step 4: Push

Execute `git push origin HEAD --force-with-lease` to ensure remote has the latest rebased code.

## Step 5: Generate PR content

Analyze the differences between the current branch and `$BASE_BRANCH` (using `git log` and `git diff`).
- Based on this, generate a concise **Title** and a Markdown **Body** (bullet points of changes).
- If issue numbers were provided, append a "## Related Issues" section at the end of the Body:
  ```
  ## Related Issues
  Related to #12
  Related to #34
  ```
  Use `Related to #N` (not `Closes`/`Fixes`) — only reference the issues, do NOT auto-close them.

## Step 6: Create PR

Directly create the PR (no confirmation needed):
```
gh pr create --base $BASE_BRANCH --title "<TITLE>" --body "<BODY>"
```

## Step 7: Start monitoring

After the PR is created successfully, capture the PR number from the output. Then immediately start autonomous monitoring:

> PR #<NUMBER> created, starting auto review-monitor mode...

Invoke `/loop 1m /gh-pr-watch <NUMBER>` to begin the autonomous review-fix-reply loop. This will poll every 1 minute, automatically fix review comments, push commits, reply to reviewers, and stop when the PR is merged or closed.
