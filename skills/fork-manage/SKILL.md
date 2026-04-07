---
name: fork-manage
description: Setup and manage forked repos. Init fork structure (symlink + remotes), sync upstream, or submit PR to upstream. Use when asked to "setup fork", "sync upstream", "fork manage", or "submit upstream PR".
argument-hint: "<init|sync|pr> [repo-path] [options]"
disable-model-invocation: true
---

## Execution rules (IMPORTANT)

- NEVER combine `cd` with output redirections (`2>/dev/null`, `>/dev/null`, `| ...`) in a single compound bash command.
- Instead, either: (a) run commands without `cd` (use absolute paths), or (b) split into separate Bash calls.

## Overview

Manages forked repos with this structure:

```
remotes:
  upstream → original repo (read-only)
  origin   → user's fork (read/write)

branches:
  main       ← user's working branch, free development + upstream sync via rebase
  fix/xxx    ← clean PR branches from upstream/main (temporary)
```

Core principle: **user's main is the source of truth**. Upstream changes are rebased under user's commits.

## Step 0: Parse command

Extract the subcommand from `$ARGUMENTS`:
- `init` → go to Step 1 (first-time setup)
- `sync` → go to Step 2 (sync upstream)
- `pr` → go to Step 3 (submit PR to upstream)
- No argument → ask user which operation

## Step 1: Init — First-time fork setup

### Step 1.1: Detect repo

If a repo path is provided in `$ARGUMENTS`, use it. Otherwise use the current working directory.
Verify it's a git repo with a remote.

### Step 1.2: Detect remotes

Read current remotes (`git remote -v`). Determine:
- Which remote points to the **original/upstream** repo (usually `origin` after a fresh clone)
- Which remote points to the **user's fork**

If only one remote exists (the upstream), ask: "What is your fork URL? (e.g. github.com/yourname/repo)"

### Step 1.3: Configure remotes

Ensure remotes are named correctly:
```bash
# upstream = original repo (read-only source)
# origin = user's fork (push target)
```

If the current `origin` points to upstream, rename it:
```bash
git remote rename origin upstream
git remote add origin <user-fork-url>
```

### Step 1.4: Local install — make local edits take effect immediately

Detect the project type and install/link the local repo so changes are live:

**Detection order (check these in sequence, use first match):**

1. **npm package** — `package.json` exists with `name` field and `bin` or `main`
   ```bash
   npm link
   ```

2. **Python package** — `setup.py`, `setup.cfg`, or `pyproject.toml` exists
   ```bash
   pip install -e .
   ```

3. **bb-browser sites** — repo contains adapter JS files with `/* @meta` blocks (matches bb-sites structure)
   ```bash
   # Replace ~/.bb-browser/bb-sites/ with symlink to local repo
   mv ~/.bb-browser/bb-sites ~/.bb-browser/bb-sites-upstream-bak
   ln -s <repo-path> ~/.bb-browser/bb-sites
   ```

4. **Generic data directory** — if the upstream repo's README or install docs mention a known data path (e.g. `~/.config/<tool>/`, `~/.local/share/<tool>/`), symlink that path to the local repo.

5. **No match** — ask user: "How does this tool consume this repo? (provide install command or target path, or skip)"

After install, verify the tool reads from local code (e.g. run a command and confirm output).

### Step 1.5: Verify

```bash
git remote -v
git branch -vv
```

Print summary of configured remotes and branches.

## Step 2: Sync — Rebase onto latest upstream

### Step 2.1: Fetch upstream

```bash
git fetch upstream
```

### Step 2.2: Rebase

```bash
git rebase upstream/main
```

If conflicts occur:
1. For each conflicting file, read the conflict markers
2. Resolve by keeping both sides' changes where possible
3. `git add` resolved files, `git rebase --continue`
4. Report what was resolved

### Step 2.3: Push

```bash
git push origin main --force-with-lease
```

### Step 2.4: Summary

Show `git log --oneline upstream/main..main` to display user's custom commits on top of upstream.

## Step 3: PR — Submit changes to upstream

### Step 3.1: Determine what to PR

Ask user: "Which changes to PR? Options:"
- `all` — all commits on main not in upstream
- `pick` — let user choose specific commits
- Or user can describe the change

### Step 3.2: Create clean PR branch

```bash
git fetch upstream
git checkout -b fix/<descriptive-name> upstream/main
```

### Step 3.3: Apply changes

Cherry-pick the selected commits onto the clean branch:
```bash
git cherry-pick <commit-hash>
```

Or if user described a change, make the modification directly.

### Step 3.4: Push and create PR

```bash
git push -u origin fix/<descriptive-name>
```

Detect upstream repo from the `upstream` remote URL, then:
```bash
gh pr create --repo <upstream-owner/repo> --head <fork-owner>:fix/<descriptive-name> --title "<title>" --body "<body>"
```

### Step 3.5: Return to main

```bash
git checkout main
```

Print the PR URL.

## Notes

- `main` is the user's development branch — free to commit anything
- `upstream/main` is the reference point for syncing
- PR branches are temporary — delete after merge/close
- After upstream merges a PR, next `sync` will automatically absorb it (rebase drops duplicate commits)
