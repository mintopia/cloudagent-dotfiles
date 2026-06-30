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
# Guards run in order; each exits 0 to suppress the handoff.
# Kill switch.
if [ -n "${NIGHT_HANDOFF_DISABLE:-}" ]; then exit 0; fi
# Loop guard: this Stop is the handoff's own turn ending — never recurse.
stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"
if [ "$stop_hook_active" = "true" ]; then exit 0; fi
# Window check. NIGHT_HANDOFF_NOW overrides the current hour for tests.
TZ_NAME="${NIGHT_HANDOFF_TZ:-Europe/London}"
START="${NIGHT_HANDOFF_START:-1}"
END="${NIGHT_HANDOFF_END:-9}"
if [ -n "${NIGHT_HANDOFF_NOW:-}" ]; then
  hour="$NIGHT_HANDOFF_NOW"
  if ! [[ "$hour" =~ ^[0-9]+$ ]]; then exit 0; fi
else
  hour="$(TZ="$TZ_NAME" date +%H)"
fi
hour="$((10#$hour))"   # strip any leading zero, force base-10
if [ "$hour" -lt "$START" ] || [ "$hour" -ge "$END" ]; then exit 0; fi
# Missing marker: we never saw a user turn this session => not an unattended run.
if [ ! -f "$lastinput_file" ]; then exit 0; fi

# Short turn: now - mtime(lastinput) < IDLE_MIN minutes => user was active.
IDLE_MIN="${NIGHT_HANDOFF_IDLE_MIN:-15}"
now="$(date +%s)"
last="$(date -r "$lastinput_file" +%s)"
if [ "$(( now - last ))" -lt "$(( IDLE_MIN * 60 ))" ]; then exit 0; fi
# Cooldown: skip if a handoff was written within COOLDOWN_H hours this session.
COOLDOWN_H="${NIGHT_HANDOFF_COOLDOWN_H:-6}"
if [ -f "$handoff_file" ]; then
  hdone="$(date -r "$handoff_file" +%s)"
  if [ "$(( now - hdone ))" -lt "$(( COOLDOWN_H * 3600 ))" ]; then exit 0; fi
fi

# Trigger: record the handoff marker first, then emit the block decision.
touch "$handoff_file"

# NOTE: the instructions are inlined here rather than delegating to the `handoff`
# skill. Matt Pocock's `handoff` skill sets `disable-model-invocation: true`, so
# the model cannot invoke it from this Stop hook — the block would never be
# satisfied. Keeping the steps self-contained makes the hook independent of any
# skill's invocation policy.
reason=$(cat <<'EOF'
A long-running turn just finished during the user's overnight window and they are likely away. Before stopping, write a handoff so they can resume cheaply in the morning. Do this directly — do NOT rely on the `handoff` skill (it is user-invocable only and cannot be triggered from here).

1. Write a handoff document to your OS temporary directory (not the workspace). Capture: what was done this turn, the current state, and the concrete next steps. Add a short "suggested skills" section. Reference existing artifacts (PRDs, plans, ADRs, issues, commits, diffs) by path or URL instead of duplicating them. Redact anything sensitive (keys, passwords, PII).
2. Then output a short, paste-ready resume prompt the user can run in a fresh session — prefer `/pickup`, and reference the handoff document's path.

Keep it concise. Do NOT start any new work — only write the handoff and the resume prompt, then stop.
EOF
)

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
