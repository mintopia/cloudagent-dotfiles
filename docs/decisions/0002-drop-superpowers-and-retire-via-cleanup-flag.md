# Decision: Drop superpowers, and retire components via an opt-in --cleanup flag

Status: accepted
Date: 2026-07-17

## Context

The superpowers plugin mandates a skill-invocation discipline — brainstorming
before planning, a required skill check before any response including clarifying
questions — that does not match how this workspace actually works. It also
competes with the skills in this repo that cover the same ground on purpose-built
terms: `grill-me-codex` and `grill-with-docs-codex` for plan hardening,
`deep-analysis` for high-stakes reasoning, `quality-gate` for red-suite
enforcement, and `pickup` for cheap session resumption.

Removing it exposed a gap in `install.sh`: the script only ever added and
updated. Deleting the `install_plugin "superpowers"` line stops *new* machines
getting it, but every machine that already ran the installer keeps it forever.
Uninstalling by hand does not scale past one machine and is not reproducible,
which is the whole point of a dotfiles repo.

An always-on purge was rejected: a dotfiles installer that silently deletes
things on every run is surprising, and the blast radius of a typo in a removal
list is much worse than the cost of typing a flag.

## Decision

These dotfiles no longer install superpowers.

Retirement is handled by `./install.sh --cleanup`, which purges the entries in
the `DEPRECATED_PLUGINS`, `DEPRECATED_MARKETPLACES`, and `DEPRECATED_SKILLS`
arrays at the top of `install.sh`, then continues with a normal install. A plain
`./install.sh` run is unchanged and never removes anything.

Retiring a component in future means adding one line to the relevant array —
not writing bespoke removal code.

Purging a plugin also deletes its marketplace cache, which
`claude plugin uninstall` leaves behind (megabytes per plugin). The marketplace
itself is left alone, since other plugins usually still need it.

## Consequences

Removals become reproducible and reviewable rather than manual, and the lists
double as a record of what was retired and when.

The flag is opt-in, so an existing machine keeps a retired component until
someone runs `--cleanup` there. That is the accepted trade for a plain install
never deleting anything.

The cache purge derives its path from Claude Code's internal
`plugins/cache/<marketplace>/<plugin>` layout. This is deliberately best-effort:
a cache is regenerable, so if that layout changes the purge silently does nothing
rather than failing the run.

The `local-llm-development` skill was removed alongside superpowers — it was
built around the superpowers plan lifecycle (`writing-plans`,
`subagent-driven-development`, `finishing-a-development-branch`) and does not
stand up without it. `docs/superpowers/` was removed for the same reason. The
`cloudagent` skill kept its `wss://` and `0.0.0.0` binding guidance, which is a
property of Cloud Agent HTTP forwards rather than of the visual companion, and
is consistent with `0001-serve-js-html-via-http-forward.md`.

## Supersedes

None
