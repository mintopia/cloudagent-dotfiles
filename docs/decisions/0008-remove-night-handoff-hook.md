# Decision: Remove the night-handoff hook

Status: accepted
Date: 2026-08-08

## Context

`hooks/night-handoff.sh` was a pair of hooks — a `UserPromptSubmit` hook that
stamped a per-session marker and a `Stop` hook that, for long unattended turns
finishing inside an overnight window, returned a `decision:block` forcing Claude
to write a resumption trail. It aimed to avoid a cold full-context `/resume` in
the morning.

In practice the feature is not used, and the `Stop` hook's `decision:block`
behaviour interrupts normal turns. The v2 pass is stripping the install surface
back to what is actually wanted.

The night-handoff and cloudagent-skill hooks shared one test file
(`hooks/tests/night-handoff.test.sh`) and one wiring filter
(`hooks/settings-hooks.jq`), so removing night-handoff means untangling both.

## Decision

Remove the night-handoff hook entirely from the repo.

- Delete `hooks/night-handoff.sh`.
- `install.sh`: drop the script copy and the `Stop`/`UserPromptSubmit` wiring;
  the hook-wiring `jq_write` now passes only `session_start_cmd`.
- `hooks/settings-hooks.jq`: keep only the `SessionStart` `add_hook`
  (cloudagent-skill); drop the `Stop` and `UserPromptSubmit` entries.
- Split the tests: the cloudagent-skill and jq tests move to
  `hooks/tests/hooks.test.sh`; delete `hooks/tests/night-handoff.test.sh`.

There is no `--cleanup` path for hooks, and the user opted to leave the current
live workspace untouched, so this only affects future installs.

## Consequences

A simpler hook surface: one `SessionStart` hook (cloudagent-skill) and no
`Stop`/`UserPromptSubmit` interception. Fresh installs no longer wire
night-handoff. Machines that already wired it keep it until manually removed,
since hooks have no `--cleanup` retirement path.

## Supersedes

None
