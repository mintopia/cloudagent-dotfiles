# Mintopia's Cloud Agent Dotfiles

Dotfiles for [Cloud Agent](https://cloudagent.mintopia.net) environments. Automates the setup of plugins, skills, MCP servers, statusline, settings, and agent instructions for a new workspace.

## Install

```bash
git clone https://github.com/mintopia/cloudagent-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script is idempotent — safe to run multiple times. Restart Claude Code after running for all changes to take effect.

## What It Does

### Plugins

- [Superpowers](https://github.com/obra/superpowers) — visual companion, brainstorming tools
- [Impeccable](https://impeccable.style) — code style enforcement
- [Context Mode](https://github.com/mksglu/context-mode) — context window protection and FTS5 knowledge base

### MCP Servers

- [jCodeMunch](https://j.gravelle.us/jCodeMunch) — codebase indexing and analysis (via pipx/pip)

### Skills

- **adr** — Architecture Decision Record enforcement and creation. Hard-blocks on conflicting ADRs, sequential numbering, `/adr` command for interactive creation.
- **caveman** (+ family) — Ultra-compressed communication mode (`/caveman`). Cuts output tokens ~75% by dropping articles, filler, and pleasantries while keeping full technical accuracy, with `lite`/`full`/`ultra` (and wenyan) intensity levels. The full family is installed: `caveman-commit` (terse commit messages), `caveman-review` (terse PR feedback), `caveman-compress` (compress CLAUDE.md/memory files, script-backed), `caveman-stats` (session token usage + savings), `cavecrew` (delegating to caveman subagents), and `caveman-help` (reference card). Installed via `npx skills add` from [Julius Brussee's caveman](https://github.com/JuliusBrussee/caveman) (MIT).
- **cloudagent** — Complete `cloudagent` CLI reference and workspace conventions. Covers file/URL presentation (`open-file`, `open-url`), HTTP forwards for web servers, notifications, visual companion setup (including the critical WSS patch), and kanban ticket management (full reference in `references/kanban.md` for progressive disclosure).
- **codex-review** — Standalone adversarial plan-review loop. Claude drafts a plan into `PLAN.md`, OpenAI Codex critiques it read-only across rounds (`VERDICT:APPROVED`/`REVISE`) until it converges or hits a round cap. `/codex-review` for when you already have a plan and just want the cross-model stress-test.
- **deep-analysis** — Explicitly-invoked depth harness (`/deep-analysis`) that runs a diverge → refute → converge loop with fresh-context adversarial sub-agents, killing weak directions on majority-refute with Claude as final arbiter. For high-stakes design, architecture, and tradeoff calls where getting it right beats getting it fast.
- **grill-me-codex** — Two-act plan hardening (`/grill-me-codex`). Act 1 interviews you one question at a time until intent is locked; Act 2 hands the plan to Codex for adversarial cross-model review. Builds on Matt Pocock's `grill-me` (MIT).
- **grill-with-docs-codex** — `grill-me-codex` plus living documentation (`/grill-with-docs-codex`). Act 1 challenges your plan against `CONTEXT.md`/ADRs and updates them inline as decisions crystallise; Act 2 is the Codex review loop. Builds on Matt Pocock's `grill-with-docs` (MIT).
- **local-llm-development** — Delegates implementation to a local LLM (LM Studio) while Claude orchestrates and reviews — a third execution option alongside sequential/parallel Claude subagents. Bundles an `llm-proxy.sh`, tool schemas, and an implementer prompt.
- **pickup** — Lightweight session recap (`/pickup`, or "where were we?") that reconstructs context from durable artifacts (session JSONL, git state, memory) instead of replaying the full conversation like `/resume`. Includes `scripts/extract_session.py`.
- **ponytail** (+ family) — Laziest-solution-that-works mode (`/ponytail`). Channels a senior dev enforcing YAGNI, stdlib-before-custom, native-before-dependency, and shortest-working-diff, with `lite`/`full`/`ultra` intensity levels. The full family is installed: `ponytail-review` (review for over-engineering), `ponytail-audit` (whole-repo over-engineering scan), `ponytail-debt` (harvest `ponytail:` comments into a debt ledger), `ponytail-gain` (impact scoreboard), and `ponytail-help` (reference card). Pairs with **caveman** for terse prose. Installed via `npx skills add` from [DietrichGebert's ponytail](https://github.com/DietrichGebert/ponytail) (MIT).
- **quality-gate** — Enforces that all test, lint, and quality check failures are fixed before work is considered complete. Prevents Claude from dismissing failures as "unrelated" or "pre-existing". If the suite is red, it gets fixed.
- **subagent-finder** — Searches the [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) catalog (150+ agents) to find specialist subagents without loading them all into context. Includes `/subagents` command to scan a project's tech stack, recommend matching agents, and install them to `.claude/agents/`.

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
conventions (presenting files/URLs, exposing web servers, notifications, kanban
tickets) are in context before Claude does anything.

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
│   ├── cloudagent/
│   │   ├── SKILL.md                        # CLI reference and workspace conventions
│   │   └── references/kanban.md            # Full kanban ticket system reference
│   ├── codex-review/SKILL.md               # Standalone Claude↔Codex plan-review loop
│   ├── deep-analysis/SKILL.md              # Diverge→refute→converge depth harness
│   ├── grill-me-codex/SKILL.md             # Interview you, then Codex-review the plan
│   ├── grill-with-docs-codex/SKILL.md      # grill-me-codex + living CONTEXT.md/ADRs
│   ├── local-llm-development/
│   │   ├── SKILL.md                        # Delegate implementation to a local LLM
│   │   └── scripts/                        # LM Studio proxy + tool schemas
│   ├── pickup/
│   │   ├── SKILL.md                        # /pickup session recap from artifacts
│   │   └── scripts/extract_session.py      # Session JSONL extractor
│   ├── quality-gate/SKILL.md               # Enforce fixing all test/lint failures
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
