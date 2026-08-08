# Decision: Externalize grill/codex skills to tsmura/grill-me-codex

Status: accepted
Date: 2026-08-08

## Context

`grill-me-codex` and `grill-with-docs-codex` were vendored custom skills in
this repo (`skills/grill-me-codex/`, `skills/grill-with-docs-codex/`,
each with their own `evals/`, fixtures, and notices). The guiding rule for
this v2 pass is to keep only genuinely custom skills vendored, and install
everything third-party via `npx skills add` where possible. Both of these
skills originate from Matt Pocock's `grill-me` design and are now maintained
upstream at `tsmura/grill-me-codex`, which also ships a third skill this repo
did not previously have: `codex-plan-review`. A fourth skill in that source,
`codex-build`, has a broken `SKILL.md` (YAML parse error) upstream and is
skipped automatically by `npx skills add`.

Vendoring gave this repo no behavior that the upstream source doesn't already
provide, only the maintenance cost of keeping vendored copies, their evals,
and their fixtures in sync by hand.

Continued vendoring was rejected: it is the status quo this decision is
moving away from, and it works against the guiding rule of this v2 pass.

## Decision

Drop the vendored `skills/grill-me-codex/` and `skills/grill-with-docs-codex/`
directories. Add `tsmura/grill-me-codex` to `THIRDPARTY_SKILLS` in
`install.sh`, installed via `npx skills add … -g -y --copy` like the other
third-party sources. This installs all valid skills from that source:
`grill-me-codex`, `grill-with-docs-codex`, and `codex-plan-review`.
`codex-build` is skipped automatically because it fails upstream.

`codex-plan-review` intentionally coexists with this repo's own vendored
`codex-review` skill. They are not duplicates: `codex-review` is a
purpose-built, workspace-specific plan-review loop kept in `skills/` per the
guiding rule, while `codex-plan-review` is the upstream tsmura equivalent
pulled in as part of the same source. Both remain available side by side.

## Consequences

Two fewer vendored skill trees (including their evals and fixtures) to
maintain by hand; updates to `grill-me-codex` and `grill-with-docs-codex` now
arrive via `npx skills add` re-runs instead of manual porting. Because both
skills keep the same names after re-sourcing, they are not added to
`DEPRECATED_SKILLS` — the `--copy` install replaces them in place, and a
cleanup entry would only remove-then-reinstall for no benefit. Users get
`codex-plan-review` as a new, unrequested addition, and now have two
similarly-named plan-review skills (`codex-review` and `codex-plan-review`)
installed side by side, which should be documented in the README to avoid
confusion.

## Supersedes

None
