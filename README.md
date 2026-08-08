# Mintopia's Cloud Agent Dotfiles

Dotfiles for [Cloud Agent](https://cloudagent.mintopia.net) environments. Automates the setup of plugins, skills, MCP servers, statusline, settings, and agent instructions for a new workspace.

## Install

```bash
git clone https://github.com/mintopia/cloudagent-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script is idempotent — safe to run multiple times. Restart Claude Code after running for all changes to take effect.

### Removing retired components

A plain run only adds and updates — it never removes anything. To also purge
components these dotfiles used to install but have since dropped:

```bash
./install.sh --cleanup
```

This uninstalls the plugins, marketplaces, and skills listed in the
`DEPRECATED_PLUGINS`, `DEPRECATED_MARKETPLACES`, and `DEPRECATED_SKILLS` arrays
near the top of `install.sh`, then continues with the normal install. It is safe
to re-run: anything already gone is reported and skipped. Retiring something in
future is a one-line addition to the relevant array.

Currently retired: the **superpowers** plugin, the **local-llm-development**
skill, the **quality-gate** skill, and the **caveman** family.

## What It Does

### Plugins

- [Impeccable](https://impeccable.style) — code style enforcement
- [Context Mode](https://github.com/mksglu/context-mode) — context window protection and FTS5 knowledge base
- **Frontend Design** — Claude Code's `frontend-design` plugin skill (from the built-in `claude-plugins-official` marketplace), for building and refining UI.

### MCP Servers

- [jCodeMunch](https://j.gravelle.us/jCodeMunch) — codebase indexing and analysis (via pipx/pip)

### CLI dependencies

- [`@openai/codex`](https://github.com/openai/codex) — the OpenAI Codex CLI, installed globally via npm (`npm i -g @openai/codex`, idempotent — skipped if `codex` is already on `PATH`). Required by the `codex-review` skill and the tsmura grill/codex skills.

### Skills

- **adr** — Architecture Decision Record enforcement and creation. Hard-blocks on conflicting ADRs, sequential numbering, `/adr` command for interactive creation.
- **cloudagent** — Complete `cloudagent` CLI reference and workspace conventions. Covers file/URL presentation (`open-file`, `open-url`), HTTP forwards for web servers (including the `wss://` and `0.0.0.0` binding requirements), and notifications.
- **codex-review** — Standalone adversarial plan-review loop. Claude drafts a plan into `PLAN.md`, OpenAI Codex critiques it read-only across rounds (`VERDICT:APPROVED`/`REVISE`) until it converges or hits a round cap. `/codex-review` for when you already have a plan and just want the cross-model stress-test.
- **deep-analysis** — Explicitly-invoked depth harness (`/deep-analysis`) that runs a diverge → refute → converge loop with fresh-context adversarial sub-agents, killing weak directions on majority-refute with Claude as final arbiter. For high-stakes design, architecture, and tradeoff calls where getting it right beats getting it fast.
- **grill-me-codex** (+ family) — Two-act plan hardening (`/grill-me-codex`). Act 1 interviews you one question at a time until intent is locked (the `grill-with-docs-codex` variant additionally challenges your plan against `CONTEXT.md`/ADRs and updates them inline); Act 2 hands the plan to Codex for adversarial cross-model review, converging via `VERDICT:APPROVED`/`REVISE`. Installs `grill-me-codex`, `grill-with-docs-codex`, and `codex-plan-review` (which intentionally coexists with the custom `codex-review` skill above) via `npx skills add tsmura/grill-me-codex` from [tsmura's grill-me-codex](https://github.com/tsmura/grill-me-codex) (MIT); `codex-build` is skipped automatically (broken upstream `SKILL.md` YAML).
- **mattpocock/skills** — All of [Matt Pocock's skills](https://github.com/mattpocock/skills) (MIT), installed via `npx skills add mattpocock/skills --skill '*' -g -y --copy`.
- **pickup** — Lightweight session recap (`/pickup`, or "where were we?") that reconstructs context from durable artifacts (session JSONL, git state, memory) instead of replaying the full conversation like `/resume`. Includes `scripts/extract_session.py`.
- **ponytail** (+ family) — Laziest-solution-that-works mode (`/ponytail`). Channels a senior dev enforcing YAGNI, stdlib-before-custom, native-before-dependency, and shortest-working-diff, with `lite`/`full`/`ultra` intensity levels. The full family is installed: `ponytail-review` (review for over-engineering), `ponytail-audit` (whole-repo over-engineering scan), `ponytail-debt` (harvest `ponytail:` comments into a debt ledger), `ponytail-gain` (impact scoreboard), and `ponytail-help` (reference card). Installed via `npx skills add` from [DietrichGebert's ponytail](https://github.com/DietrichGebert/ponytail) (MIT).
- **roast** — Pressure-tests an idea before you build it (`/roast`). Convenes a 5-persona adversarial council (Contrarian, Expansionist, Logician, Researcher, Buyer) in parallel to attack and defend the idea from every angle, then a Judge synthesizes one `GO`/`RESHAPE`/`KILL` verdict with the cheapest test to de-risk it.
- **subagent-finder** — Searches the [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) catalog (150+ agents) to find specialist subagents without loading them all into context. Includes `/subagents` command to scan a project's tech stack, recommend matching agents, and install them to `.claude/agents/`.

Beyond what this repo installs, the `skills` CLI ships its own discovery tool: run `npx skills find [query]` to search for third-party skills without installing anything.

### Configuration

- **Statusline** — Custom statusline showing cwd, git branch, model, context bar chart, token counts (cumulative + per-call with read/write/cached), session cost estimate, and clock.
- **Settings** — Opus model, dark theme, dangerous mode skip, in-process teammate mode, 5% skill listing budget.
- **Git** — Global user name and email (Jessica Smith \<jess@mintopia.net\>).
- **Keybindings** — Shift+Enter for newline in chat.
- **Decision memory** — ADR-based decision tracking appended to user `AGENTS.md`, teaching agents to search for and respect existing architecture decisions.

## Night handoff hook

`hooks/night-handoff.sh` watches for long-running turns that finish while you are
asleep and forces Claude to leave a cheap resumption trail, so you don't pay for a
cold full-context `/resume` in the morning.

How it works:

- A `UserPromptSubmit` hook stamps a per-session marker on every user turn.
- A `Stop` hook measures how long the just-finished turn ran (`now − marker`). If
  that turn ran longer than the idle threshold **and** it ended inside your
  overnight window **and** no handoff was written recently, it returns a
  `decision:block` instructing Claude to write a handoff document and print a
  paste-ready resume prompt (prefer `/pickup`).

The handoff instructions are inlined in the hook rather than delegating to Matt
Pocock's `handoff` skill: that skill sets `disable-model-invocation: true`, so a
`Stop` hook cannot make the model invoke it. Keeping the steps self-contained
makes the hook independent of any skill's invocation policy.

Because the measured "idle" is really the turn's duration, a long unattended run
that finishes at 03:00 triggers a handoff, while you actively chatting at 02:00
(short turns) does not. A per-session cooldown prevents repeats.

Configuration (environment variables):

| Var | Default | Meaning |
|-----|---------|---------|
| `NIGHT_HANDOFF_TZ` | `Europe/London` | Timezone the window is measured in (DST-aware). |
| `NIGHT_HANDOFF_START` | `1` | Window start hour, inclusive. |
| `NIGHT_HANDOFF_END` | `9` | Window end hour, exclusive. |
| `NIGHT_HANDOFF_IDLE_MIN` | `15` | Minimum turn duration (minutes) to count as "away". |
| `NIGHT_HANDOFF_COOLDOWN_H` | `6` | No repeat handoff within this many hours per session. |
| `NIGHT_HANDOFF_DISABLE` | _(unset)_ | Set to any value to disable the hook. |

Run the tests with `bash hooks/tests/night-handoff.test.sh`.

## Cloudagent skill hook

`hooks/cloudagent-skill.sh` is a `SessionStart` hook that makes Claude always load
the `cloudagent` skill at the start of every session, so Cloud Agent workspace
conventions (presenting files/URLs, exposing web servers, notifications) are in
context before Claude does anything.

How it works:

- On `SessionStart`, the hook emits `additionalContext` instructing Claude to
  invoke the `cloudagent` skill via the Skill tool.
- It only fires inside a Cloud Agent workspace — detected the same way the skill
  is (the `cloudagent` CLI on `PATH` or the `CLOUDAGENT_API_URL` env var) — so it
  stays silent on other machines.

Configuration (environment variables):

| Var | Default | Meaning |
|-----|---------|---------|
| `CLOUDAGENT_SKILL_HOOK_DISABLE` | _(unset)_ | Set to any value to disable the hook. |

Tests live alongside the night-handoff tests: `bash hooks/tests/night-handoff.test.sh`.

## Structure

```
├── install.sh                              # Main setup script
├── statusline-command.sh                   # Custom Claude Code statusline
├── config/
│   ├── settings.json                       # Claude Code settings
│   ├── keybindings.json                    # Keybinding overrides
│   └── agents-append.md                    # Decision memory (appended to ~/.claude/AGENTS.md)
├── skills/
│   ├── adr/SKILL.md                        # ADR enforcement and /adr command
│   ├── cloudagent/SKILL.md                 # CLI reference and workspace conventions
│   ├── codex-review/SKILL.md               # Standalone Claude↔Codex plan-review loop
│   ├── deep-analysis/SKILL.md              # Diverge→refute→converge depth harness
│   ├── pickup/
│   │   ├── SKILL.md                        # /pickup session recap from artifacts
│   │   └── scripts/extract_session.py      # Session JSONL extractor
│   ├── roast/SKILL.md                      # 5-persona adversarial idea council
│   └── subagent-finder/
│       ├── SKILL.md                        # Agent search and /subagents command
│       └── scripts/
│           ├── search.sh                   # Keyword search against agent catalog
│           └── assess.sh                   # Project tech stack scanner
├── decision-memory/
│   ├── decision-memory.md                  # How the decision memory system works
│   └── example-adr.md                      # ADR template
└── docs/decisions/
    └── 0001-serve-js-html-via-http-forward.md  # Use web server for interactive HTML
```
