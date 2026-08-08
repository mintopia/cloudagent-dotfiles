# Decision: Auto-start Harmonic via a SessionStart hook with a private forward

Status: accepted
Date: 2026-08-08

## Context

[Harmonic](https://github.com/mintopia/harmonic) is an agent UI / task scheduler
that queues, runs, and reviews autonomous coding-agent tasks. In a Cloud Agent
workspace it should be available whenever the workspace is, as a single instance,
reachable over a private HTTPS URL.

Relevant facts about Harmonic:

- It runs straight from GitHub via `npx github:mintopia/harmonic` (first run
  clones + builds, ~1-2 min; then starts from the npx cache).
- `harmonic start` runs it as a background daemon (state/logs in `~/.harmonic`)
  and is a **singleton** — it refuses to start if a daemon is already running.
- It listens on port 4700 and binds `0.0.0.0` by default.
- Browser-facing services in a Cloud Agent workspace must be exposed via
  `cloudagent http-forwards` (TLS-terminated HTTPS); `--private` requires auth to
  reach the URL. The forward proxy can only reach a server bound to `0.0.0.0`.

## Decision

Install a `SessionStart` hook (`hooks/harmonic-start.sh`) that, inside a Cloud
Agent workspace, ensures Harmonic is running and privately forwarded.

- Start the daemon with `npx -y github:mintopia/harmonic start`, detached so a
  first-run build never blocks session start. Single-instance is inherited from
  Harmonic's own `start` guard — no extra locking in the hook.
- Ensure a private HTTPS forward on the `harmonic` hostname
  (`cloudagent http-forwards add --container 4700 --hostname harmonic --private`),
  added only when one for the hostname is not already present.
- Surface the private URL to Claude via `additionalContext`.
- Wire it as a second `SessionStart` entry in `settings-hooks.jq`, alongside
  cloudagent-skill. `install.sh` warms the npx build once so the first real
  session starts instantly. Kill switch: `HARMONIC_HOOK_DISABLE`.

Harmonic runs ungated; the `--private` forward is the auth boundary. Binding
`0.0.0.0` is required for the forward and is acceptable in a single-tenant
workspace. (Setting `HARMONIC_PASSWORD` for defense-in-depth was considered and
declined for now.)

## Consequences

Harmonic is available on a stable private `harmonic` URL from the first session
onward, with exactly one daemon regardless of how many sessions or subagents
start. The hook is best-effort (`set -uo pipefail`, no `-e`) so a Harmonic or
network failure never breaks a session. There is no `--cleanup` path for hooks;
retiring Harmonic later means removing the hook and its wiring, and the running
daemon is left to `harmonic stop`.

## Supersedes

None
