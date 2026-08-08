#!/usr/bin/env bash
# harmonic-start.sh — SessionStart hook. Ensures Harmonic (agent UI / task
# scheduler, github.com/mintopia/harmonic) is running as a single background
# daemon and reachable via a private HTTPS forward on the `harmonic` hostname.
#
# Idempotent and safe to run every session:
#   - `harmonic start` is a singleton — it refuses if a daemon is already up.
#   - the forward is only added when one for the hostname does not already exist;
#     concurrent SessionStart fires are serialized with a lock so they cannot
#     both add.
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

# Run a command under a timeout when `timeout` is available, so a slow/unreachable
# cloudagent API can never hang session start; fall back to a plain call otherwise.
run_to() { if command -v timeout >/dev/null 2>&1; then timeout 15 "$@"; else "$@"; fi; }

# 1. Ensure the daemon is running. `harmonic start` self-guards as a singleton
#    ("Already running" if a daemon exists). Run detached so a slow first-run
#    npx build never blocks session start; the daemon persists across sessions.
if command -v npx >/dev/null 2>&1; then
  nohup npx -y github:mintopia/harmonic start --port "$HARMONIC_PORT" \
    >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi

# 2. Ensure exactly one private HTTPS forward for the `harmonic` hostname. Both
#    the cloudagent CLI and jq are required to read/parse the forward list.
url=""
if command -v cloudagent >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  # Serialize concurrent SessionStart fires (per session, and on resume/clear)
  # so two runs cannot both see "no forward" and both add. Best-effort.
  exec 9>"${TMPDIR:-/tmp}/harmonic-forward.lock" 2>/dev/null || true
  if command -v flock >/dev/null 2>&1; then flock 9 2>/dev/null || true; fi

  # `http-forwards list --json` wraps rows in {"data":[...]}; accept a bare
  # array too, in case the schema changes.
  url="$(run_to cloudagent http-forwards list --json 2>/dev/null \
    | jq -r --arg h "$HARMONIC_HOSTNAME" \
        '[ (.data // .)[]? | select(.hostname==$h) | .url ] | first // empty' 2>/dev/null)"

  if [ -z "$url" ]; then
    # `add --json` returns the row (possibly under .data); accept either shape.
    url="$(run_to cloudagent http-forwards add --container "$HARMONIC_PORT" \
        --hostname "$HARMONIC_HOSTNAME" --private --json 2>/dev/null \
      | jq -r '(.data.url // .url // empty)' 2>/dev/null)"
  fi
fi

# 3. Surface the URL to Claude (best-effort; silent if we could not obtain one).
if [ -n "$url" ] && command -v jq >/dev/null 2>&1; then
  jq -n --arg url "$url" \
    '{hookSpecificOutput: {hookEventName: "SessionStart",
      additionalContext: ("Harmonic (agent UI / task scheduler) is running at "
        + $url + " — a private HTTPS forward on the `harmonic` hostname.")}}'
fi
exit 0
