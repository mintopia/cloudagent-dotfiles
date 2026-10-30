#!/usr/bin/env bash
# Launch the visual companion so it outlives the launching Bash call.
#
# Cloud Agent: runs under a detached tmux session (below). Anywhere else (e.g.
# Claude Code on a laptop): launches directly with the watchdog tied to the
# Claude Code process, since tmux there gets killed with the sandbox.
#
# Why: server.cjs watches BRAINSTORM_OWNER_PID (the process that owns the launch)
# and self-terminates the moment that owner exits — the "owner process exited"
# death. Two things kill a naive launch: the harness reaps the whole process
# group when the Bash turn ends, and the auto-resolved owner PID is the launcher
# shell, which exits straight away. This wrapper fixes both: it runs the launcher
# inside a detached tmux session (tmux reparents it, escaping the group reap) and
# pins the owner PID to that session's shell, which lives on as `sleep infinity`
# for the server's whole lifetime.
#
# Drop-in for start-companion.sh: same arguments, prints its server-started JSON
# (or an error JSON) on stdout.
#
# Usage: launch-persistent.sh --project-dir <path> [--open] [start-server flags...]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [[ "${args[i]}" == "--project-dir" ]] && PROJECT_DIR="${args[i+1]:-}"
done
SLUG="$(basename "${PROJECT_DIR:-visual-companion}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n-' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-40 | sed 's/-$//')"
PREFIX="visual-companion"
for a in "$@"; do [[ "$a" == "--grill" ]] && PREFIX="grill-ui"; done
SESSION="${VC_TMUX_SESSION:-${PREFIX}-${SLUG:-project}}"
TMP="${TMPDIR:-/tmp}"
OUT="$(mktemp "$TMP/visual-companion-launch.XXXXXX.json")"

is_cloudagent() {
  [[ -n "${CLOUDAGENT_API_URL:-}" ]] && command -v cloudagent >/dev/null 2>&1
}

# Nearest ancestor that is the Claude Code CLI (npm or native install).
find_claude_pid() {
  local pid=$PPID args
  for _ in $(seq 1 20); do
    [[ -z "$pid" || "$pid" -le 1 ]] && return 1
    args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
    if [[ "$args" =~ (^|/)claude([[:space:]]|$)|claude-code|/claude/versions/ ]]; then
      printf '%s' "$pid"; return 0
    fi
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  return 1
}

# Local (laptop) path: no tmux. A user's own tmux server or Claude Code's
# sandbox both kill a tmux-launched server, so tie the watchdog to the Claude
# Code process instead; if it can't be found, an empty owner disables the
# watchdog and the idle timeout / stop-companion.sh are the only shutdown.
if ! is_cloudagent || ! command -v tmux >/dev/null 2>&1; then
  BRAINSTORM_OWNER_PID_OVERRIDE="$(find_claude_pid || true)"
  export BRAINSTORM_OWNER_PID_OVERRIDE
  RESULT="$("$SCRIPT_DIR/start-companion.sh" "$@" 2>&1 || true)"
  if grep -q '"type":"server-started"' <<<"$RESULT"; then
    grep -m1 '"type":"server-started"' <<<"$RESULT"
  else
    ERR="$(tr -d '\r"' <<<"$RESULT" | grep -m1 . || true)"
    echo "{\"error\": \"visual companion launch failed: ${ERR:-no output}. If Claude Code's sandbox is on, rerun this command with the sandbox disabled (it blocks listening ports and reaps processes when the command ends).\"}"
    exit 1
  fi
  exit 0
fi

# A previous run leaves the session parked on `sleep infinity`; replace it.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Build a runner script so arg quoting survives the hand-off to tmux's shell. $$
# is the runner's own PID; it owns the server and persists via `exec sleep
# infinity`, so the watchdog's owner stays alive for the session's lifetime.
RUN="$(mktemp "$TMP/visual-companion-run.XXXXXX.sh")"
{
  echo '#!/usr/bin/env bash'
  echo 'export BRAINSTORM_OWNER_PID_OVERRIDE=$$'
  printf '%q' "$SCRIPT_DIR/start-companion.sh"
  for a in "$@"; do printf ' %q' "$a"; done
  printf ' > %q 2>&1\n' "$OUT"
  echo 'exec sleep infinity'
} > "$RUN"
chmod +x "$RUN"

tmux new-session -d -s "$SESSION" "exec bash $(printf '%q' "$RUN")"

# Wait for the launcher to emit its result (server-started JSON, or an error).
for _ in $(seq 1 100); do
  if grep -q '"type":"server-started"\|"error"\|^Error' "$OUT" 2>/dev/null; then break; fi
  sleep 0.1
done

if grep -m1 '"type":"server-started"' "$OUT" 2>/dev/null; then
  :
else
  # start-companion.sh failed (e.g. the http-forward API). The local server may
  # still be up under tmux; surface the real error rather than a generic one.
  ERR="$(tr -d '\r' < "$OUT" | grep -m1 . || true)"
  echo "{\"error\": \"visual companion launch failed: ${ERR:-no output; see $OUT}\"}"
fi
