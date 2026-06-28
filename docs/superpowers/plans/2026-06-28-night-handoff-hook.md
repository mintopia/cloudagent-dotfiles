# Night Handoff Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Claude Code hook that, when a long unattended turn finishes during the user's overnight window, forces Claude to write a handoff document and emit a cheap resume prompt.

**Architecture:** One bash script (`hooks/night-handoff.sh`) with two entry points dispatched on `$1`: `touch` (wired to `UserPromptSubmit`) stamps a per-session marker file at turn start; `stop` (wired to `Stop`) measures `now − mtime(marker)` (= turn duration) and, if it is overnight, the turn was long, and no handoff was written recently, returns a `decision:block` that makes Claude write the handoff. We build the emitting trigger first, then add each guard as a genuine red→green step. Settings wiring lives in an idempotent jq filter so it can be unit-tested and preserves any existing hooks.

**Tech Stack:** Bash, `jq` (already an installer dependency), GNU coreutils `date`/`touch`. Tests are a self-contained bash harness driven by `NIGHT_HANDOFF_NOW` / `NIGHT_HANDOFF_STATE_DIR` test seams.

**Reference spec:** `docs/superpowers/specs/2026-06-28-night-handoff-hook-design.md`

---

## File Structure

- **Create `hooks/night-handoff.sh`** — the hook script (both events). Runtime artifact, copied to `~/.claude/hooks/`.
- **Create `hooks/settings-hooks.jq`** — idempotent jq filter that adds the two hook entries to `settings.json` without clobbering existing hooks. Used by `install.sh` at install time and by the tests.
- **Create `hooks/tests/night-handoff.test.sh`** — bash test harness for the script and the jq filter.
- **Modify `install.sh`** — copy the script to `~/.claude/hooks/`, wire settings via the jq filter, extend the setup summary.
- **Modify `README.md`** — document the hook and its configuration.

**Guard order in the finished script** (top to bottom): kill switch → loop guard → window → missing-marker + idle → cooldown → trigger. Tasks 3–7 each replace one ordered placeholder, so the order is fixed up front by Task 2.

---

### Task 1: Test harness + `touch` event

**Files:**
- Create: `hooks/tests/night-handoff.test.sh`
- Create: `hooks/night-handoff.sh`

- [ ] **Step 1: Write the failing test (creates the harness skeleton)**

Create `hooks/tests/night-handoff.test.sh`:

```bash
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

# === SUMMARY (keep last) ===
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — `night-handoff.sh` does not exist, so both `touch` assertions fail (`Passed: 0  Failed: 2`).

- [ ] **Step 3: Write the minimal implementation**

Create `hooks/night-handoff.sh`:

```bash
#!/usr/bin/env bash
# night-handoff.sh — force a handoff when a long unattended turn ends overnight.
# Usage: night-handoff.sh touch   (wired to the UserPromptSubmit hook)
#        night-handoff.sh stop    (wired to the Stop hook)
# Reads the hook event JSON on stdin.
# See docs/superpowers/specs/2026-06-28-night-handoff-hook-design.md
set -euo pipefail

STATE_DIR="${NIGHT_HANDOFF_STATE_DIR:-$HOME/.claude/state/night-handoff}"
event="${1:-}"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
if [ -z "$session_id" ]; then exit 0; fi

mkdir -p "$STATE_DIR"
lastinput_file="$STATE_DIR/${session_id}.lastinput"
handoff_file="$STATE_DIR/${session_id}.handoff"

if [ "$event" = "touch" ]; then
  touch "$lastinput_file"
  exit 0
fi

if [ "$event" != "stop" ]; then exit 0; fi

# Stop-event decision logic added in later tasks.
exit 0
```

Make it executable:

```bash
chmod +x hooks/night-handoff.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Passed: 2  Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff touch event + test harness"
```

---

### Task 2: Stop — minimal handoff trigger

This task makes `stop` *always* emit the handoff block. Guards that narrow it down are added in Tasks 3–7, each as a red→green step.

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing tests**

In `hooks/tests/night-handoff.test.sh`, insert this block immediately before the `# === SUMMARY (keep last) ===` line:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — the four `stop` assertions fail; the current `stop` path is a silent no-op (`Failed: 4`).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace:

```bash
# Stop-event decision logic added in later tasks.
exit 0
```

with:

