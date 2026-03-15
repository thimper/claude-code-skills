---
name: new-branch
description: Create a new git branch from the base branch with smart naming suggestions.
argument-hint: "<description>"
disable-model-invocation: true
---

## Execution rules (IMPORTANT)

- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command. This triggers Claude Code safety prompts and blocks autonomous execution.
- Instead, either: (a) run commands without `cd` (use repo root as working directory), or (b) split into separate Bash calls.
- Do NOT append `|| echo "..."` fallbacks — handle errors in your logic instead.

## Step 1: Analyze requirement

Analyze the user's input arguments as the "Requirement".
- If input is empty, ask for requirement first.

## Step 2: Propose branch names

Based on the requirement, IMMEDIATELY propose 3 distinct, kebab-case branch names (e.g., `feat/...`, `fix/...`).

## Step 3: Let user choose

Ask me to pick a number (1-3) OR type a custom name.

## Step 4: Create branch

Once I reply with a selection or name:
- Determine the base branch using this priority:
  1. If `$ARGUMENTS` contains `--base <branch>`, use it.
  2. Read `.claude/workspace.json` → use `base_branch` field if it exists.
  3. If neither exists:
     - Run `git fetch --all` then `git branch -r --list 'origin/*' --format='%(refname:short)' | sed 's|origin/||' | head -20` to list remote branches.
     - Present the branches as a numbered list and ask: "Default base branch? Pick a number or type branch name:"
     - Save the answer to `.claude/workspace.json` as `{"base_branch": "<answer>"}`.
- Run `git fetch origin <BASE_BRANCH>`
- Run `git checkout -b <FINAL_BRANCH_NAME> origin/<BASE_BRANCH>`
- This automatically sets the upstream tracking, so downstream skills (`/gh-pr`, `/rebase-api`, `/sync-branch`) can auto-detect the base branch.
