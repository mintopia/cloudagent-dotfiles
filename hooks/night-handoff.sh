#!/usr/bin/env bash
# night-handoff.sh — force a handoff when a long unattended turn ends overnight.
# Usage: night-handoff.sh touch   (wired to the UserPromptSubmit hook)
#        night-handoff.sh stop    (wired to the Stop hook)
# Reads the hook event JSON on stdin.
# See docs/superpowers/specs/2026-06-28-night-handoff-hook-design.md
set -euo pipefail

STATE_DIR="${NIGHT_HANDOFF_STATE_DIR:-$HOME/.claude/state/night-handoff}"
event="${1:-}"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
if [ -z "$session_id" ]; then exit 0; fi

mkdir -p "$STATE_DIR"
lastinput_file="$STATE_DIR/${session_id}.lastinput"
handoff_file="$STATE_DIR/${session_id}.handoff"

if [ "$event" = "touch" ]; then
  touch "$lastinput_file"
  exit 0
fi

if [ "$event" != "stop" ]; then exit 0; fi

# --- Stop decision logic ---------------------------------------------------
# Guards are inserted by later tasks at the ordered placeholders below.
# [guard:killswitch]
# [guard:loop]
# [guard:window]
# [guard:marker-idle]
# [guard:cooldown]

# Trigger: record the handoff marker first, then emit the block decision.
touch "$handoff_file"

reason=$(cat <<'EOF'
A long-running turn just finished during the user's overnight window and they are likely away. Before stopping, create a handoff so they can resume cheaply in the morning:

1. Invoke the `handoff` skill to write a handoff document capturing what was done, the current state, and the next steps.
2. Then output a short, paste-ready resume prompt the user can run in a fresh session — prefer `/pickup`, and reference the handoff document's path.

Keep it concise. Do NOT start any new work — only write the handoff and the resume prompt, then stop.
EOF
)

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
