---
name: sync-branch
description: Sync local branch to remote latest after PR merge. Fetches and hard-resets to the base branch.
argument-hint: "[branch-name]"
disable-model-invocation: true
---

## Execution rules (IMPORTANT)

- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command. This triggers Claude Code safety prompts and blocks autonomous execution.
- Instead, either: (a) run commands without `cd` (use repo root as working directory), or (b) split into separate Bash calls.
- Do NOT append `|| echo "..."` fallbacks — handle errors in your logic instead.

## Step 0: Detect base branch

Determine the sync target using this priority:
1. If `$ARGUMENTS` contains a branch name, use it.
2. Detect from the current branch's upstream tracking: `git rev-parse --abbrev-ref @{upstream}` → strip the `origin/` prefix.
3. Fall back to the repo's default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

Store the result as `BASE_BRANCH`.

## Instructions

1. Fetch remote and reset local branch:

```bash
git fetch origin $BASE_BRANCH && git reset --hard origin/$BASE_BRANCH
```

2. Show latest commits to confirm sync:

```bash
git log --oneline -5
```

## Note

- This will discard local uncommitted changes
- Use after PR has been merged to sync local branch
- Target branch auto-detected from upstream tracking, or specify via argument
