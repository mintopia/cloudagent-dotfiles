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

# Stop-event decision logic added in later tasks.
exit 0
