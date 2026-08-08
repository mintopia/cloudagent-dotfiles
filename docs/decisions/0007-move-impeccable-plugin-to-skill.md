# Decision: Move impeccable from a plugin to an npx skill

Status: accepted
Date: 2026-08-08

## Context

`impeccable` (frontend design/critique) was installed as a Claude Code plugin
from the `pbakaus/impeccable` marketplace, which `install.sh` added solely for
that plugin. The v2 guiding rule is to keep our own skills vendored and install
everything third-party via `npx skills add` where possible, preferring skills
over plugins when a component is a self-contained skill.

`npx skills add pbakaus/impeccable --list` confirms the repo publishes a single
self-contained skill with no MCP server and no hooks — it converts cleanly.

`context-mode` was considered for the same treatment and deliberately excluded:
its skills wrap the `ctx_*` MCP server tools and a PreToolUse routing hook that
only the plugin provides, so as a bare npx skill it would be non-functional.

## Decision

Install `impeccable` as an npx skill instead of a plugin; keep `context-mode`
a plugin.

- Remove the `add_marketplace "pbakaus/impeccable"` and
  `install_plugin "impeccable"` lines from `install.sh`.
- Add `[pbakaus/impeccable]="impeccable skill"` to `THIRDPARTY_SKILLS`.
- Add `impeccable@impeccable` to `DEPRECATED_PLUGINS` and `impeccable` to
  `DEPRECATED_MARKETPLACES` so `./install.sh --cleanup` retires the old plugin
  and its now-unused marketplace from machines that already have them (the
  marketplace was added only for this plugin, and nothing else needs it).

## Consequences

One fewer plugin and marketplace to manage; impeccable now lives in
`~/.claude/skills` like the other npx skills, consistent with the v2 rule.
`context-mode` remains a plugin because its runtime tooling requires it. Existing
machines keep the impeccable plugin until `./install.sh --cleanup` is run there,
consistent with 0002.

## Supersedes

None