```bash
# --- Stop decision logic ---------------------------------------------------
# Guards are inserted by later tasks at the ordered placeholders below.
# [guard:killswitch]
# [guard:loop]
# [guard:window]
# [guard:marker-idle]
# [guard:cooldown]

# Trigger: record the handoff marker first, then emit the block decision.
touch "$handoff_file"

reason=$(cat <<'EOF'
A long-running turn just finished during the user's overnight window and they are likely away. Before stopping, create a handoff so they can resume cheaply in the morning:

1. Invoke the `handoff` skill to write a handoff document capturing what was done, the current state, and the next steps.
2. Then output a short, paste-ready resume prompt the user can run in a fresh session — prefer `/pickup`, and reference the handoff document's path.

Keep it concise. Do NOT start any new work — only write the handoff and the resume prompt, then stop.
EOF
)

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff minimal handoff trigger"
```

---

### Task 3: Stop — loop guard (`stop_hook_active`)

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing test**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
# --- stop: loop guard -------------------------------------------------------
setup
ACTIVE='{"session_id":"s1","stop_hook_active":true}'
run stop "$ACTIVE"
ok "stop_hook_active is silent"          '[ -z "$OUT" ]'
ok "stop_hook_active writes no marker"   '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — with only Task 2's unconditional trigger, an `stop_hook_active:true` event still emits the block and writes the marker (`Failed: 2`).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace the line:

```bash
# [guard:loop]
```

with:

```bash
# Loop guard: this Stop is the handoff's own turn ending — never recurse.
stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"
if [ "$stop_hook_active" = "true" ]; then exit 0; fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff loop guard"
```

---

### Task 4: Stop — kill switch

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing test**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
# --- stop: kill switch ------------------------------------------------------
setup
NIGHT_HANDOFF_DISABLE=1 run stop "$SID"
ok "disabled stop is silent"        '[ -z "$OUT" ]'
ok "disabled stop writes no marker" '[ ! -f "$NIGHT_HANDOFF_STATE_DIR/s1.handoff" ]'
teardown
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — without the kill switch, a disabled run still emits the block (`Failed: 2`).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace the line:

```bash
# [guard:killswitch]
```

with:

```bash
# Kill switch.
if [ -n "${NIGHT_HANDOFF_DISABLE:-}" ]; then exit 0; fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff kill switch"
```

---

### Task 5: Stop — overnight window guard

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing test**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — without the window guard, the noon run still emits the block (`Failed: 2`; the in-window assertion already passes).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace the line:

```bash
# [guard:window]
```

with:

```bash
# Window check. NIGHT_HANDOFF_NOW overrides the current hour for tests.
TZ_NAME="${NIGHT_HANDOFF_TZ:-Europe/London}"
START="${NIGHT_HANDOFF_START:-1}"
END="${NIGHT_HANDOFF_END:-9}"
if [ -n "${NIGHT_HANDOFF_NOW:-}" ]; then
  hour="$NIGHT_HANDOFF_NOW"
else
  hour="$(TZ="$TZ_NAME" date +%H)"
fi
hour="$((10#$hour))"   # strip any leading zero, force base-10
if [ "$hour" -lt "$START" ] || [ "$hour" -ge "$END" ]; then exit 0; fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff overnight window guard"
```

---

### Task 6: Stop — missing-marker guard and idle threshold

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing tests**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — without this guard, the in-window/no-marker case and the short-turn case still emit the block (`Failed: 3`; the two "long turn" assertions already pass).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace the line:

```bash
# [guard:marker-idle]
```

with:

```bash
# Missing marker: we never saw a user turn this session => not an unattended run.
if [ ! -f "$lastinput_file" ]; then exit 0; fi

# Short turn: now - mtime(lastinput) < IDLE_MIN minutes => user was active.
IDLE_MIN="${NIGHT_HANDOFF_IDLE_MIN:-15}"
now="$(date +%s)"
last="$(date -r "$lastinput_file" +%s)"
if [ "$(( now - last ))" -lt "$(( IDLE_MIN * 60 ))" ]; then exit 0; fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff missing-marker guard + idle threshold"
```

---

### Task 7: Stop — per-session cooldown

**Files:**
- Modify: `hooks/night-handoff.sh`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing test**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — without the cooldown guard, a long turn emits a block even though a handoff was written 1 hour ago (`Failed: 1`; the stale-handoff assertion already passes).

- [ ] **Step 3: Write the implementation**

In `hooks/night-handoff.sh`, replace the line:

```bash
# [guard:cooldown]
```

with:

```bash
# Cooldown: skip if a handoff was written within COOLDOWN_H hours this session.
COOLDOWN_H="${NIGHT_HANDOFF_COOLDOWN_H:-6}"
if [ -f "$handoff_file" ]; then
  hdone="$(date -r "$handoff_file" +%s)"
  if [ "$(( now - hdone ))" -lt "$(( COOLDOWN_H * 3600 ))" ]; then exit 0; fi
fi
```

