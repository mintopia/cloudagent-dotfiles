# Decision: Install all mattpocock/skills

Status: accepted
Date: 2026-08-08

## Context

`install.sh` previously installed a hand-curated subset of 18 skills from
`mattpocock/skills`, selected via `MATT_ENGINEERING` and `MATT_PRODUCTIVITY`
lists and passed to `npx skills add` with an explicit `--skill $MATT_SKILLS`
filter. Every time upstream added, renamed, or reorganized a skill, this
repo's curated list needed a matching manual edit or it silently drifted out
of date — installing skills that no longer existed under those names, or
missing new ones the curated list was never updated to include.

Maintaining a curated list was rejected as the ongoing approach: it is
drift-prone by construction, requires someone to notice upstream changes and
update two hardcoded lists in `install.sh`, and the cost of that upkeep
outweighs the benefit of trimming an already-optional third-party skill set.

## Decision

Install all skills from `mattpocock/skills` via `npx skills add --skill '*'`,
replacing the curated filter. Drop the `MATT_ENGINEERING` and
`MATT_PRODUCTIVITY` arrays from `install.sh` entirely.

`mattpocock-skills` also exists as a plugin in `claude-plugins-official`, but
per the guiding rule for this v2 pass (install third-party where possible via
`npx skills add`, not plugins), the npx source stays the install path rather
than switching to the plugin.

## Consequences

No more manual curation or drift between upstream and this repo's list — a
fresh install always matches whatever `mattpocock/skills` currently ships.
The trade-off is a larger, less-curated set of installed skills, some of
which may be irrelevant to any given workspace; that is accepted as a cheap
cost relative to the maintenance burden it replaces.

## Supersedes

None
