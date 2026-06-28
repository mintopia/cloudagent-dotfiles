# Night Handoff Hook — Design

**Date:** 2026-06-28
**Status:** Approved (pending implementation plan)

## Problem

Long-running tasks in Cloud Agent often finish overnight while the user is away.
By morning the prompt cache (5-minute TTL) is cold, so resuming with `/resume`
replays the full conversation at uncached cost. The user wants an automatic
safety net: when a long turn finishes during the night and the user is likely
asleep, Claude should write a handoff document and emit a cheap, paste-ready
resume prompt — so the morning pickup costs a fraction of a cold `/resume`.

This builds on the existing `pickup` skill (cheap context reconstruction) and the
installed `handoff` skill (writing the handoff document). The hook's job is purely
to *decide when* to force a handoff and to *trigger* it.

## Key insight: turn duration as a presence proxy

A `Stop` hook fires exactly once, at the moment a turn ends, and must decide
immediately — it cannot observe the future, so it cannot wait to see whether the
user submits something in the next 5 minutes. True idle-detection is therefore
impossible *synchronously*, and a forced model-written handoff requires a
synchronous blocking decision. These two are mutually exclusive.

The resolution: a `UserPromptSubmit` hook touches a marker file on **every user
input** (i.e. at turn *start*). At the subsequent `Stop` event,
`now − mtime(marker)` equals **how long the just-ended turn ran**. This is an
effective presence proxy:

- A long unattended task started at 00:30 that finishes at 03:00 shows ~2.5 h of
  "idle" → the user was almost certainly away → write a handoff.
- A user actively chatting at 02:00 produces short turns (seconds) → no handoff.

Accepted limitation: a long turn the user *watches* at 2 AM will trigger one
handoff. This is harmless — the per-session cooldown prevents repeats — and the
only alternative (true presence detection) is not available in the hook surface.

## Architecture

One script, two entry points, dispatched on `$1`:

```
hooks/night-handoff.sh touch   # wired to UserPromptSubmit
hooks/night-handoff.sh stop    # wired to Stop
```

Implemented in **bash + `jq`** (both already repo dependencies; `jq` is used by
the installer). Timezone handling uses `TZ="Europe/London" date` which respects
BST/GMT automatically.

### State

Per-session files under `~/.claude/state/night-handoff/`:

| File | Written by | Meaning |
|------|-----------|---------|
| `<session_id>.lastinput` | `touch` event | mtime = start of the most recent user turn |
| `<session_id>.handoff`   | `stop` event  | mtime = when a handoff was last forced this session |

`session_id` comes from the hook's stdin JSON. The directory is created on demand.

### `touch` event (UserPromptSubmit)

Read `session_id` from stdin, `touch` `<session_id>.lastinput`, exit 0. No output,
never blocks.

### `stop` event (Stop) — decision logic

Read stdin JSON (`session_id`, `stop_hook_active`, `cwd`, `transcript_path`).
Evaluate in order; the first matching guard exits 0 (allow normal stop):

1. **Disabled** — `NIGHT_HANDOFF_DISABLE` is set → exit 0.
2. **Loop guard** — `stop_hook_active == true` → exit 0. This `Stop` *is* the
   handoff's own turn ending; never recurse.
3. **Outside window** — current hour in `NIGHT_HANDOFF_TZ` is not within
   `[START, END)` → exit 0.
4. **Short turn** — `now − mtime(<session_id>.lastinput) < IDLE_MIN` minutes →
   exit 0 (user was active / turn was quick). If the marker is missing, treat as
   short (exit 0) — we never saw a user turn this session.
5. **Cooldown** — `<session_id>.handoff` exists and was written within
   `COOLDOWN_H` hours → exit 0 (already handed off recently this session).

If none match: record the handoff marker (touch `<session_id>.handoff`) **before**
emitting, then print the block decision and exit 0:

```json
{"decision": "block", "reason": "<instruction, see below>"}
```

### The injected instruction

Concise, and explicitly scoped to prevent the continuation from starting new work:

