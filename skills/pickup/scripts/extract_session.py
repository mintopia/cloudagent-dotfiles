#!/usr/bin/env python3
"""Extract a lightweight summary from a Claude Code session JSONL file.

Reads the session transcript and outputs a structured JSON summary containing:
- User prompts (the human's actual typed messages)
- Assistant responses (text only, no tool calls or thinking)
- Tool usage counts
- Session metadata (timestamps, duration, model)
- The last prompt sent

Designed to be cheap: only extracts text content, skips binary/thinking blocks,
and caps individual messages to avoid blowing up context.
"""

import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

MAX_MSG_CHARS = 500
MAX_USER_MSGS = 30
MAX_ASSISTANT_MSGS = 20


def extract_session(jsonl_path: str) -> dict:
    path = Path(jsonl_path)
    if not path.exists():
        return {"error": f"File not found: {jsonl_path}"}

    user_messages = []
    assistant_messages = []
    tool_counts = Counter()
    timestamps = []
    last_prompt = None
    model = None
    skills_used = set()

    for line in path.open():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        entry_type = entry.get("type")
        ts = entry.get("timestamp")
        if ts:
            timestamps.append(ts)

        if entry_type == "user":
            msg = entry.get("message", {})
            for content in msg.get("content", []):
                if isinstance(content, dict) and content.get("type") == "text":
                    text = content["text"].strip()
                    if text and not text.startswith("<"):
                        user_messages.append(text[:MAX_MSG_CHARS])

        elif entry_type == "assistant":
            msg = entry.get("message", {})
            if not model:
                model = msg.get("model")

            skill = entry.get("attributionSkill")
            if skill:
                skills_used.add(skill)

            for content in msg.get("content", []):
                if isinstance(content, dict):
                    if content.get("type") == "text":
                        text = content["text"].strip()
                        if text:
                            assistant_messages.append(text[:MAX_MSG_CHARS])
                    elif content.get("type") == "tool_use":
                        tool_counts[content.get("name", "unknown")] += 1

        elif entry_type == "last-prompt":
            lp = entry.get("lastPrompt")
            if lp:
                last_prompt = lp

    duration_str = None
    if len(timestamps) >= 2:
        try:
            first = datetime.fromisoformat(timestamps[0].replace("Z", "+00:00"))
            last = datetime.fromisoformat(timestamps[-1].replace("Z", "+00:00"))
            delta = last - first
            minutes = int(delta.total_seconds() / 60)
            if minutes < 60:
                duration_str = f"{minutes} minutes"
            else:
                hours = minutes // 60
                remaining = minutes % 60
                duration_str = f"{hours}h {remaining}m"
        except (ValueError, TypeError):
            pass

    return {
        "session_file": str(path.name),
        "model": model,
        "duration": duration_str,
        "start_time": timestamps[0] if timestamps else None,
        "end_time": timestamps[-1] if timestamps else None,
        "user_messages": user_messages[-MAX_USER_MSGS:],
        "assistant_messages": assistant_messages[-MAX_ASSISTANT_MSGS:],
        "tool_usage": dict(tool_counts.most_common(15)),
        "total_tool_calls": sum(tool_counts.values()),
        "last_prompt": last_prompt,
        "skills_used": sorted(skills_used),
        "message_counts": {
            "user": len(user_messages),
            "assistant": len(assistant_messages),
        },
    }


def find_previous_session(project_dir: str, current_session_id: str = None) -> str | None:
    """Find the most recently modified session JSONL that isn't the current one."""
    project = Path(project_dir)
    if not project.exists():
        return None

    sessions = sorted(
        [f for f in project.glob("*.jsonl") if f.stem != current_session_id],
        key=lambda f: f.stat().st_mtime,
        reverse=True,
    )
    return str(sessions[0]) if sessions else None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract_session.py <session.jsonl> [--find-previous <project-dir> [current-session-id]]")
        sys.exit(1)

    if sys.argv[1] == "--find-previous":
        project_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        current_id = sys.argv[3] if len(sys.argv) > 3 else None
        result = find_previous_session(project_dir, current_id)
        if result:
            print(result)
        else:
            print("No previous session found", file=sys.stderr)
            sys.exit(1)
    else:
        summary = extract_session(sys.argv[1])
        print(json.dumps(summary, indent=2))
