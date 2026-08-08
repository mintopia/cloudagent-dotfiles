# Decision: Add the frontend-design plugin from claude-plugins-official

Status: accepted
Date: 2026-08-08

## Context

Frontend/UI review and polish work (visual hierarchy, layout, accessibility,
theming, component critique) is a recurring task in this workspace, and
nothing in the current skill/plugin set covers it on purpose-built terms.
`impeccable` covers some of the same ground but is a separate third-party
plugin the user runs alongside it, not a replacement for it.

Claude Code ships a built-in default marketplace, `claude-plugins-official`,
which includes a `frontend-design` plugin skill maintained by Anthropic. It
installs the same way as the other two plugins already in `install.sh`
(`impeccable`, `context-mode`) and needs no `marketplace add` step, since the
marketplace is built in.

Two alternatives were rejected. Re-adding superpowers was rejected because
`0002-drop-superpowers-and-retire-via-cleanup-flag.md` already removed it for
reasons unrelated to frontend work, and pulling it back in for one skill
would reintroduce the whole discipline this repo dropped it for. Vendoring a
custom frontend-review skill was rejected because it would duplicate
maintenance the plugin's upstream already does, with no workspace-specific
behavior to justify owning it.

## Decision

Install `frontend-design@claude-plugins-official` via `claude plugin install`,
alongside `impeccable` and `context-mode`, in the plugins section of
`install.sh`. No marketplace registration step is needed since
`claude-plugins-official` is the built-in default marketplace.

## Consequences

Frontend/UI work gains a purpose-built skill without vendoring code or
reintroducing superpowers. The plugin is maintained upstream by Anthropic, so
this repo has no update burden for it beyond the existing `claude plugin
install` idempotency the other plugins already rely on.

## Supersedes

None
