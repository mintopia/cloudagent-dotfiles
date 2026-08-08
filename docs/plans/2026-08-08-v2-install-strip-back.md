# v2 Install Strip-Back Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-source and strip back the skill/plugin set in `install.sh` per the v2 design spec.

**Architecture:** `install.sh` is an idempotent bash installer. Changes are localised edits to its plugin, MCP/dep, skill, cleanup, and summary sections, plus deleting three vendored skill dirs, updating the README, and recording ADRs. No runtime code, so verification is `bash -n` syntax checks + `grep` assertions on the edited script + one live `npx --list` lookup for exact cleanup names.

**Tech Stack:** bash, jq (already used), `npx skills`, `npm`, `claude plugin` CLI.

## Global Constraints

- Spec: `docs/specs/2026-08-08-v2-install-strip-back-design.md` (verbatim source of truth).
- Rule: keep custom skills vendored in this repo; install third-party via `npx skills add` where possible.
- `install.sh` must stay idempotent and safe to re-run; never truncate user files.
- `claude-plugins-official` is a built-in default marketplace — do NOT `marketplace add` it.
- Custom skills kept vendored (7): `adr`, `cloudagent`, `codex-review`, `deep-analysis`, `pickup`, `subagent-finder`, `roast`.
- Every commit message ends with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.
- Work happens on the `develop` branch.

---

### Task 1: Delete dropped vendored skills

**Files:**
- Delete: `skills/grill-me-codex/` (SKILL.md, THIRD-PARTY-NOTICES.md)
- Delete: `skills/grill-with-docs-codex/` (SKILL.md, THIRD-PARTY-NOTICES.md, ADR-FORMAT.md, CONTEXT-FORMAT.md)
- Delete: `skills/quality-gate/` (SKILL.md, evals/ and fixtures/)

**Interfaces:**
- Produces: a `skills/` dir containing exactly the 7 kept custom skills.

- [ ] **Step 1: Remove the three directories**

```bash
git rm -r skills/grill-me-codex skills/grill-with-docs-codex skills/quality-gate
```

- [ ] **Step 2: Verify only the 7 kept skills remain**

Run: `ls skills/`
Expected: `adr  cloudagent  codex-review  deep-analysis  pickup  roast  subagent-finder`

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
refactor(skills): drop vendored grill-*-codex and quality-gate

grill skills move to tsmura/grill-me-codex via npx; quality-gate is
dropped entirely (see docs/specs/2026-08-08-v2-install-strip-back-design.md).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: install.sh — add frontend-design plugin and @openai/codex

**Files:**
- Modify: `install.sh` (plugins section ~L194-198; new npm-deps block after the MCP section ~L236)

**Interfaces:**
- Consumes: existing `install_plugin` helper (name, marketplace), existing `info/ok/warn/err` log helpers.
- Produces: `frontend-design` installed from `claude-plugins-official`; `@openai/codex` present globally.

- [ ] **Step 1: Add frontend-design to the plugins section**

In the `--- Plugins ---` block, after the two existing `install_plugin` lines, add:

```bash
install_plugin "frontend-design" "claude-plugins-official"
```

(`claude-plugins-official` is a default marketplace, so no `add_marketplace` line is needed.)

- [ ] **Step 2: Add an npm-globals section after the MCP Servers section**

Immediately after the MCP `echo` that closes the jcodemunch block, insert:

