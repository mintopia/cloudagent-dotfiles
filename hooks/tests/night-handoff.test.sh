#!/usr/bin/env bash
# Tests for night-handoff.sh and settings-hooks.jq.
# Run: bash hooks/tests/night-handoff.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$HERE/.." && pwd)/night-handoff.sh"
FILTER="$(cd "$HERE/.." && pwd)/settings-hooks.jq"
PASS=0; FAIL=0

setup() {
  TMP="$(mktemp -d)"
  export NIGHT_HANDOFF_STATE_DIR="$TMP/state"
  unset NIGHT_HANDOFF_DISABLE NIGHT_HANDOFF_NOW
  export NIGHT_HANDOFF_IDLE_MIN=15 NIGHT_HANDOFF_COOLDOWN_H=6 \
         NIGHT_HANDOFF_START=1 NIGHT_HANDOFF_END=9
}
teardown() { rm -rf "$TMP"; }

# run <event> <json>  -> sets OUT (stdout) and RC (exit code)
run() { OUT="$(printf '%s' "$2" | "$HOOK" "$1" 2>/dev/null)"; RC=$?; }

# ok <name> <test-expression>
ok() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ✔ $1";
  else FAIL=$((FAIL+1)); echo "  ✘ $1  [$2]"; fi
}

# emits_block: true when $OUT is a JSON object with .decision == "block"
emits_block() { printf '%s' "$OUT" | jq -e '.decision=="block"' >/dev/null 2>&1; }

SID='{"session_id":"s1","stop_hook_active":false}'

# --- touch ------------------------------------------------------------------
setup
run touch "$SID"
ok "touch creates lastinput marker" '[ -f "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput" ]'
ok "touch is silent"                '[ -z "$OUT" ]'
teardown

# --- stop: trigger ----------------------------------------------------------
# Use the full happy path (in-window + long unattended turn) so these stay green
# as later tasks add the window / idle / cooldown guards.
setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "40 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "stop emits block decision"        'emits_block'
ok "stop reason mentions handoff"     'printf "%s" "$OUT" | jq -re ".reason" | grep -qi handoff'
ok "stop reason mentions /pickup"     'printf "%s" "$OUT" | jq -re ".reason" | grep -q "/pickup"'
ok "stop writes handoff marker"       '[ -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

# === SUMMARY (keep last) ===
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
