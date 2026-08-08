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

Statusline, `settings.json`, keybindings, `cloudagent-skill` hook,
decision-memory `AGENTS.md` append, git config, and the `jq_write` / idempotency
machinery.

(The `night-handoff` hook was originally out of scope but is removed in the
amendment below.)

## Testing / verification

- `bash hooks/tests/night-handoff.test.sh` still passes (untouched, but run it).
- Dry-run reasoning: a fresh `./install.sh` installs the new set; `./install.sh
  --cleanup` additionally removes caveman family + quality-gate.
- Confirm `frontend-design` installs from the default marketplace without an
  explicit `marketplace add`.
- Confirm `@openai/codex` install is idempotent (no error on re-run).

---

## Amendment (2026-08-08): impeccable → skill; remove night-handoff

Two follow-on changes decided after the initial tasks landed.

### A. Move `impeccable` from a plugin to an npx skill

`impeccable` is a single self-contained skill (no MCP, no hooks) — confirmed via
`npx skills add pbakaus/impeccable --list` (1 skill). It converts cleanly.

- **install.sh:** remove the `add_marketplace "pbakaus/impeccable" "impeccable"`
  line and the `install_plugin "impeccable" "impeccable"` line. Add
  `[pbakaus/impeccable]="impeccable skill"` to `THIRDPARTY_SKILLS`.
- **Summary block:** plugins line → `context-mode, frontend-design`; 3p line
  adds impeccable.
- **Cleanup wiring:** add `impeccable@impeccable` to `DEPRECATED_PLUGINS` and
  `impeccable` to `DEPRECATED_MARKETPLACES` (this script was the only thing that
  added that marketplace, and nothing else needs it once the plugin is gone).
- **README:** move impeccable from Plugins to the Skills section.

`context-mode` **stays a plugin** — its skills wrap the `ctx_*` MCP server and a
PreToolUse routing hook that only the plugin provides; as a bare skill it would
be non-functional.

### B. Remove the `night-handoff` hook entirely

Not used; the Stop hook gets in the way. Removed from the repo (the live
workspace is left untouched per the user's choice).

- **install.sh:** drop the `night-handoff.sh` copy/chmod; in the hook-wiring
  `jq_write`, pass only `session_start_cmd` (drop `stop_cmd` / `touch_cmd`).
  Update the summary block's Hooks line to just `cloudagent-skill`.
- **Delete** `hooks/night-handoff.sh`.
- **hooks/settings-hooks.jq:** remove the `Stop` and `UserPromptSubmit`
  `add_hook` lines and their `$stop_cmd`/`$touch_cmd` args; keep `SessionStart`.
- **Tests:** `hooks/tests/night-handoff.test.sh` tests both hooks. Extract the
  cloudagent-skill tests into `hooks/tests/cloudagent-skill.test.sh` and delete
  the night-handoff test file.
- **README:** delete the entire "Night handoff hook" section; fix the
  "Cloudagent skill hook" section's test-command reference to the new test file;
  update any hook summary/structure references.

### Cleanup wiring (amended)

- `DEPRECATED_PLUGINS`: `superpowers@claude-plugins-official`, **`impeccable@impeccable`**.
- `DEPRECATED_MARKETPLACES`: **`impeccable`**.
- (night-handoff is a hook, not a plugin/skill/marketplace — there is no
  `--cleanup` path for hooks, and the live workspace is intentionally untouched.)

### C. Install the "I Have ADHD" output style

The user has an output style (`i-have-adhd.md`, frontmatter `name: I Have ADHD`,
`keep-coding-instructions: true`). Classic standalone output styles are
**deprecated** in Claude Code 2.1.226 (`/output-style` removed in 2.1.73);
Anthropic's successor styles ship as plugins that inject the style via a
`SessionStart` hook emitting `additionalContext`. Because the file keeps coding
instructions, a SessionStart injection is a faithful equivalent.

- **Vendor** the file at `config/output-styles/i-have-adhd.md`.
- **Add** `hooks/adhd-output-style.sh` — a `SessionStart` hook that strips the
  YAML frontmatter from the installed style file and emits the body as
  `additionalContext` (via `jq`, mirroring `cloudagent-skill.sh`). Guarded by
  `ADHD_OUTPUT_STYLE_DISABLE` kill switch.
- **install.sh:** copy the style to `~/.claude/output-styles/i-have-adhd.md`
  (future-proofing) and the hook to `~/.claude/hooks/`; wire a second
  `SessionStart` `add_hook` in `settings-hooks.jq`.
- **settings-hooks.jq:** add `--arg adhd_cmd` and a second
  `add_hook("SessionStart"; $adhd_cmd)`.
- **README + summary:** document the output style and hook.

### ADRs (amendment)

- 0007: move impeccable from plugin to npx skill (context-mode stays a plugin).
- 0008: remove the night-handoff hook.
- 0009: install the ADHD output style via a SessionStart injection hook (classic
  output styles deprecated).
