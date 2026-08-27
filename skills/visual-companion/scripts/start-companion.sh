#!/usr/bin/env bash
# Cloud Agent-aware launcher for the visual companion.
#
# In a Cloud Agent workspace this binds 0.0.0.0, creates (or reuses) a
# TLS-terminated http-forward, and rewrites the returned URL to the public
# https:// address. helper.js upgrades the WebSocket to wss:// on its own when
# the page is https, so live-reload and click tracking keep working behind the
# forward. Anywhere else it just runs the plain localhost server unchanged.
#
# Either way it prints the same `server-started` JSON the visual-companion loop
# expects (screen_dir / state_dir / url), so the skill body never has to branch
# on environment.
#
# Usage: start-companion.sh --project-dir <path> [--open] [start-server flags...]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORWARD_HOSTNAME="visual-companion"

# Detect a Cloud Agent workspace the same way the cloudagent skill/hooks and
# install.sh do: the management API env var plus the CLI on PATH.
is_cloudagent() {
  [[ -n "${CLOUDAGENT_API_URL:-}" ]] && command -v cloudagent >/dev/null 2>&1
}

# Plain path: not a Cloud Agent workspace, run the server as-is and pass through.
if ! is_cloudagent; then
  exec "$SCRIPT_DIR/start-server.sh" "$@"
fi

# Cloud Agent path. Bind broadly so the forward proxy can reach the server;
# url-host is a throwaway we overwrite once the forward exists.
OUT="$("$SCRIPT_DIR/start-server.sh" --host 0.0.0.0 --url-host localhost "$@")"

# start-server.sh prints either a server-started JSON or {"error":...}. On error
# (or anything unexpected) surface it verbatim and stop.
if ! grep -q '"type"[[:space:]]*:[[:space:]]*"server-started"' <<<"$OUT"; then
  printf '%s\n' "$OUT"
  exit 1
fi

# Pull the fields we need out of the server JSON. node is already a hard
# dependency (it runs server.cjs), and newline-framing survives spaces in paths.
mapfile -t FIELDS < <(printf '%s' "$OUT" | node -e '
  let s=""; process.stdin.on("data", d => s += d).on("end", () => {
    const j = JSON.parse(s);
    const u = new URL(j.url);
    process.stdout.write([j.port, u.searchParams.get("key") || "", j.state_dir].join("\n"));
  });')
PORT="${FIELDS[0]}"
KEY="${FIELDS[1]}"
STATE_DIR="${FIELDS[2]}"

# Reuse an existing forward for this container port (restarts keep the same port
# and key per project, so the user's open tab reconnects to the same URL), else
# create one.
BASE_URL="$(cloudagent http-forwards list --json 2>/dev/null | node -e '
  let s=""; process.stdin.on("data", d => s += d).on("end", () => {
    let arr = [];
    try { const j = JSON.parse(s); arr = j.data || j; } catch (e) {}
    const port = Number(process.argv[1]);
    const hit = (arr || []).find(f => Number(f.container_port) === port);
    process.stdout.write(hit && hit.url ? String(hit.url) : "");
  });' "$PORT")"

if [[ -z "$BASE_URL" ]]; then
  ADD="$(cloudagent http-forwards add --container "$PORT" --hostname "$FORWARD_HOSTNAME" --json)"
  mapfile -t FWD < <(printf '%s' "$ADD" | node -e '
    let s=""; process.stdin.on("data", d => s += d).on("end", () => {
      const j = JSON.parse(s); const f = j.data || j;
      process.stdout.write([f.url || "", f.id || ""].join("\n"));
    });')
  BASE_URL="${FWD[0]}"
  FWD_ID="${FWD[1]}"
  # Record the forward id so stop-companion.sh can tear it down.
  [[ -n "$FWD_ID" && -d "$STATE_DIR" ]] && printf '%s\n' "$FWD_ID" > "$STATE_DIR/http-forward-id"
fi

if [[ -z "$BASE_URL" ]]; then
  printf '{"error":"Could not create or find an http-forward for port %s"}\n' "$PORT"
  exit 1
fi

# Public URL = forward base + the session key gate. Rewrite the `url` field in
# the original JSON and reprint everything else untouched.
PUBLIC_URL="${BASE_URL%/}/?key=${KEY}"
printf '%s' "$OUT" | PUBLIC_URL="$PUBLIC_URL" node -e '
  let s=""; process.stdin.on("data", d => s += d).on("end", () => {
    const j = JSON.parse(s);
    j.local_url = j.url;
    j.url = process.env.PUBLIC_URL;
    process.stdout.write(JSON.stringify(j));
    process.stdout.write("\n");
  });'