> A long-running turn just finished during the user's overnight window and they
> are likely away. Before stopping, create a handoff so they can resume cheaply
> in the morning:
> 1. Invoke the `handoff` skill to write a handoff document capturing what was
>    done, the current state, and the next steps.
> 2. Then output a short, paste-ready resume prompt the user can run in a fresh
>    session — prefer `/pickup`, and reference the handoff document's path.
>
> Keep it concise. Do **not** start any new work — only write the handoff and the
> resume prompt, then stop.

The continuation turn ends with `stop_hook_active == true`, so guard 2 short-
circuits the next `Stop` and there is no loop. The cooldown marker is a second
line of defence.

## Configuration (env vars, with defaults)

| Var | Default | Meaning |
|-----|---------|---------|
| `NIGHT_HANDOFF_TZ` | `Europe/London` | Timezone the window is measured in (DST-aware). |
| `NIGHT_HANDOFF_START` | `1` | Window start hour (inclusive). |
| `NIGHT_HANDOFF_END` | `9` | Window end hour (exclusive). |
| `NIGHT_HANDOFF_IDLE_MIN` | `15` | Min turn duration (minutes) to count as "user away". |
| `NIGHT_HANDOFF_COOLDOWN_H` | `6` | No repeat handoff within this many hours per session. |
| `NIGHT_HANDOFF_DISABLE` | _(unset)_ | Any non-empty value disables the hook. |
| `NIGHT_HANDOFF_NOW` | _(unset)_ | Test seam: overrides "current hour" (0–23) for the window check. |
| `NIGHT_HANDOFF_STATE_DIR` | `~/.claude/state/night-handoff` | Test seam: overrides the state directory. |

The window check reads `NIGHT_HANDOFF_NOW` if set, otherwise
`TZ="$NIGHT_HANDOFF_TZ" date +%H`. This makes the window branch unit-testable
without waiting for 2 AM.

## Installer changes (`install.sh`)

1. Copy `hooks/` → `~/.claude/hooks/`, `chmod +x` the script.
2. Idempotently wire both events into `~/.claude/settings.json` via `jq`, using
   absolute installed paths (mirrors how the statusline is wired). The wiring
   **must preserve any pre-existing `Stop` / `UserPromptSubmit` hooks** — append
   our matcher entry only if an entry pointing at `night-handoff.sh` is not
   already present, rather than overwriting `.hooks.Stop`.
3. Add the hook to the "Setup complete" summary block.

Hook config shape written into `settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "<CLAUDE_DIR>/hooks/night-handoff.sh touch" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "<CLAUDE_DIR>/hooks/night-handoff.sh stop" }] }
    ]
  }
}
```

## Documentation

Add a "Night handoff hook" section to `README.md` describing the behaviour, the
env-var configuration table, and the kill switch.

## Testing

A bash test harness (e.g. `hooks/tests/night-handoff.test.sh`) that, for each
branch, pipes mock stdin JSON into the script with a temp state dir
(`HOME` / state path override), the relevant `NIGHT_HANDOFF_*` envs, and
`NIGHT_HANDOFF_NOW`, then asserts stdout/exit code:

- `touch` creates/updates `<session_id>.lastinput`.
- `stop` exits 0 silently when: disabled; `stop_hook_active`; outside window;
  short turn (recent `lastinput`); missing `lastinput`; cooldown active.
- `stop` emits a `decision:block` JSON and writes `<session_id>.handoff` when:
  in window, long turn, no recent handoff.

Time is injected via `NIGHT_HANDOFF_NOW` and via setting marker-file mtimes with
`touch -d`, so tests are deterministic and fast.

## Out of scope — keepalive (won't-do, infeasible)

The user proposed a complementary keepalive during *non-sleep* hours: when idle
and approaching cache expiry, ping the session to keep the prompt cache warm.
This is **not buildable** with the current hook surface:

- Keeping the cache warm requires re-running a turn over the cached context.
  Nothing outside the live CLI can trigger that — the prompt cache is internal to
  the running conversation, with no hook or CLI command to "ping" it.
- The `Notification` hook fires on idle but can only run a side-effect (e.g. a
  desktop notification), not a model turn.
- Economics are inverted: repeated warm cache-reads across hours cost *more* than
  a single cold reload.

The cheap-resume path is the handoff document plus the `pickup` skill. Recorded
here so the idea is not re-litigated.
