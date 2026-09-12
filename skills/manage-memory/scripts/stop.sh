#!/usr/bin/env bash
# Stop the server and remove its Cloud Agent forward. Usage: stop.sh <state_dir>
set -euo pipefail
STATE_DIR="${1:?usage: stop.sh <state_dir>}"

if [[ -f "$STATE_DIR/server.pid" ]]; then
  kill "$(cat "$STATE_DIR/server.pid")" 2>/dev/null || true
fi
if [[ -f "$STATE_DIR/forward.id" ]] && command -v cloudagent >/dev/null 2>&1; then
  FID="$(cat "$STATE_DIR/forward.id")"
  [[ -n "$FID" ]] && cloudagent http-forwards remove "$FID" >/dev/null 2>&1 || true
fi
echo "stopped"
