#!/usr/bin/env bash
# Cloud Agent-aware teardown for the visual companion.
#
# Stops the server via the upstream stop-server.sh. The project's http-forward is
# deliberately left in place so an open tab reconnects after a restart.
# Safe to run off Cloud Agent — it just stops the server.
#
# Usage: stop-companion.sh <session_dir>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_DIR="${1:-}"

if [[ -z "$SESSION_DIR" ]]; then
  echo '{"error": "Usage: stop-companion.sh <session_dir>"}'
  exit 1
fi

# Kill this project's persistent tmux session (named as in launch-persistent.sh).
# A project session dir is <project>/.visual-companion/brainstorm/<id>.
PROJECT_DIR=""
[[ "$SESSION_DIR" == */.visual-companion/brainstorm/* ]] && PROJECT_DIR="${SESSION_DIR%/.visual-companion/brainstorm/*}"
SLUG="$(basename "${PROJECT_DIR:-visual-companion}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n-' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-40 | sed 's/-$//')"
if command -v tmux >/dev/null 2>&1; then
  tmux kill-session -t "${VC_TMUX_SESSION:-visual-companion-${SLUG:-project}}" 2>/dev/null || true
fi

exec "$SCRIPT_DIR/stop-server.sh" "$SESSION_DIR"