Note: `now` is defined by the idle guard above, which is why this placeholder sits below `[guard:marker-idle]`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/night-handoff.sh hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): night-handoff per-session cooldown"
```

---

### Task 8: Settings-wiring jq filter (idempotent, preserves existing hooks)

**Files:**
- Create: `hooks/settings-hooks.jq`
- Test: `hooks/tests/night-handoff.test.sh`

- [ ] **Step 1: Write the failing tests**

In `hooks/tests/night-handoff.test.sh`, insert before `# === SUMMARY (keep last) ===`:

```bash
# --- settings-hooks.jq ------------------------------------------------------
wire() { jq --arg stop_cmd "HH stop" --arg touch_cmd "HH touch" -f "$FILTER"; }

OUT="$(printf '{}' | wire)"
ok "adds Stop command"          'printf "%s" "$OUT" | jq -e "[.hooks.Stop[].hooks[].command]|index(\"HH stop\")" >/dev/null'
ok "adds UserPromptSubmit cmd"  'printf "%s" "$OUT" | jq -e "[.hooks.UserPromptSubmit[].hooks[].command]|index(\"HH touch\")" >/dev/null'

OUT="$(printf '{}' | wire | wire)"
ok "idempotent: no duplicate Stop" 'test "$(printf "%s" "$OUT" | jq "[.hooks.Stop[].hooks[].command]|map(select(.==\"HH stop\"))|length")" -eq 1'

EXISTING='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"other.sh"}]}]}}'
OUT="$(printf '%s' "$EXISTING" | wire)"
ok "preserves existing Stop hook" 'printf "%s" "$OUT" | jq -e "[.hooks.Stop[].hooks[].command]|index(\"other.sh\")" >/dev/null'
ok "adds ours alongside existing" 'test "$(printf "%s" "$OUT" | jq "[.hooks.Stop[].hooks[].command]|length")" -eq 2'
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: FAIL — `settings-hooks.jq` does not exist, so every `wire` call errors and all five assertions fail (`Failed: 5`).

- [ ] **Step 3: Write the implementation**

Create `hooks/settings-hooks.jq`:

```jq
# Idempotently add the night-handoff Stop / UserPromptSubmit hooks to settings.
# Args: --arg stop_cmd "<abs path> stop"  --arg touch_cmd "<abs path> touch"
# Existing hooks for either event are preserved; our entry is added only if a
# hook with the same command string is not already present.