```bash
# ---------------------------------------------------------------------------
# npm global dependencies
# ---------------------------------------------------------------------------

info "Installing npm global dependencies..."
if command -v npm &>/dev/null; then
  # @openai/codex — the OpenAI Codex CLI, used by codex-review and the
  # tsmura grill/codex skills. Idempotent: skip if already on PATH.
  if command -v codex &>/dev/null; then
    ok "Already installed: @openai/codex"
  else
    info "Installing @openai/codex..."
    if npm install -g @openai/codex; then
      ok "Installed: @openai/codex"
    else
      err "Failed to install @openai/codex"
    fi
  fi
else
  err "npm not found — cannot install @openai/codex"
fi
echo
```

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n install.sh`
Expected: no output (exit 0)

- [ ] **Step 4: Assert the additions are present**

Run: `grep -c 'frontend-design\|@openai/codex' install.sh`
Expected: `3` or more (one plugin line + at least two codex references)

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): add frontend-design plugin and @openai/codex CLI

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: install.sh — re-source skills (MP all, drop caveman, add tsmura) + summary

**Files:**
- Modify: `install.sh` (Matt Pocock block ~L354-369; `THIRDPARTY_SKILLS` block ~L372-388; summary block ~L408-413)

**Interfaces:**
- Consumes: existing `npx -y skills add … -g -y --copy` pattern, `INSTALLED_SKILLS` array.
- Produces: all MP skills installed; ponytail + tsmura grill family installed; caveman gone; summary reflects reality.

- [ ] **Step 1: Replace the curated Matt Pocock install with all-skills**

Delete the `MATT_ENGINEERING`, `MATT_PRODUCTIVITY`, `MATT_SKILLS` variable lines and the `--skill $MATT_SKILLS` invocation. Replace the whole block with:

```bash
# mattpocock/skills — install ALL skills. (mattpocock-skills also exists as a
# plugin in claude-plugins-official, but the npx-where-possible rule keeps it
# on npx.)
info "Installing all mattpocock/skills..."
if npx -y skills add mattpocock/skills --skill '*' -g -y --copy; then
  ok "Installed mattpocock/skills (all)"
else
  err "Failed to install mattpocock/skills"
fi
echo
```

- [ ] **Step 2: Update THIRDPARTY_SKILLS — drop caveman, add tsmura**

Replace the `declare -A THIRDPARTY_SKILLS=(…)` block contents with:

```bash
declare -A THIRDPARTY_SKILLS=(
  [DietrichGebert/ponytail]="ponytail family"
  [tsmura/grill-me-codex]="grill + codex-plan-review family"
)
```

(The loop already installs each with `npx -y skills add "$repo" -g -y --copy`, which installs all valid skills and skips the broken `codex-build`.)

- [ ] **Step 3: Update the summary block**

In the final `echo "Installed:"` block, change the plugins, MP, and 3p lines to:

```bash
echo "  Plugins:     impeccable, context-mode, frontend-design"
echo "  MCP servers: jcodemunch"
echo "  npm:         @openai/codex"
echo "  Skills:      $skills_joined"
echo "  Skills (mp): all mattpocock/skills"
echo "  Skills (3p): ponytail family, tsmura grill/codex family (via npx skills)"
```

- [ ] **Step 4: Syntax-check**

Run: `bash -n install.sh`
Expected: no output (exit 0)

- [ ] **Step 5: Assert caveman is gone and tsmura is present**

Run: `grep -c 'caveman' install.sh; grep -c 'tsmura/grill-me-codex' install.sh`
Expected: `0` then `1`

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): install all MP skills, re-source grills from tsmura, drop caveman

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: install.sh — wire --cleanup for caveman family + quality-gate

**Files:**
- Modify: `install.sh` (`DEPRECATED_SKILLS` array ~L63-65)

**Interfaces:**
- Consumes: existing `remove_skill` helper (removes `~/.claude/skills/<name>`), existing `DEPRECATED_SKILLS` array + summary derivation.
- Produces: `--cleanup` removes quality-gate and the caveman family.

- [ ] **Step 1: Look up the exact caveman family skill dir names**

Run: `npx -y skills add JuliusBrussee/caveman --list 2>&1 | grep -iE '^\s*│?\s*caveman|cavecrew' `
Expected: the installable skill names (e.g. `caveman`, `caveman-commit`, `caveman-review`, `caveman-compress`, `caveman-stats`, `cavecrew`, `caveman-help`). Use the ACTUAL names returned.

- [ ] **Step 2: Extend DEPRECATED_SKILLS with the confirmed names**

Replace the `DEPRECATED_SKILLS=(…)` array with (substitute the exact names from Step 1):

```bash
DEPRECATED_SKILLS=(
  "local-llm-development"
  "quality-gate"
  # caveman family (dropped in v2) — names confirmed via
  # `npx skills add JuliusBrussee/caveman --list`
  "caveman"
  "caveman-commit"
  "caveman-review"
  "caveman-compress"
  "caveman-stats"
  "cavecrew"
  "caveman-help"
)
```

- [ ] **Step 3: Syntax-check**

Run: `bash -n install.sh`
Expected: no output (exit 0)

- [ ] **Step 4: Assert quality-gate + caveman are in the deprecated list**

Run: `awk '/DEPRECATED_SKILLS=\(/,/^\)/' install.sh | grep -c 'quality-gate\|caveman\|cavecrew'`
Expected: `8` (quality-gate + 7 caveman-family entries)

- [ ] **Step 5: Verify --cleanup help still parses**

Run: `bash install.sh --help`
Expected: usage text printed, exit 0

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): retire quality-gate and caveman family via --cleanup

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `README.md` (Plugins ~L35-38; MCP ~L40-42; Skills list ~L44-56; Configuration; "Currently retired" ~L30-31; Structure tree ~L126-158)

**Interfaces:**
- Consumes: nothing (docs).
- Produces: README matching the v2 install behaviour.

- [ ] **Step 1: Update the Plugins section**

Add a `frontend-design` bullet:

```markdown
- **Frontend Design** — Claude Code's `frontend-design` plugin skill (from the built-in `claude-plugins-official` marketplace), for building and refining UI.
```

- [ ] **Step 2: Add an MCP/deps note for @openai/codex**

Under a new heading or the MCP section, add:

```markdown
### CLI dependencies

