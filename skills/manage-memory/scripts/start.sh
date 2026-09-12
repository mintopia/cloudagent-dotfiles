#!/usr/bin/env bash
# Launch the memory editor server. Cloud Agent-aware: binds 0.0.0.0 and creates a
# private TLS forward there; plain localhost otherwise. Prints a JSON line with the
# url, state_dir, pid and forward_id — save it; you read state_dir back on save.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MEMORY_DIR="" STATE_DIR="" PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --memory-dir) MEMORY_DIR="$2"; shift 2;;
    --state-dir)  STATE_DIR="$2";  shift 2;;
    --port)       PORT="$2";       shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

[[ -n "$MEMORY_DIR" ]] || { echo "--memory-dir required" >&2; exit 1; }
[[ -d "$MEMORY_DIR" ]] || { echo "memory dir not found: $MEMORY_DIR" >&2; exit 1; }
STATE_DIR="${STATE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/manage-memory.XXXXXX")}"
mkdir -p "$STATE_DIR"
PORT="${PORT:-$(( (RANDOM % 16383) + 49152 ))}"

CLOUD=0
if [[ -n "${CLOUDAGENT_API_URL:-}" ]] && command -v cloudagent >/dev/null 2>&1; then CLOUD=1; fi
HOST=127.0.0.1
[[ "$CLOUD" == "1" ]] && HOST=0.0.0.0

MM_MEMORY_DIR="$MEMORY_DIR" MM_STATE_DIR="$STATE_DIR" MM_PORT="$PORT" MM_HOST="$HOST" \
  nohup node "$SCRIPT_DIR/server.mjs" >"$STATE_DIR/server.log" 2>&1 &
PID=$!
echo "$PID" > "$STATE_DIR/server.pid"

for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.1
done

# Extract a field from a cloudagent JSON response, tolerating a `data` wrapper.
field() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const x=o.data||o;process.stdout.write(String(x[process.argv[1]]??""))}catch(e){}})' "$1"; }

URL="http://localhost:$PORT/"
FORWARD_ID=""
if [[ "$CLOUD" == "1" ]]; then
  # Drop any stale forward on our hostname — the port changes per launch, so a
  # leftover one both collides (500 on add) and points at a dead port.
  cloudagent http-forwards list --json \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const a=o.data||o;(Array.isArray(a)?a:[]).filter(f=>f.hostname==="manage-memory").forEach(f=>console.log(f.id))}catch(e){}})' \
    | while read -r id; do [[ -n "$id" ]] && cloudagent http-forwards remove "$id" >/dev/null 2>&1 || true; done
  RESP="$(cloudagent http-forwards add --container "$PORT" --hostname manage-memory --private --json)"
  URL="$(field url <<<"$RESP")"
  FORWARD_ID="$(field id <<<"$RESP")"
  echo "$FORWARD_ID" > "$STATE_DIR/forward.id"
fi

node -e 'const [url,dir,port,pid,fid]=process.argv.slice(1);console.log(JSON.stringify({url,state_dir:dir,port:Number(port),pid:Number(pid),forward_id:fid}))' \
  "$URL" "$STATE_DIR" "$PORT" "$PID" "$FORWARD_ID"
