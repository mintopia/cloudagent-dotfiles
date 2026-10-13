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

# Parse --project-dir from the passthrough args (start-server.sh owns validation).
PROJECT_DIR=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [[ "${args[i]}" == "--project-dir" ]] && PROJECT_DIR="${args[i+1]:-}"
done

# Per-project hostname: grill-<dir name>, lowercased to [a-z0-9-], trimmed, and
# capped so the DNS label stays well under 63 chars.
SLUG="$(basename "${PROJECT_DIR:-visual-companion}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n-' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-40 | sed 's/-$//')"
FORWARD_HOSTNAME="grill-${SLUG:-project}"

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
    process.stdout.write([j.port, u.searchParams.get("key") || ""].join("\n"));
  });')
PORT="${FIELDS[0]}"
KEY="${FIELDS[1]}"

# Reuse an existing forward: match by container port first, then by hostname
# (restarts keep the same port and key per project, so the user's open tab
# reconnects to the same URL), else create one. Forwards are never removed on
# stop, so they persist across restarts.
BASE_URL="$(cloudagent http-forwards list --json 2>/dev/null | node -e '
  let s=""; process.stdin.on("data", d => s += d).on("end", () => {
    let arr = [];
    try { const j = JSON.parse(s); arr = j.data || j; } catch (e) {}
    const port = Number(process.argv[1]);
    const host = process.argv[2];
    const list = arr || [];
    const hit = list.find(f => Number(f.container_port) === port)
      || list.find(f => f.hostname === host);
    process.stdout.write(hit && hit.url ? String(hit.url) : "");
  });' "$PORT" "$FORWARD_HOSTNAME")"

if [[ -z "$BASE_URL" ]]; then
  ADD="$(cloudagent http-forwards add --container "$PORT" --hostname "$FORWARD_HOSTNAME" --json)"
  mapfile -t FWD < <(printf '%s' "$ADD" | node -e '
    let s=""; process.stdin.on("data", d => s += d).on("end", () => {
      const j = JSON.parse(s); const f = j.data || j;
      process.stdout.write([f.url || "", f.id || ""].join("\n"));
    });')
  BASE_URL="${FWD[0]}"
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
