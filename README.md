# Claude Code Git Skills

A collection of Claude Code skills that automate common git workflows.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **new-branch** | `/new-branch <description>` | Create a new branch from base with smart naming suggestions |
| **gh-pr** | `/gh-pr [issue-numbers]` | Create a PR with auto-detected base branch, optional issue linking, and auto review monitoring |
| **gh-pr-watch** | `/gh-pr-watch [PR_NUMBER]` | Auto-monitor a PR: fix review comments, push fixes, reply to reviewers |
| **rebase-api** | `/rebase-api [branch]` | Rebase onto base branch with automatic conflict resolution |
| **sync-branch** | `/sync-branch [branch]` | Sync local branch to remote latest after PR merge |

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- Git configured with your user info

## Installation

### Quick Install

```bash
./install.sh
```

### Manual Install

Copy (or symlink) the `skills/` directory into your global Claude Code config:

```bash
# Create the global skills directory if needed
mkdir -p ~/.claude/skills

# Symlink each skill
for skill in skills/*/; do
  skill_name=$(basename "$skill")
  ln -sf "$(pwd)/$skill" ~/.claude/skills/"$skill_name"
done
```

After installation, restart Claude Code. The skills will be available as slash commands in any project.

### Per-Project Install

To install skills for a specific project only:

```bash
mkdir -p /path/to/your-project/.claude/skills
for skill in skills/*/; do
  skill_name=$(basename "$skill")
  ln -sf "$(cd && pwd)/Documents/developer/code/claude-skills/$skill" /path/to/your-project/.claude/skills/"$skill_name"
done
```

## Usage

Inside Claude Code, type `/` to see available skills, or invoke directly:

```
/new-branch add user authentication
/gh-pr 42 implement login flow
/rebase-api
/sync-branch
```

## Workflow Example

A typical feature development flow:

1. `/new-branch add-payment-api` - create a feature branch
2. _(write code)_
3. `/gh-pr 15,23` - create PR linked to issues #15 and #23, auto-starts review monitoring
4. `/gh-pr-watch` runs automatically via `/loop`, fixing review comments and replying
5. After merge, `/sync-branch` to reset local to latest

## Uninstall

```bash
./install.sh --uninstall
```

Or manually remove the symlinks:

```bash
for skill in skills/*/; do
  rm -f ~/.claude/skills/$(basename "$skill")
done
```
