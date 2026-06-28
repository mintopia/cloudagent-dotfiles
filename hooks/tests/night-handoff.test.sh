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

# --- stop: loop guard -------------------------------------------------------
setup
ACTIVE='{"session_id":"s1","stop_hook_active":true}'
run stop "$ACTIVE"
ok "stop_hook_active is silent"          '[ -z "$OUT" ]'
ok "stop_hook_active writes no marker"   '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

# --- stop: kill switch ------------------------------------------------------
setup
NIGHT_HANDOFF_DISABLE=1 run stop "$SID"
ok "disabled stop is silent"        '[ -z "$OUT" ]'
ok "disabled stop writes no marker" '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

# --- stop: window guard -----------------------------------------------------
setup
NIGHT_HANDOFF_NOW=12 run stop "$SID"
ok "noon (outside window) is silent"     '[ -z "$OUT" ]'
ok "outside window writes no marker"     '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "40 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "02:00 (inside window) still emits"   'emits_block'
teardown

# --- stop: missing marker + idle threshold ----------------------------------
setup
# In window, but no lastinput marker => never saw a user turn => silent.
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "in-window without lastinput is silent" '[ -z "$OUT" ]'
teardown

setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "2 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"   # short turn
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "short turn in-window is silent"        '[ -z "$OUT" ]'
ok "short turn writes no marker"           '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "40 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"  # long turn
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "long turn in-window emits block"       'emits_block'
ok "long turn writes handoff marker"       '[ -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown

# --- stop: cooldown ---------------------------------------------------------
setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "40 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"  # long turn
touch -d "1 hour ago"     "$NIGHT_HANDOFF_STATE_DIR/s1.handoff"    # handoff < 6h ago
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "cooldown suppresses repeat handoff" '[ -z "$OUT" ]'
teardown

setup
mkdir -p "$NIGHT_HANDOFF_STATE_DIR"
touch -d "40 minutes ago" "$NIGHT_HANDOFF_STATE_DIR/s1.lastinput"
touch -d "8 hours ago"    "$NIGHT_HANDOFF_STATE_DIR/s1.handoff"    # handoff > 6h ago
NIGHT_HANDOFF_NOW=2 run stop "$SID"
ok "stale handoff allows a new handoff"  'emits_block'
teardown

# === SUMMARY (keep last) ===
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