- [`@openai/codex`](https://github.com/openai/codex) — the OpenAI Codex CLI, installed globally via npm. Required by the `codex-review` skill and the tsmura grill/codex skills.
```

- [ ] **Step 3: Rewrite the Skills section**

- Remove the `caveman`, `quality-gate`, `grill-me-codex`, and `grill-with-docs-codex` bullets.
- Add a `roast` bullet describing the vendored `roast` skill.
- Add a bullet for the tsmura grill/codex family (grill-me-codex, grill-with-docs-codex, codex-plan-review) installed via `npx skills add tsmura/grill-me-codex`, noting `codex-build` is skipped (broken upstream).
- Update the ponytail bullet to keep it (unchanged), and note caveman is gone.
- Add a note that `npx skills find` is the built-in skill discovery tool.
- Change the Matt Pocock description to "all skills" instead of the curated categories.
- Remove kanban references: drop "kanban ticket management" from the cloudagent bullet and remove the `references/kanban.md` line from the Structure tree (the cloudagent skill dropped kanban in commit dc3f2c6).

- [ ] **Step 4: Update "Currently retired"**

Change the retired line to list: the **superpowers** plugin, the **local-llm-development** skill, **quality-gate**, and the **caveman** family.

- [ ] **Step 5: Update the Structure tree**

Remove `grill-me-codex/`, `grill-with-docs-codex/`, `quality-gate/` from the `skills/` tree; add `roast/SKILL.md`. Add `docs/specs/` and `docs/plans/` if listing docs.

- [ ] **Step 6: Verify no stale references remain**

Run: `grep -ci 'caveman\|quality-gate' README.md`
Expected: `1` (only the single "Currently retired" mention of caveman; quality-gate should be 0 there — adjust the grep/expectation to match your final wording)

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(readme): reflect v2 skill/plugin set

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Record v2 ADRs

**Files:**
- Create: `docs/decisions/0003-add-frontend-design-plugin.md`
- Create: `docs/decisions/0004-externalize-grill-codex-skills-to-tsmura.md`
- Create: `docs/decisions/0005-drop-caveman-and-quality-gate.md`
- Create: `docs/decisions/0006-install-all-mattpocock-skills.md`

**Interfaces:**
- Consumes: the ADR format used by `docs/decisions/0001-*.md` and `0002-*.md` (read one first to match structure).
- Produces: four sequential ADRs documenting the v2 decisions.

- [ ] **Step 1: Read an existing ADR to match the format**

Run: `cat docs/decisions/0002-drop-superpowers-and-retire-via-cleanup-flag.md`
Expected: the ADR template (Status / Context / Decision / Consequences or similar).

- [ ] **Step 2: Write the four ADRs**

Each ADR follows the same headings as 0002, with Status `Accepted`, dated 2026-08-08, Context and Decision drawn from the spec's rationale:
- 0003: use the `frontend-design` plugin from claude-plugins-official (rejected: re-adding superpowers, vendoring).
- 0004: externalize grill/codex skills to `tsmura/grill-me-codex` via npx (rejected: continued vendoring), noting `codex-plan-review` coexists with custom `codex-review`.
- 0005: drop caveman and quality-gate; retire via `--cleanup`.
- 0006: install all mattpocock/skills (rejected: maintaining a curated subset).

- [ ] **Step 3: Verify sequential numbering, no gaps/dupes**

Run: `ls docs/decisions/`
Expected: `0001-… 0002-… 0003-… 0004-… 0005-… 0006-…` with no duplicate numbers.

- [ ] **Step 4: Commit**

```bash
git add docs/decisions/
git commit -m "$(cat <<'EOF'
docs(adr): record v2 install strip-back decisions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Full syntax check**

Run: `bash -n install.sh && echo OK`
Expected: `OK`

- [ ] **Step 2: Run the hook test suite (untouched, must still pass)**

Run: `bash hooks/tests/hooks.test.sh` (night-handoff.test.sh is removed in the amendment)
Expected: all tests pass.

- [ ] **Step 3: Sanity-grep the final install.sh**

Run: `grep -c 'frontend-design\|@openai/codex\|tsmura/grill-me-codex' install.sh; grep -c 'caveman\|MATT_ENGINEERING' install.sh`
Expected: first ≥3; second `7` (caveman family in DEPRECATED_SKILLS only, MATT_ENGINEERING gone).

- [ ] **Step 4: Confirm clean working tree**

Run: `git status --short`
Expected: empty (all changes committed).

## Self-Review

**Spec coverage:** frontend-design (T2) ✓; @openai/codex (T2) ✓; MP all (T3) ✓; ponytail kept + caveman dropped + tsmura added (T3) ✓; delete vendored grills + quality-gate (T1) ✓; cleanup wiring (T4) ✓; README incl. roast + skills find (T5) ✓; ADRs (T6) ✓; unchanged areas untouched ✓; testing (T7) ✓.

**Placeholder scan:** caveman family names are resolved live in T4/Step 1 before use — not a placeholder. README grep expectation in T5/Step 6 is deliberately "adjust to final wording". No TBD/TODO.

**Type consistency:** helper names (`install_plugin`, `remove_skill`, `THIRDPARTY_SKILLS`, `DEPRECATED_SKILLS`, `INSTALLED_SKILLS`) match `install.sh` as read. Marketplace name `claude-plugins-official` consistent throughout.

---

## Amendment tasks (impeccable → skill; remove night-handoff)

### Task 8: Move impeccable from plugin to npx skill

**Files:** Modify `install.sh` (marketplaces, plugins, THIRDPARTY_SKILLS, DEPRECATED_PLUGINS, DEPRECATED_MARKETPLACES, summary).

**Interfaces:** Consumes existing helpers; `THIRDPARTY_SKILLS` loop installs each repo via `npx -y skills add "$repo" -g -y --copy`.

- [ ] **Step 1:** Remove `add_marketplace "pbakaus/impeccable" "impeccable"` from the Marketplaces section.
- [ ] **Step 2:** Remove `install_plugin "impeccable" "impeccable"` from the Plugins section (leave context-mode + frontend-design).
- [ ] **Step 3:** Add `[pbakaus/impeccable]="impeccable skill"` to the `THIRDPARTY_SKILLS` array.
- [ ] **Step 4:** In `DEPRECATED_PLUGINS`, add `"impeccable@impeccable"`. In `DEPRECATED_MARKETPLACES`, add `"impeccable"` (replace the empty `()` and its comment).
- [ ] **Step 5:** Update the summary block: plugins line → `impeccable`→ removed, so `  Plugins:     context-mode, frontend-design`; 3p line mentions impeccable.
- [ ] **Step 6:** `bash -n install.sh` (expect clean). Assert: `grep -c 'install_plugin "impeccable"' install.sh` → `0`; `grep -c 'pbakaus/impeccable' install.sh` → `1`.
- [ ] **Step 7:** Commit (install.sh only), Co-Authored-By trailer.

### Task 9: Remove the night-handoff hook

**Files:** Modify `install.sh`; delete `hooks/night-handoff.sh`; modify `hooks/settings-hooks.jq`; split `hooks/tests/night-handoff.test.sh` → new `hooks/tests/hooks.test.sh`; modify `README.md`.

- [ ] **Step 1:** `install.sh` Hooks section — remove the `cp .../night-handoff.sh` + `chmod` + its `ok` line, and the `STOP_CMD`/`TOUCH_CMD` definitions. Change the `jq_write` hook-wiring call to pass ONLY `--arg session_start_cmd "$SESSION_START_CMD"`. Update the surrounding comment and the `ok "Wired ..."` message to say cloudagent-skill only.
- [ ] **Step 2:** `install.sh` summary block — Hooks line → `  Hooks:       cloudagent-skill (session-start)`.
- [ ] **Step 3:** `git rm hooks/night-handoff.sh`.
- [ ] **Step 4:** `hooks/settings-hooks.jq` — delete the `add_hook("Stop"; $stop_cmd)` and `add_hook("UserPromptSubmit"; $touch_cmd)` lines; keep `add_hook("SessionStart"; $session_start_cmd)`. Update the header comment and Args doc to reflect only session_start_cmd.
- [ ] **Step 5:** Create `hooks/tests/hooks.test.sh` containing the cloudagent-skill tests plus the (now single-SessionStart) settings-hooks.jq tests, preserving the test harness scaffolding they need. `git rm hooks/tests/night-handoff.test.sh`.
- [ ] **Step 6:** `README.md` — delete the entire "## Night handoff hook" section; in the "## Cloudagent skill hook" section change the test-command reference from `bash hooks/tests/night-handoff.test.sh` to `bash hooks/tests/hooks.test.sh`; update any hooks summary references.
- [ ] **Step 7:** Verify: `bash -n install.sh`; `bash hooks/tests/hooks.test.sh` (all pass); `grep -rc 'night.handoff\|NIGHT_HANDOFF' install.sh hooks/settings-hooks.jq README.md` → all 0.
- [ ] **Step 8:** Commit (staging exactly the changed/removed/added files), Co-Authored-By trailer.

### Task 11: Install the "I Have ADHD" output style (native)

Native output style — NOT a hook. (An earlier draft used a SessionStart
injection hook; the user corrected it: it is already an output style, install it
as one.)

**Files:** vendor `config/output-styles/i-have-adhd.md` (done); modify `install.sh`; modify `config/settings.json`; modify `README.md`.

- [ ] **Step 1:** `config/settings.json` — add `"outputStyle": "I Have ADHD"` (value = the frontmatter `name`). The Settings merge activates it.
- [ ] **Step 2:** `install.sh` — add an "Output style" section: `mkdir -p ~/.claude/output-styles`; copy `config/output-styles/i-have-adhd.md` there. No hook.
- [ ] **Step 3:** `install.sh` summary block — add `Output style: I Have ADHD (~/.claude/output-styles, active via settings)`.
- [ ] **Step 4:** `README.md` — document the output style as a native style (file + `outputStyle` setting).
- [ ] **Step 5:** Verify: `bash -n install.sh`; `jq -e '.outputStyle=="I Have ADHD"' config/settings.json` → true.
- [ ] **Step 6:** Commit, Co-Authored-By trailer.

### Task 10: ADRs 0007–0009

- [ ] **Step 1:** Create `docs/decisions/0007-move-impeccable-plugin-to-skill.md` (context-mode stays a plugin — MCP + hook), `docs/decisions/0008-remove-night-handoff-hook.md`, and `docs/decisions/0009-adhd-output-style-via-sessionstart-hook.md` (classic output styles deprecated), matching the 0002 format.
- [ ] **Step 2:** Verify sequential numbering 0001–0009.
- [ ] **Step 3:** Commit, Co-Authored-By trailer.
