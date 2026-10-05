#!/usr/bin/env bash
# Launch the visual companion under a persistent tmux session.
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
SESSION="${VC_TMUX_SESSION:-visual-companion}"
TMP="${TMPDIR:-/tmp}"
OUT="$(mktemp "$TMP/visual-companion-launch.XXXXXX.json")"

if ! command -v tmux >/dev/null 2>&1; then
  # No tmux: fall back to a direct launch. The owner-PID watchdog may still reap
  # the server when the launching turn ends; the idle timeout is the backstop.
  exec "$SCRIPT_DIR/start-companion.sh" "$@"
fi

# A previous run leaves the session parked on `sleep infinity`; replace it.
tmux kill-session -t "$SESSION" 2>/dev/null || true
rm -f "$TMP"/visual-companion-run.*.sh 2>/dev/null || true

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
