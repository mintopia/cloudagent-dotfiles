# Decision: Build the grill UI on visual-companion, with persistent per-project forwards

Status: accepted
Date: 2026-10-13

## Context

Grilling (`grill-me`, `grill-with-docs`) is the most-used workflow, and long rounds of numbered questions are hard to read and answer in the terminal. We want a browser page that renders each Round, collects a Submission, and carries on into `/to-spec` or `/to-tickets`.

The grill skills come from `mattpocock/skills` and `install.sh` overwrites them on every install, so they can't be patched. `visual-companion` already provides a key-protected server, a Cloud Agent HTTP forward, a `wss://` upgrade with REST fallback, tmux persistence and a per-project port and key.

## Decision

- Add local entry skills that compose the latest upstream skills (`grilling`, `domain-modeling`) with a shared UI-protocol skill, instead of forking upstream content.
- Add a grill mode to `visual-companion` as a separate server module beside the vendored upstream server, rather than writing a separate skill's server or using a claude.ai Artifact. It serves structured JSON Rounds and `POST /submit`, and reuses the patched `helper.js` and the Cloud Agent wrappers. The upstream files stay unmodified, as ADR-0014 requires.
- Give each project its own port (already saved per project) and its own forward hostname (`grill-<project>`), handled in the wrappers. Keep the forward when the server stops, so the URL stays the same across restarts and sessions. This applies to plain visual-companion use as well.

## Consequences

One forward lifecycle to maintain, and upstream re-syncs stay easy. Multiple projects in one workspace run independently. Forwards are no longer cleaned up on stop, which overrides the cleanup consequence in ADR-0001: idle forwards stay until removed by hand. Upstream changes to the grill skills are picked up automatically, but the UI protocol must stay generic enough to survive them.

## Supersedes

None (amends the cleanup consequence of 0001 and the `visual-companion` forward hostname in 0014)