def has_cmd($event; $cmd):
  (.hooks[$event] // []) | any(.[].hooks[]?; .command == $cmd);

def add_hook($event; $cmd):
  if has_cmd($event; $cmd) then .
  else .hooks[$event] = ((.hooks[$event] // [])
       + [{hooks: [{type: "command", command: $cmd}]}])
  end;

.hooks = (.hooks // {})
| add_hook("Stop"; $stop_cmd)
| add_hook("UserPromptSubmit"; $touch_cmd)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash hooks/tests/night-handoff.test.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/settings-hooks.jq hooks/tests/night-handoff.test.sh
git commit -m "feat(hooks): idempotent settings-hooks.jq wiring filter"
```

---

### Task 9: Installer wiring

**Files:**
- Modify: `install.sh` (add a Hooks section after the statusline-wiring block near line 133, and extend the summary near line 222)

- [ ] **Step 1: Add the hooks install section**

In `install.sh`, find the line `ok "Wired statusline into settings.json"` (end of the statusline-wiring block, around line 133). Immediately after it, insert:

```bash

# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

info "Installing hooks..."
HOOKS_DIR="$CLAUDE_DIR/hooks"
mkdir -p "$HOOKS_DIR"
cp "$DOTFILES_DIR/hooks/night-handoff.sh" "$HOOKS_DIR/night-handoff.sh"
chmod +x "$HOOKS_DIR/night-handoff.sh"
ok "Installed night-handoff.sh"

# Wire the Stop / UserPromptSubmit hooks idempotently, preserving any existing
# hooks. Absolute paths are machine-specific, so this is done here (not in
# config/settings.json) and is safe to re-run.
STOP_CMD="$HOOKS_DIR/night-handoff.sh stop"
TOUCH_CMD="$HOOKS_DIR/night-handoff.sh touch"
tmp=$(mktemp)
jq --arg stop_cmd "$STOP_CMD" --arg touch_cmd "$TOUCH_CMD" \
   -f "$DOTFILES_DIR/hooks/settings-hooks.jq" \
   "$CLAUDE_DIR/settings.json" > "$tmp"
mv "$tmp" "$CLAUDE_DIR/settings.json"
ok "Wired night-handoff hooks into settings.json"
echo
```

- [ ] **Step 2: Extend the setup summary**

In `install.sh`, find this line in the summary block near the end:

```bash
echo "  Statusline:  ~/.claude/statusline-command.sh"
```

Insert this line immediately before it:

```bash
echo "  Hooks:       night-handoff (overnight handoff)"
```

- [ ] **Step 3: Verify the installer's wiring snippet on a sample settings file**

Run (a dry check of the exact filter the installer uses — does not touch your real `~/.claude`):

```bash
printf '{"model":"x"}' | jq --arg stop_cmd "/h/night-handoff.sh stop" \
  --arg touch_cmd "/h/night-handoff.sh touch" -f hooks/settings-hooks.jq
```

Expected: JSON containing `"model":"x"` plus a `hooks` object whose `Stop` and `UserPromptSubmit` arrays each hold one `command` ending in `night-handoff.sh stop` / `night-handoff.sh touch`.

- [ ] **Step 4: Syntax-check the modified installer**

Run: `bash -n install.sh && echo OK`
Expected: `OK` (no syntax errors).

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "chore(install): install and wire the night-handoff hook"
```

---

### Task 10: README documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the documentation section**

In `README.md`, add a new section (place it after the skills documentation, before any trailing/footer content). Use this exact content:

```markdown
## Night handoff hook

`hooks/night-handoff.sh` watches for long-running turns that finish while you are
asleep and forces Claude to leave a cheap resumption trail, so you don't pay for a
cold full-context `/resume` in the morning.

How it works:

- A `UserPromptSubmit` hook stamps a per-session marker on every user turn.
- A `Stop` hook measures how long the just-finished turn ran (`now − marker`). If
  that turn ran longer than the idle threshold **and** it ended inside your
  overnight window **and** no handoff was written recently, it returns a
  `decision:block` instructing Claude to invoke the `handoff` skill and print a
  paste-ready resume prompt (prefer `/pickup`).

Because the measured "idle" is really the turn's duration, a long unattended run
that finishes at 03:00 triggers a handoff, while you actively chatting at 02:00
(short turns) does not. A per-session cooldown prevents repeats.

Configuration (environment variables):

| Var | Default | Meaning |
|-----|---------|---------|
| `NIGHT_HANDOFF_TZ` | `Europe/London` | Timezone the window is measured in (DST-aware). |
| `NIGHT_HANDOFF_START` | `1` | Window start hour, inclusive. |
| `NIGHT_HANDOFF_END` | `9` | Window end hour, exclusive. |
| `NIGHT_HANDOFF_IDLE_MIN` | `15` | Minimum turn duration (minutes) to count as "away". |
| `NIGHT_HANDOFF_COOLDOWN_H` | `6` | No repeat handoff within this many hours per session. |
| `NIGHT_HANDOFF_DISABLE` | _(unset)_ | Set to any value to disable the hook. |

Run the tests with `bash hooks/tests/night-handoff.test.sh`.
```

- [ ] **Step 2: Verify the section was added**

Run: `grep -n "Night handoff hook" README.md`
Expected: one match at the new section heading.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): document the night-handoff hook"
```

---

## Final verification

- [ ] Run the full test suite: `bash hooks/tests/night-handoff.test.sh` → `Failed: 0`.
- [ ] Syntax check: `bash -n hooks/night-handoff.sh && bash -n install.sh && echo OK` → `OK`.
- [ ] Confirm the jq filter produces valid JSON: `printf '{}' | jq -f hooks/settings-hooks.jq --arg stop_cmd a --arg touch_cmd b` → a JSON object with `.hooks.Stop` and `.hooks.UserPromptSubmit`.
- [ ] Manual smoke test of the trigger path:

```bash
DEMO="$(mktemp -d)/state"; mkdir -p "$DEMO"
touch -d "40 minutes ago" "$DEMO/demo.lastinput"
printf '{"session_id":"demo","stop_hook_active":false}' \
  | NIGHT_HANDOFF_STATE_DIR="$DEMO" NIGHT_HANDOFF_NOW=2 bash hooks/night-handoff.sh stop
```

Expected: a JSON object with `"decision":"block"` and a `reason` mentioning the `handoff` skill and `/pickup`.

---

## Notes for the implementer

- **Why `date -r FILE`**: GNU coreutils `date -r` prints a file's modification time; combined with `touch -d "N minutes ago"` in tests this gives deterministic, fast control over "turn duration" without sleeping.
- **`set -euo pipefail` + conditionals**: the script uses `if … then exit 0; fi` rather than `[ … ] && exit 0`, because a false `&&` list would otherwise abort the script under `set -e`.
- **Loop safety**: the `stop_hook_active` guard plus the cooldown marker both prevent the forced handoff turn from re-triggering the hook.
- **Out of scope**: the non-sleep-hours keepalive is intentionally not built — see the spec's "won't-do" section.
