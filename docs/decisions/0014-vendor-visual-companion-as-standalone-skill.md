# Decision: Vendor the visual companion as a standalone Cloud Agent-aware skill

Status: accepted
Date: 2026-08-27

## Context

`0002-drop-superpowers-and-retire-via-cleanup-flag.md` dropped the superpowers
plugin: its skill-invocation discipline does not match this workspace and it
competes with purpose-built skills here. `superpowers@claude-plugins-official` is
in `DEPRECATED_PLUGINS`, so `./install.sh --cleanup` removes it.

The plugin's brainstorming skill shipped a genuinely useful, self-contained
sub-tool that has nothing to do with that discipline: the **visual companion** — a
local web server that serves HTML mockups/diagrams to the user's browser and
records their clicks. It is the only piece worth keeping, and today it survives
only because `--cleanup` has not been run on this machine. Once superpowers is
purged it disappears.

ADR 0002 already anticipated the Cloud Agent angle: it kept the `wss://` and
`0.0.0.0` binding guidance in the `cloudagent` skill because that is a property of
Cloud Agent HTTP forwards, not of the companion. Those manual steps live in the
`cloudagent-env` skill, but they are easy to forget and one of them (the
`ws://`→`wss://` patch) fails silently — the page loads and only interactivity
dies, with nothing in the log.

## Decision

Vendor the visual companion into this repo as a standalone skill at
`skills/visual-companion/`, independent of superpowers and of brainstorming. The
`install.sh` skills loop already auto-discovers `skills/*/` and copies `SKILL.md`
plus `scripts/`, so no installer change is needed. It installs everywhere (not
gated on Cloud Agent) because the launcher self-detects the environment.

Scope: a **general** visual companion. Its description triggers on any design,
frontend, or architecture discussion where a question is better seen than read —
not tied to a brainstorming flow.

The upstream server is vendored **unmodified** (`server.cjs`, `start-server.sh`,
`stop-server.sh`, `frame-template.html`) so it stays easy to re-sync. Two
Cloud Agent adaptations are baked in instead of left as manual steps:

1. **`helper.js` is patched** to derive the WebSocket scheme from
   `window.location.protocol` — `wss://` on https pages, `ws://` on plain http.
   This is the one fix that must live in the client, and it works both behind a
   TLS forward and on plain localhost ("works if not https").
2. **`start-companion.sh` / `stop-companion.sh` wrappers** detect a Cloud Agent
   workspace (`CLOUDAGENT_API_URL` + the `cloudagent` CLI). On Cloud Agent they
   bind `0.0.0.0`, create/reuse an `http-forward` on the `visual-companion`
   hostname, and rewrite the returned URL to the public `https://…/?key=…`. Off
   Cloud Agent they `exec` the plain upstream scripts unchanged.

This does **not** revive superpowers or its discipline, and does not supersede
0002 — the plugin stays deprecated and `--cleanup` still purges it.

## Consequences

The companion outlives the superpowers purge and works out of the box in this
Cloud Agent workspace with no manual forward/patch steps, while remaining usable
on a plain laptop.

Keeping the upstream server files unmodified means future fixes can be re-copied
from the plugin cache; only `helper.js` carries a one-line local patch that must
be re-applied on any re-sync (noted at the patched line and in `SKILL.md`).

The companion's browser flow can overlap with the terminal-based hardening skills
(`grill-*`, `deep-analysis`) — the `description` draws the line explicitly: visual
questions only, text/tabular decisions stay in the terminal.

The `cloudagent-env` skill's "Superpowers visual companion" section now describes
manual steps that the vendored skill automates; it can be trimmed to point at
this skill in a follow-up, but is left as-is here to keep this change scoped.

## Supersedes

None. Amends the carve-out noted in
`0002-drop-superpowers-and-retire-via-cleanup-flag.md`.
