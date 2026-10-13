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

mkdir -p "$W/bin"
printf '#!/bin/sh\necho "$@" >> "%s/notify.log"\n' "$W" > "$W/bin/cloudagent"; chmod +x "$W/bin/cloudagent"
export PATH="$W/bin:$PATH"

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

sleep 2.5
ok "new round triggers one notify with number and count" '[ "$(grep -c "Grill round 1 ready.*2 questions" "$W/notify.log")" = 1 ]'
ok "page falls back to polling on connection loss" 'curl -s "$BASE/?key=$KEY" | grep -q "Connection lost"'
ok "page renders with the key"          '[ "$(code "$BASE/?key=$KEY")" = 200 ]'
PAGE="$(curl -s "$BASE/?key=$KEY")"
ok "page pins marked, highlight.js and mermaid" 'grep -q "marked@[0-9.]*/" <<<"$PAGE" && grep -q "highlight.js\|cdn-release@11.9.0" <<<"$PAGE" && grep -q "mermaid@10.9.1" <<<"$PAGE" && ! grep -qE "(marked|mermaid)@(latest|[0-9]+)/" <<<"$PAGE"'
ok "page has dark and light code themes" 'grep -q "prefers-color-scheme: dark" <<<"$PAGE" && grep -q "github-dark.min.css" <<<"$PAGE"'
ok "page supports visual blocks and mockup classes" 'grep -q "q.visual" <<<"$PAGE" && grep -q "\.mockup-body" <<<"$PAGE"'
ok "page has accept-all, panel, decision log" 'PAGE="$(curl -s "$BASE/?key=$KEY")"; for m in accept-all id=\"panel\" id=\"log\" "Round comment" "max-width:640px"; do grep -q -- "$m" <<<"$PAGE" || exit 1; done'
ok "page script is valid JavaScript"    'curl -s "$BASE/?key=$KEY" | sed -n "/^<script>\$/,/^<\/script>/p" | sed "1d;\$d" > "$W/page.js" && node --check "$W/page.js"'
ok "page rejected without the key"      '[ "$(code "$BASE/")" = 403 ]'
ok "page rejected with a wrong key"     '[ "$(code "$BASE/?key=nope")" = 403 ]'
ok "state rejected without the key"     '[ "$(code "$BASE/state")" = 403 ]'
ok "submit rejected without the key"    '[ "$(code -X POST -d "{}" "$BASE/submit")" = 403 ]'
ok "state lists the round as ready"     '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r ".status + (.rounds[0].round.questions|length|tostring)")" = "round-ready2" ]'

SUB='{"round":1,"answers":[{"id":"q1","kind":"option","option":"a","text":"because"},{"id":"q2","kind":"accept"}],"comment":"ok"}'
ok "submit with the key succeeds"       '[ "$(code -X POST -H "x-grill-key: $KEY" -d "$SUB" "$BASE/submit")" = 200 ]'
ok "answers file has the expected shape" 'jq -e ".round==1 and .comment==\"ok\" and .answers[0]=={id:\"q1\",kind:\"option\",option:\"a\",text:\"because\"} and .answers[1]=={id:\"q2\",kind:\"accept\"} and (.submitted_at|type)==\"string\"" "$SDIR/answers-001.json" >/dev/null'
ok "second submit conflicts"            '[ "$(code -X POST -H "x-grill-key: $KEY" -d "$SUB" "$BASE/submit")" = 409 ]'
ok "browser submission is tagged"       '[ "$(jq -r .source "$SDIR/answers-001.json")" = browser ]'
ok "state moves to agent-working"       '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r .status)" = agent-working ]'

