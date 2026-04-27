---
name: sessions
description: Browse and search Claude Code conversation history, then resume a selected session.
argument-hint: "[--all] [--limit N] [--search keyword] [--date YYYY-MM-DD]"
---

List Claude Code conversation history and help resume a specific session.

Run the session browser script:

```bash
python3 "${CLAUDE_SKILL_DIR}/claude-sessions.py" $ARGUMENTS
```

IMPORTANT: After running the script, reformat the output as a markdown table with these columns:

| Time | Topic | Session ID | Msgs |

- Time: convert the date to relative time like "5m ago", "2h ago", "1d ago", "3d ago"
- Topic: from the script "first message" field, keep it short and meaningful
- Session ID: full ID, wrap in backticks for easy copy
- Msgs: message count

Do NOT include a row number / sequence column.

Then add a reminder line: `claude --resume <id>`

Available flags: `--all` `--limit N` `--search "keyword"` `--project name` `--date YYYY-MM-DD` `--full <id>`
