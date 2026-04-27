#!/usr/bin/env python3
"""Browse Claude Code conversation history.

Parses ~/.claude/history.jsonl and project conversation files to list,
search, and inspect past sessions.

Usage:
  claude-sessions.py                          # recent 20 for current project
  claude-sessions.py --all                    # all projects
  claude-sessions.py --limit 50              # more results
  claude-sessions.py --search "OTA"          # keyword search
  claude-sessions.py --project life-companion # filter project
  claude-sessions.py --date 2026-04-07       # filter by date
  claude-sessions.py --full <sessionId>      # show all messages in session
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
HISTORY_FILE = CLAUDE_DIR / "history.jsonl"
PROJECTS_DIR = CLAUDE_DIR / "projects"


def load_history():
    """Load all entries from history.jsonl, grouped by sessionId."""
    sessions = defaultdict(list)
    if not HISTORY_FILE.exists():
        return sessions
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            sid = entry.get("sessionId")
            if not sid:
                continue
            sessions[sid].append(entry)
    return sessions


def session_summary(sid, entries):
    """Build a summary dict for one session."""
    entries.sort(key=lambda e: e.get("timestamp", 0))

    project_raw = entries[0].get("project", "")
    project_name = os.path.basename(project_raw) if project_raw else "unknown"

    # Collect user messages (the 'display' field)
    messages = []
    for e in entries:
        disp = e.get("display", "").strip()
        if disp and not disp.startswith("/clear"):
            messages.append(disp)

    first_msg = messages[0] if messages else "(no message)"
    # Truncate first message for display
    first_line = first_msg.split("\n")[0][:80]

    ts_first = entries[0].get("timestamp", 0) / 1000
    ts_last = entries[-1].get("timestamp", 0) / 1000
    dt_first = datetime.fromtimestamp(ts_first) if ts_first else None
    dt_last = datetime.fromtimestamp(ts_last) if ts_last else None

    return {
        "sessionId": sid,
        "project": project_name,
        "project_full": project_raw,
        "first_msg": first_line,
        "all_messages": messages,
        "msg_count": len(entries),
        "dt_first": dt_first,
        "dt_last": dt_last,
        "ts_last": ts_last,
    }


def make_topic(messages):
    """Generate a short topic/name from the first meaningful user message."""
    # First pass: skip trivial messages (greetings, short slash commands)
    trivial = {"你好", "hi", "hello", "hey", "test", "ok", "好的", "嗯"}
    for msg in messages:
        stripped = msg.strip()
        if stripped.lower() in trivial:
            continue
        if stripped.startswith("/") and len(stripped) < 20:
            continue
        if stripped.startswith("/clear"):
            continue
        line = stripped.split("\n")[0].strip()
        if len(line) > 60:
            line = line[:57] + "..."
        return line
    # Fallback: return first message even if trivial
    if messages:
        return messages[0].split("\n")[0][:60]
    return "(empty)"


def format_table(summaries):
    """Format summaries as a compact, copy-friendly list."""
    if not summaries:
        print("No sessions found.")
        return

    lines = []
    for i, s in enumerate(summaries, 1):
        dt = s["dt_last"].strftime("%m-%d %H:%M") if s["dt_last"] else "?"
        topic = make_topic(s["all_messages"])
        sid = s["sessionId"]
        proj = s["project"]
        lines.append(f"  {i:>2}. [{dt}] {topic}")
        lines.append(f"      id: {sid}  ({s['msg_count']} msgs, {proj})")

    print("\n".join(lines))
    print(f"\n  Total: {len(summaries)} sessions")
    print(f"  Resume: claude --resume <id>")


def show_full(sid, sessions):
    """Show all messages for a specific session."""
    entries = sessions.get(sid)
    if not entries:
        # Try partial match
        matches = [k for k in sessions if k.startswith(sid)]
        if len(matches) == 1:
            entries = sessions[matches[0]]
            sid = matches[0]
        else:
            print(f"Session {sid} not found.")
            return

    entries.sort(key=lambda e: e.get("timestamp", 0))
    print(f"Session: {sid}")
    print(f"Project: {entries[0].get('project', '?')}")
    print(f"Messages: {len(entries)}")
    print("-" * 80)

    for e in entries:
        ts = e.get("timestamp", 0) / 1000
        dt = datetime.fromtimestamp(ts).strftime("%H:%M:%S") if ts else "?"
        disp = e.get("display", "").strip()
        if disp:
            # Indent multi-line messages
            disp_lines = disp.split("\n")
            first = disp_lines[0][:120]
            print(f"  [{dt}] {first}")
            for extra in disp_lines[1:5]:
                print(f"           {extra[:120]}")
            if len(disp_lines) > 5:
                print(f"           ... ({len(disp_lines) - 5} more lines)")


def main():
    parser = argparse.ArgumentParser(description="Browse Claude Code sessions")
    parser.add_argument("--all", action="store_true", help="Show all projects")
    parser.add_argument("--limit", type=int, default=20, help="Max results (default 20)")
    parser.add_argument("--search", type=str, help="Search messages by keyword")
    parser.add_argument("--project", type=str, help="Filter by project name substring")
    parser.add_argument("--date", type=str, help="Filter by date (YYYY-MM-DD or YYYY-MM)")
    parser.add_argument("--full", type=str, help="Show all messages for a session ID")
    parser.add_argument("--cwd", type=str, default=os.getcwd(), help="Current working directory (auto-detected)")

    args = parser.parse_args()

    sessions = load_history()
    if not sessions:
        print("No history found.")
        sys.exit(1)

    # --full mode
    if args.full:
        show_full(args.full, sessions)
        return

    # Build summaries
    summaries = []
    for sid, entries in sessions.items():
        summaries.append(session_summary(sid, entries))

    # Filter by project
    if not args.all and not args.project:
        # Default: filter to current project directory
        cwd = args.cwd
        summaries = [s for s in summaries if s["project_full"] and cwd.endswith(s["project"].replace("-", "/").lstrip("/"))]
        if not summaries:
            # Fallback: match by directory basename
            basename = os.path.basename(args.cwd)
            summaries_all = [session_summary(sid, entries) for sid, entries in sessions.items()]
            summaries = [s for s in summaries_all if basename in s["project"]]

    if args.project:
        summaries = [s for s in summaries if args.project.lower() in s["project"].lower() or args.project.lower() in s["project_full"].lower()]

    # Filter by date
    if args.date:
        summaries = [s for s in summaries if s["dt_last"] and s["dt_last"].strftime("%Y-%m-%d").startswith(args.date)]

    # Filter by search keyword
    if args.search:
        keyword = args.search.lower()
        filtered = []
        for s in summaries:
            if any(keyword in m.lower() for m in s["all_messages"]):
                filtered.append(s)
        summaries = filtered

    # Sort by last active (newest first)
    summaries.sort(key=lambda s: s["ts_last"] or 0, reverse=True)

    # Limit
    summaries = summaries[: args.limit]

    format_table(summaries)


if __name__ == "__main__":
    main()