cat > "$SDIR/round-002.json" <<'JSON'
{"round":2,"type":"questions","questions":[{"id":"q1","title":"More?","body":"b"}]}
JSON
printf '%s' '{"round":2,"answers":[{"id":"q1","kind":"text","text":"typed"}],"comment":"","source":"terminal","submitted_at":"x"}' > "$SDIR/answers-002.json"
ok "terminal answers show as answered"  '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r ".status + .rounds[1].answers.source")" = agent-workingterminal ]'
rm "$SDIR/answers-002.json"
ok "incomplete submission is rejected"  '[ "$(code -X POST -H "x-grill-key: $KEY" -d "{\"round\":2,\"answers\":[]}" "$BASE/submit")" = 400 ]'
ok "unknown round is rejected"          '[ "$(code -X POST -H "x-grill-key: $KEY" -d "{\"round\":9,\"answers\":[]}" "$BASE/submit")" = 404 ]'
ok "rejected submission writes nothing" '[ ! -e "$SDIR/answers-002.json" ]'

ok "session files are git-excluded"     'grep -qxF ".grill/" "$P/.git/info/exclude"'

sleep 1.5
ok "round 2 notified singular"          'grep -q "Grill round 2 ready.*1 question " "$W/notify.log"'
kill "$(cat "$SDIR/state/server.pid")"; sleep 1
OUT2="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill)"
ok "restart keeps port and key"         '[ "$(jq -r .url <<<"$OUT2")" = "$URL" ]'
ok "restart keeps the session history"  '[ "$(curl -s "$BASE/state?key=$KEY" | jq ".rounds|length")" = 2 ]'

sleep 2.5
ok "restart does not re-notify"         '[ "$(wc -l < "$W/notify.log")" = 2 ]'
ok "restart page state carries the decision log" 'curl -s "$BASE/state?key=$KEY" | jq -e ".decisions|startswith(\"# Decision log\")" >/dev/null'
ok "server info reports resumed"        '[ "$(jq -r .resumed <<<"$OUT2")" = true ] && [ "$(jq -r .resumed <<<"$OUT")" = false ]'
ok "session has a decision log file"    '[ "$(jq -r .decision_log <<<"$OUT2")" = "$SDIR/decisions.md" ] && [ -f "$SDIR/decisions.md" ]'
ok "git-ignore file is untouched"       '[ ! -e "$P/.gitignore" ]'
ok "visual-companion dir is excluded"   'grep -qxF ".visual-companion/" "$P/.git/info/exclude"'

ok "open round stays open after restart" '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r ".rounds[1].answers")" = null ]'
printf -- '- chose files\n' >> "$SDIR/decisions.md"
ok "state shows appended decision log"  'curl -s "$BASE/state?key=$KEY" | jq -e ".decisions|contains(\"chose files\")" >/dev/null'

ST="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill --grill-status)"
ok "status offers the unfinished session" '[ "$(jq -r .unfinished <<<"$ST")" = "$SDIR" ] && [ "$(jq -r .rounds <<<"$ST")" = 2 ] && [ "$(jq -r .answered <<<"$ST")" = 1 ]'

echo '{"finished_at":"now"}' > "$SDIR/finished.json"
ok "finished session is not offered"    '[ "$(jq -r .unfinished <<<"$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill --grill-status)")" = null ]'
ok "state reports finished"             '[ "$(curl -s "$BASE/state?key=$KEY" | jq -r .status)" = finished ]'

sleep 1; OUT3="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill)"
SDIR3="$(jq -r .session_dir <<<"$OUT3")"
ok "after finishing, a new session starts" '[ "$SDIR3" != "$SDIR" ] && [ "$(jq -r .resumed <<<"$OUT3")" = false ]'
ok "new session reuses port and key"    '[ "$(jq -r .url <<<"$OUT3")" = "$URL" ]'
ok "old session history is untouched"   '[ -f "$SDIR/round-002.json" ] && [ -f "$SDIR/answers-001.json" ]'

sleep 1; OUT4="$(bash "$SCRIPTS/start-server.sh" --project-dir "$P" --grill --new)"
ok "--new starts a fresh session"       '[ "$(jq -r .session_dir <<<"$OUT4")" != "$SDIR3" ] && [ "$(jq -r .resumed <<<"$OUT4")" = false ]'
kill "$(cat "$(jq -r .session_dir <<<"$OUT4")/state/server.pid")" 2>/dev/null

echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
