#!/usr/bin/env bash
# harmonic-start.sh — SessionStart hook. Ensures Harmonic (agent UI / task
# scheduler, github.com/mintopia/harmonic) is running as a single background
# daemon and reachable via a private HTTPS forward on the `harmonic` hostname.
#
# Idempotent and safe to run every session:
#   - `harmonic start` is a singleton — it refuses if a daemon is already up.
#   - the forward is only added when one for the hostname does not already exist.
#
# NOTE: no `set -e` — this hook is best-effort; a failure must never break the
# session. It only fires inside a Cloud Agent workspace (the forward needs the
# cloudagent CLI).
set -uo pipefail

# Kill switch.
if [ -n "${HARMONIC_HOOK_DISABLE:-}" ]; then exit 0; fi

# Only inside a Cloud Agent workspace.
if ! command -v cloudagent >/dev/null 2>&1 && [ -z "${CLOUDAGENT_API_URL:-}" ]; then
  exit 0
fi

HARMONIC_PORT="${HARMONIC_PORT:-4700}"
HARMONIC_HOSTNAME="${HARMONIC_HOSTNAME:-harmonic}"

# 1. Ensure the daemon is running. `harmonic start` self-guards as a singleton
#    ("Already running" if a daemon exists). Run detached so a slow first-run
#    npx build never blocks session start; the daemon persists across sessions.
if command -v npx >/dev/null 2>&1; then
  nohup npx -y github:mintopia/harmonic start --port "$HARMONIC_PORT" \
    >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi

# 2. Ensure a private HTTPS forward for the `harmonic` hostname exists. The
#    forward can be created before the server is listening — it just proxies to
#    the container port.
url=""
if command -v cloudagent >/dev/null 2>&1; then
  url="$(cloudagent http-forwards list --json 2>/dev/null \
    | jq -r --arg h "$HARMONIC_HOSTNAME" 'first(.[]? | select(.hostname==$h) | .url) // empty' 2>/dev/null)"
  if [ -z "$url" ]; then
    url="$(cloudagent http-forwards add --container "$HARMONIC_PORT" \
      --hostname "$HARMONIC_HOSTNAME" --private --json 2>/dev/null \
      | jq -r '.url // empty' 2>/dev/null)"
  fi
fi

# 3. Surface the URL to Claude (best-effort; silent if we could not obtain one).
if [ -n "$url" ]; then
  jq -n --arg url "$url" \
    '{hookSpecificOutput: {hookEventName: "SessionStart",
      additionalContext: ("Harmonic (agent UI / task scheduler) is running at "
        + $url + " — a private HTTPS forward on the `harmonic` hostname.")}}'
fi
exit 0
