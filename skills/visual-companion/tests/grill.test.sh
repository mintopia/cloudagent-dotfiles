#!/usr/bin/env bash
# Tests for the grill UI server (start-server.sh --grill) over HTTP and disk.
# Run: bash skills/visual-companion/tests/grill.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/../scripts" && pwd)"
PASS=0; FAIL=0
ok() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ✔ $1";
  else FAIL=$((FAIL+1)); echo "  ✘ $1  [$2]"; fi
}

W="$(mktemp -d)"
trap 'for p in "$W"/*/.grill/session-*/state/server.pid; do [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null; done; rm -rf "$W"' EXIT
P="$W/proj"; mkdir -p "$P"; git -C "$P" init -q

OUT="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill)"
URL="$(jq -r .url <<<"$OUT")"; PORT="$(jq -r .port <<<"$OUT")"
SDIR="$(jq -r .session_dir <<<"$OUT")"
KEY="${URL##*key=}"
BASE="http://localhost:$PORT"
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

cat > "$SDIR/round-001.json" <<'JSON'
{"round":1,"type":"questions","title":"Scope","notes":"Agent **notes**",
 "questions":[
  {"id":"q1","title":"Which store?","body":"Pick a **store**","options":[{"id":"a","label":"SQLite"},{"id":"b","label":"Files"}],"recommendation":"Files"},
  {"id":"q2","title":"Name it?","body":"Naming","recommendation":"yes"}]}
JSON

ok "page renders with the key"          '[ "$(code "$BASE/?key=$KEY")" = 200 ]'
ok "page rejected without the key"      '[ "$(code "$BASE/")" = 403 ]'
ok "page rejected with a wrong key"     '[ "$(code "$BASE/?key=nope")" = 403 ]'
ok "state rejected without the key"     '[ "$(code "$BASE/state")" = 403 ]'
ok "submit rejected without the key"    '[ "$(code -X POST -d "{}" "$BASE/submit")" = 403 ]'
ok "state lists the round as ready"     '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r ".status + (.rounds[0].round.questions|length|tostring)")" = "round-ready2" ]'

SUB='{"round":1,"answers":[{"id":"q1","kind":"option","option":"a","text":"because"},{"id":"q2","kind":"accept"}],"comment":"ok"}'
ok "submit with the key succeeds"       '[ "$(code -X POST -H "x-grill-key: $KEY" -d "$SUB" "$BASE/submit")" = 200 ]'
ok "answers file has the expected shape" 'jq -e ".round==1 and .comment==\"ok\" and .answers[0]=={id:\"q1\",kind:\"option\",option:\"a\",text:\"because\"} and .answers[1]=={id:\"q2\",kind:\"accept\"} and (.submitted_at|type)==\"string\"" "$SDIR/answers-001.json" >/dev/null'
ok "second submit conflicts"            '[ "$(code -X POST -H "x-grill-key: $KEY" -d "$SUB" "$BASE/submit")" = 409 ]'
ok "state moves to agent-working"       '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r .status)" = agent-working ]'

cat > "$SDIR/round-002.json" <<'JSON'
{"round":2,"type":"questions","questions":[{"id":"q1","title":"More?","body":"b"}]}
JSON
ok "incomplete submission is rejected"  '[ "$(code -X POST -H "x-grill-key: $KEY" -d "{\"round\":2,\"answers\":[]}" "$BASE/submit")" = 400 ]'
ok "unknown round is rejected"          '[ "$(code -X POST -H "x-grill-key: $KEY" -d "{\"round\":9,\"answers\":[]}" "$BASE/submit")" = 404 ]'
ok "rejected submission writes nothing" '[ ! -e "$SDIR/answers-002.json" ]'

ok "session files are git-excluded"     'grep -qxF ".grill/" "$P/.git/info/exclude"'

kill "$(cat "$SDIR/state/server.pid")"; sleep 1
OUT2="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill)"
ok "restart keeps port and key"         '[ "$(jq -r .url <<<"$OUT2")" = "$URL" ]'
ok "restart keeps the session history"  '[ "$(curl -s "$BASE/state?key=$KEY" | jq ".rounds|length")" = 2 ]'

echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
