#!/usr/bin/env bash
# Tests for the SessionStart hook and settings-hooks.jq:
#   - settings-hooks.jq   (wires the cloudagent-skill SessionStart hook)
#   - cloudagent-skill.sh (loads the cloudagent skill in a workspace)
# Run: bash hooks/tests/hooks.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
FILTER="$HOOKS/settings-hooks.jq"
PASS=0; FAIL=0

# ok <name> <test-expression>
ok() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ✔ $1";
  else FAIL=$((FAIL+1)); echo "  ✘ $1  [$2]"; fi
}

# --- settings-hooks.jq ------------------------------------------------------
wire() { jq --arg session_start_cmd "HH session" --arg harmonic_cmd "HH harmonic" -f "$FILTER"; }

OUT="$(printf '{}' | wire)"
ok "adds cloudagent SessionStart cmd" 'printf "%s" "$OUT" | jq -e "[.hooks.SessionStart[].hooks[].command]|index(\"HH session\")" >/dev/null'
ok "adds harmonic SessionStart cmd"   'printf "%s" "$OUT" | jq -e "[.hooks.SessionStart[].hooks[].command]|index(\"HH harmonic\")" >/dev/null'
ok "no Stop hook wired"               'printf "%s" "$OUT" | jq -e "(.hooks.Stop // []) | length == 0" >/dev/null'
ok "no UserPromptSubmit hook wired"   'printf "%s" "$OUT" | jq -e "(.hooks.UserPromptSubmit // []) | length == 0" >/dev/null'

OUT="$(printf '{}' | wire | wire)"
ok "idempotent: no duplicate SessionStart cmds" 'test "$(printf "%s" "$OUT" | jq "[.hooks.SessionStart[].hooks[].command]|length")" -eq 2'

EXISTING='{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"other.sh"}]}]}}'
OUT="$(printf '%s' "$EXISTING" | wire)"
ok "preserves existing SessionStart hook" 'printf "%s" "$OUT" | jq -e "[.hooks.SessionStart[].hooks[].command]|index(\"other.sh\")" >/dev/null'
ok "adds both ours alongside existing"    'test "$(printf "%s" "$OUT" | jq "[.hooks.SessionStart[].hooks[].command]|length")" -eq 3'

# --- cloudagent-skill.sh ----------------------------------------------------
CASKILL="$HOOKS/cloudagent-skill.sh"

# In a Cloud Agent workspace (CLOUDAGENT_API_URL set): emits SessionStart context.
OUT="$(printf '{}' | env CLOUDAGENT_API_URL=https://example bash "$CASKILL" 2>/dev/null)"
ok "cloudagent emits additionalContext" 'printf "%s" "$OUT" | jq -e ".hookSpecificOutput.additionalContext" >/dev/null'
ok "context names the cloudagent skill" 'printf "%s" "$OUT" | jq -re ".hookSpecificOutput.additionalContext" | grep -q "cloudagent"'
ok "context no longer mentions kanban"  '! (printf "%s" "$OUT" | jq -re ".hookSpecificOutput.additionalContext" | grep -qi "kanban")'
ok "cloudagent hookEventName SessionStart" 'printf "%s" "$OUT" | jq -e ".hookSpecificOutput.hookEventName==\"SessionStart\"" >/dev/null'

# Kill switch wins even inside a workspace.
OUT="$(printf '{}' | env CLOUDAGENT_API_URL=https://example CLOUDAGENT_SKILL_HOOK_DISABLE=1 bash "$CASKILL" 2>/dev/null)"
ok "cloudagent kill switch suppresses output" '[ -z "$OUT" ]'

# Outside a Cloud Agent workspace: no API URL and cloudagent not on PATH.
CABIN="$(mktemp -d)"
ln -s "$(command -v bash)" "$CABIN/bash"
ln -s "$(command -v jq)"   "$CABIN/jq"
OUT="$(printf '{}' | env -i PATH="$CABIN" CLOUDAGENT_API_URL= bash "$CASKILL" 2>/dev/null)"
ok "cloudagent outside workspace is silent" '[ -z "$OUT" ]'
rm -rf "$CABIN"

# --- harmonic-start.sh (guard paths only; no npx/cloudagent side effects) ---
HARM="$HOOKS/harmonic-start.sh"

# Kill switch: silent, exit 0, even inside a workspace.
OUT="$(printf '{}' | env CLOUDAGENT_API_URL=https://example HARMONIC_HOOK_DISABLE=1 bash "$HARM" 2>/dev/null)"; RC=$?
ok "harmonic kill switch is silent" '[ -z "$OUT" ]'
ok "harmonic kill switch exits 0"   '[ "$RC" -eq 0 ]'

# Outside a Cloud Agent workspace: no cloudagent CLI on PATH, no API URL → exits
# before touching npx/cloudagent, silent. Minimal PATH so cloudagent is unfound.
HBIN="$(mktemp -d)"
ln -s "$(command -v bash)" "$HBIN/bash"
ln -s "$(command -v jq)"   "$HBIN/jq"
OUT="$(printf '{}' | env -i PATH="$HBIN" CLOUDAGENT_API_URL= bash "$HARM" 2>/dev/null)"; RC=$?
ok "harmonic outside workspace is silent" '[ -z "$OUT" ]'
ok "harmonic outside workspace exits 0"   '[ "$RC" -eq 0 ]'
rm -rf "$HBIN"

# === SUMMARY (keep last) ===
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
