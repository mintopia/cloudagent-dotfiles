# v2: Install strip-back — design

**Date:** 2026-08-08
**Status:** Approved (design), pending implementation
**Baseline:** tag `v1` (`ff72492`)

## Goal

Strip back and re-source the skill/plugin set installed by `install.sh`.
Fewer vendored skills, more third-party skills pulled via `npx skills add`,
one new plugin, and one new CLI dependency. Everything not about
skills/plugins/deps is unchanged.

The guiding rule (from the user): **keep our own custom skills vendored in this
repo; install everything third-party via `npx skills add` where possible.**

## End state

### Plugin marketplaces
- `impeccable` (`pbakaus/impeccable`) — keep
- `context-mode` (`mksglu/context-mode`) — keep
- `claude-plugins-official` — built-in default marketplace, **not** added by the
  script; it is the source for `frontend-design`.

### Plugins (`claude plugin install`)
- `impeccable` — keep
- `context-mode` — keep
- **`frontend-design@claude-plugins-official`** — NEW. It is a Claude Code
  plugin skill (not the old superpowers one), installed like the others.

### MCP servers
- `jcodemunch` — keep (pipx, falling back to pip).

### npm globals (NEW category)
- **`@openai/codex`** — the OpenAI Codex CLI. Dependency for the custom
  `codex-review` skill and the tsmura grill/codex skills. Installed globally
  via `npm i -g @openai/codex` (idempotent: skip if already on `PATH`).

### Third-party skills (`npx skills add … -g -y --copy`)
- **`mattpocock/skills`** — install **all** skills (`--skill '*'`), was a
  curated 18. (`mattpocock-skills` also exists as a plugin in
  claude-plugins-official, but the npx-where-possible rule keeps it on npx.)
- **`DietrichGebert/ponytail`** — keep, whole family.
- **`tsmura/grill-me-codex`** — NEW source. Install **all valid** skills:
  `grill-me-codex`, `grill-with-docs-codex`, `codex-plan-review`.
  `codex-build` is broken upstream (SKILL.md YAML parse error) and is skipped
  automatically by `npx skills add`.
- **caveman is dropped** — removed from the third-party install list entirely.

### Skills CLI built-in finder
- `npx skills find [query]` is the "skills-finder" — built into the `skills`
  CLI, nothing to install. Documented in the README as the discovery tool.

### Custom skills kept in the repo (local copy loop → `~/.claude/skills`)
7 skills, unchanged mechanism:
`adr`, `cloudagent`, `codex-review`, `deep-analysis`, `pickup`,
`subagent-finder`, `roast`.

(`roast` already shipped in v1 but was missing from the README — v2 documents
it.)

## Changes from v1

### Removed
| Component | Was | v2 |
|-----------|-----|----|
| `caveman` (whole family) | third-party via npx | dropped entirely |
| `quality-gate` | vendored custom skill | dropped entirely |
| `grill-me-codex` (vendored) | vendored custom skill | re-sourced from tsmura |
| `grill-with-docs-codex` (vendored) | vendored custom skill | re-sourced from tsmura |
| Matt Pocock `--skill` filter | curated 18 | all skills |
| cloudagent kanban system | in cloudagent SKILL.md + references/kanban.md | removed from the skill |

### Added
- `frontend-design` plugin.
- `@openai/codex` npm global.
- `tsmura/grill-me-codex` npx skill family (incl. `codex-plan-review`, which
  intentionally coexists with the custom `codex-review`).

## Repo file changes

- **Delete** `skills/grill-me-codex/`, `skills/grill-with-docs-codex/`,
  `skills/quality-gate/` (and their `evals/`, `THIRD-PARTY-NOTICES.md`,
  `ADR-FORMAT.md`, `CONTEXT-FORMAT.md`, fixtures).
- **Edit** `install.sh`:
  - Add `frontend-design` to the plugins section.
  - Add an npm-globals section installing `@openai/codex` (idempotent).
  - Matt Pocock: replace the curated `--skill $MATT_SKILLS` with `--skill '*'`
    (drop the `MATT_ENGINEERING`/`MATT_PRODUCTIVITY` lists).
  - `THIRDPARTY_SKILLS`: drop `JuliusBrussee/caveman`; keep
    `DietrichGebert/ponytail`; add `tsmura/grill-me-codex`.
  - Update the final summary block (plugins, npm, skills lines).
  - Cleanup wiring — see below.
- **Edit** `README.md`: reflect all of the above (drop caveman/quality-gate/
  vendored-grill sections; add frontend-design, `@openai/codex`, tsmura grills,
  `skills find`, `roast`; update the structure tree and "Currently retired").
- **Add** ADRs under `docs/decisions/` for the notable decisions (see below).

## Cleanup wiring (`--cleanup`)

The `DEPRECATED_*` arrays retire components from machines that already have them.
Cleanup runs before install, so a re-source (same name) is remove-then-reinstall.

- `DEPRECATED_PLUGINS`: `superpowers@claude-plugins-official` (existing, keep).
- `DEPRECATED_MARKETPLACES`: none.
- `DEPRECATED_SKILLS`: `local-llm-development` (existing) **plus**:
  - `quality-gate`
  - the caveman family: `caveman`, `caveman-commit`, `caveman-review`,
    `caveman-compress`, `caveman-stats`, `cavecrew`, `caveman-help`
    — **verify exact installed dir names at implementation time** via
    `npx skills add JuliusBrussee/caveman --list`.
- **Not** added to cleanup: `grill-me-codex`, `grill-with-docs-codex`. They keep
  the same names and are replaced in place by the tsmura `--copy` install, so a
  cleanup entry would only remove-then-reinstall for no benefit.

## ADRs to record (during implementation)

Under `docs/decisions/` (next sequential numbers after 0002):
1. Add `frontend-design` as a plugin (vs superpowers / vendoring).
2. Externalize grill/codex skills to `tsmura/grill-me-codex` via npx (vs
   vendoring).
3. Drop `caveman` and `quality-gate`.
4. Install all Matt Pocock skills (vs a curated subset).

## Out of scope (unchanged)

Statusline, `settings.json`, keybindings, `night-handoff` hook,
`cloudagent-skill` hook, decision-memory `AGENTS.md` append, git config, and the
`jq_write` / idempotency machinery.

## Testing / verification

- `bash hooks/tests/night-handoff.test.sh` still passes (untouched, but run it).
- Dry-run reasoning: a fresh `./install.sh` installs the new set; `./install.sh
  --cleanup` additionally removes caveman family + quality-gate.
- Confirm `frontend-design` installs from the default marketplace without an
  explicit `marketplace add`.
- Confirm `@openai/codex` install is idempotent (no error on re-run).
