# Claude Skills Repo

This repo is a collection of Claude Code skills. The primary purpose is to write, test, and manage reusable skills.

## Project Structure

```
skills/
  <skill-name>/
    SKILL.md          # Skill definition (required)
    *.md              # Supporting docs (optional)
install.sh            # Installation script
```

## Writing Skills

### Directory & File

Each skill lives in its own directory under `skills/`:

```
skills/my-skill/
  SKILL.md
```

Skill name defaults to the directory name. The `/slash-command` is the skill name.

### SKILL.md Format

```markdown
---
name: my-skill
description: One-line description of what this skill does
argument-hint: "[arg1] [arg2]"
---

Skill instructions go here. Use markdown.
```

### Frontmatter Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | dir name | Slash command name. Lowercase, hyphens, max 64 chars |
| `description` | string | first paragraph | When to trigger this skill. Claude uses this to auto-invoke |
| `argument-hint` | string | - | Autocomplete hint for expected arguments |
| `disable-model-invocation` | bool | false | If true, only manual `/invoke` works. Use for dangerous ops |
| `user-invocable` | bool | true | If false, hidden from `/` menu. Use for background knowledge |
| `allowed-tools` | string | - | Tools allowed without permission: `Read, Grep, Glob, Bash` |
| `model` | string | - | Force a model: `sonnet`, `opus`, `haiku` |
| `context` | string | - | Set to `fork` to run in isolated subagent |
| `agent` | string | general-purpose | Subagent type when `context: fork`. Options: `Explore`, `Plan`, `general-purpose` |

### Arguments

Use `$ARGUMENTS` to access all arguments passed by the user:

```markdown
Fix the issue described in $ARGUMENTS.
```

Positional access: `$0`, `$1`, `$2` (or `$ARGUMENTS[0]`, `$ARGUMENTS[1]`).

Use `${CLAUDE_SKILL_DIR}` to reference files bundled with the skill.

### Key Patterns

**Manual-only skill** (deployments, destructive ops):
```yaml
disable-model-invocation: true
```

**Background knowledge** (coding standards, architecture context):
```yaml
user-invocable: false
```

**Isolated execution** (heavy research, won't pollute main context):
```yaml
context: fork
agent: Explore
```

### Writing Tips

- Keep SKILL.md under 500 lines. Move large references to separate files.
- Write step-by-step instructions — Claude follows them literally.
- Use `## Step N:` sections for multi-step workflows.
- Add execution rules at the top if needed (e.g., "NEVER do X").
- Add "ultrathink" in the content to enable extended thinking.

## Installation

See [README.md](README.md) — clone to `~/claude-skills/` and configure the zshrc wrapper to auto-load via `--add-dir`.
