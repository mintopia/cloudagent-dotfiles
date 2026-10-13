#!/usr/bin/env bash
# Tests for start-companion.sh / stop-companion.sh using a fake `cloudagent` CLI.
# Run: bash skills/visual-companion/tests/companion.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/../scripts" && pwd)"
PASS=0; FAIL=0
ok() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ✔ $1";
  else FAIL=$((FAIL+1)); echo "  ✘ $1  [$2]"; fi
}

W="$(mktemp -d)"
trap 'for p in "$W"/*/.visual-companion/brainstorm/*/state/server.pid; do [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null; done; rm -rf "$W"' EXIT
mkdir -p "$W/bin" "$W/My Proj_One" "$W/second"
STORE="$W/forwards.json"; echo '[]' > "$STORE"

# Fake CLI: `http-forwards list|add|remove` backed by a JSON file.
cat > "$W/bin/cloudagent" <<'FAKE'
#!/usr/bin/env bash
[[ "$1 $2" == "http-forwards list" ]] && { cat "$STORE"; exit 0; }
if [[ "$1 $2" == "http-forwards add" ]]; then
  shift 2; while [[ $# -gt 0 ]]; do case "$1" in --container) P="$2";; --hostname) H="$2";; esac; shift; done
  echo "add $H $P" >> "$STORE.log"
  F="{\"id\":\"f-$H\",\"hostname\":\"$H\",\"container_port\":$P,\"url\":\"https://$H.example.test\"}"
  jq ". + [$F]" "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"; echo "$F"; exit 0
fi
[[ "$1 $2" == "http-forwards remove" ]] && { echo "remove $3" >> "$STORE.log"; exit 0; }
exit 1
FAKE
chmod +x "$W/bin/cloudagent"
export STORE

ca() { env PATH="$W/bin:$PATH" STORE="$STORE" CLOUDAGENT_API_URL=https://x "$@"; }
adds() { grep -c '^add' "$STORE.log" 2>/dev/null || true; }
touch "$STORE.log"

P1="$W/My Proj_One"; P2="$W/second"
OUT1="$(ca bash "$SCRIPTS/start-companion.sh" --project-dir "$P1")"
URL1="$(jq -r .url <<<"$OUT1")"; PORT1="$(jq -r .port <<<"$OUT1")"
ok "creates forward grill-<cleaned dir name>" 'grep -q "^add grill-my-proj-one $PORT1\$" "$STORE.log"'
ok "url is the public forward url"             '[[ "$URL1" == https://grill-my-proj-one.example.test/?key=* ]]'

stopit() { ca bash "$SCRIPTS/stop-companion.sh" "$(dirname "$(jq -r .screen_dir <<<"$1")")"; sleep 1; }
stopit "$OUT1" >/dev/null
ok "stop does not remove the forward" '! grep -q "^remove" "$STORE.log"'

OUT1B="$(ca bash "$SCRIPTS/start-companion.sh" --project-dir "$P1")"
ok "restart reuses forward (no new add)" '[ "$(adds)" -eq 1 ]'
ok "restart keeps the same url"          '[ "$(jq -r .url <<<"$OUT1B")" = "$URL1" ]'

# Hostname fallback: forward exists on a stale port, same hostname.
jq '.[0].container_port = 1' "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"
stopit "$OUT1B" >/dev/null
ca bash "$SCRIPTS/start-companion.sh" --project-dir "$P1" >/dev/null
ok "falls back to hostname match" '[ "$(adds)" -eq 1 ]'

OUT2="$(ca bash "$SCRIPTS/start-companion.sh" --project-dir "$P2")"
ok "second project gets own hostname"  'grep -q "^add grill-second " "$STORE.log"'
ok "second project gets different port" '[ "$(jq -r .port <<<"$OUT2")" != "$(jq -r .port <<<"$OUT1B")" ]'
ok "both servers run independently"     'curl -fs -o /dev/null "http://localhost:$(jq -r .port <<<"$OUT2")/" || kill -0 "$(cat "$(jq -r .state_dir <<<"$OUT2")/server.pid")"'

LONG="$W/$(printf 'a%.0s' {1..80})"; mkdir -p "$LONG"
ca bash "$SCRIPTS/start-companion.sh" --project-dir "$LONG" >/dev/null
ok "long hostnames are shortened" 'grep "^add grill-a" "$STORE.log" | awk "{print length(\$2)}" | grep -qx "[0-9]\{1,50\}"'

# Outside Cloud Agent: no forward calls, plain localhost URL.
before="$(wc -l < "$STORE.log")"
mkdir -p "$W/plain"
OUTP="$(env -u CLOUDAGENT_API_URL PATH="$W/bin:$PATH" STORE="$STORE" bash "$SCRIPTS/start-companion.sh" --project-dir "$W/plain")"
ok "outside Cloud Agent: no cloudagent calls" '[ "$(wc -l < "$STORE.log")" -eq "$before" ]'
ok "outside Cloud Agent: localhost url"       '[[ "$(jq -r .url <<<"$OUTP")" == http://localhost:* ]]'

echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
