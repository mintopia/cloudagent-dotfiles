#!/usr/bin/env bash
# Cloud Agent-aware teardown for the visual companion.
#
# Removes the http-forward this session created (if any), then stops the server
# via the upstream stop-server.sh. Safe to run off Cloud Agent — it just stops
# the server.
#
# Usage: stop-companion.sh <session_dir>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_DIR="${1:-}"

if [[ -z "$SESSION_DIR" ]]; then
  echo '{"error": "Usage: stop-companion.sh <session_dir>"}'
  exit 1
fi

FWD_FILE="${SESSION_DIR}/state/http-forward-id"
if [[ -f "$FWD_FILE" ]] && command -v cloudagent >/dev/null 2>&1; then
  FWD_ID="$(tr -d ' \r\n' < "$FWD_FILE" 2>/dev/null || true)"
  if [[ -n "$FWD_ID" ]]; then
    cloudagent http-forwards remove "$FWD_ID" >/dev/null 2>&1 || true
    rm -f "$FWD_FILE"
  fi
fi

exec "$SCRIPT_DIR/stop-server.sh" "$SESSION_DIR"
