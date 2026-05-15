---
name: pickup
description: >
  Lightweight session recap invoked via /pickup or natural phrases like
  "where were we?", "catch me up", "what was I doing?". Reconstructs previous
  session context from durable artifacts (session JSONL, git state, memory files,
  recent file changes) instead of /resume which replays the full conversation and
  costs many tokens when the cache is cold. Use this skill whenever the user types
  /pickup, or says "where were we", "catch me up", "what was I working on",
  "recap", or any variant of wanting to resume context without a full /resume.
  Do NOT use if the user explicitly asks for /resume.
---

# Pickup

Produce a cheap, accurate summary of the previous session so the user can pick up
where they left off without replaying the full conversation transcript.

## Why this exists

`/resume` loads the entire previous conversation into context, which is powerful
but expensive — especially when the prompt cache has expired (after 5 minutes of
inactivity). This skill reconstructs context from artifacts that are already on
disk: the session JSONL, git history, memory files, and filesystem timestamps.
The result is a summary that costs a fraction of the tokens while capturing the
essential "where was I and what's next."

## How it works

Gather context from five sources, then synthesize into a single summary. Use the
bundled `scripts/extract_session.py` to parse the JSONL cheaply — it extracts
only text content and metadata, skipping thinking blocks and binary data.

### Step 1: Find and parse the previous session

```bash
# Determine the project directory for session files
PROJECT_DIR="$HOME/.claude/projects/$(echo "$PWD" | sed 's|/|-|g')"

# Find the most recent previous session (not the current one)
PREV_SESSION=$(python3 <skill-path>/scripts/extract_session.py --find-previous "$PROJECT_DIR" "$CURRENT_SESSION_ID")

# Extract the summary
python3 <skill-path>/scripts/extract_session.py "$PREV_SESSION"
```

The script returns JSON with:
- `user_messages`: what the user asked for (capped at 500 chars each, last 30)
- `assistant_messages`: what you said back (capped, last 20)
- `tool_usage`: which tools were used and how often
- `last_prompt`: the final thing the user typed
- `skills_used`: which skills were invoked
- `duration`, `start_time`, `end_time`: session timing
- `message_counts`: total message volume

If the current session ID isn't available, just use the most recently modified
JSONL file in the project directory.

### Step 2: Gather git context

Run these in parallel:
- `git log --oneline -20 --since="<session_start_time>"` — commits made during the session
- `git diff --stat` — any uncommitted changes left over
- `git diff --cached --stat` — staged but uncommitted changes
- `git branch --show-current` — current branch
- `git stash list` — any stashed work

The session start time comes from the JSONL metadata. If not available, use the
last 24 hours as a reasonable window.

### Step 3: Check memory

Read `MEMORY.md` from the project memory directory to see if anything was saved
during or about the previous session. Memory entries with recent timestamps are
especially relevant.

### Step 4: Check recently modified files

```bash
find . -name '*.md' -o -name '*.py' -o -name '*.ts' -o -name '*.js' \
  -o -name '*.yaml' -o -name '*.json' -o -name '*.sh' \
  | xargs ls -lt --time-style=long-iso 2>/dev/null \
  | head -20
```

This shows which files were touched recently, giving clues about what area of the
codebase was being worked on.

### Step 5: Synthesize the summary

Combine all the gathered information into a summary. Adapt the format based on
how much happened:

**For light sessions** (few commits, simple conversation): 2-4 sentences covering
what was done and what's next.

**For complex sessions** (many commits, multiple topics, lots of tool use): use
this structure:

```
## Session Recap

**Duration**: [time] | **Branch**: [branch] | **Model**: [model]

### What was happening
[1-3 sentences synthesizing the user's goals from their messages]

### What got done
- [Bullet list of commits and key changes]
- [Notable decisions or discoveries]

### Left in progress
- [Uncommitted changes]
- [The last prompt / where the conversation was heading]
- [Any stashed work]

### Suggested next steps
- [Based on uncommitted work, last prompt, and conversation trajectory]
```

## After the summary

Offer to create a task list if there's clearly unfinished work. Something like:
"Want me to set up tasks for the remaining work?" Keep it brief — the user knows
what they want to do, they just need the context refreshed.

## What NOT to do

- Don't replay the full conversation — that's what `/resume` is for
- Don't read the entire JSONL file into context — use the extraction script
- Don't guess at what was happening if the artifacts are ambiguous — say what you
  found and let the user fill gaps
- Don't spend tokens re-reading files that the summary already tells you about —
  the user will ask if they need you to look at specific code
