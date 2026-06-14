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
- **cloudagent** — Complete `cloudagent` CLI reference and workspace conventions. Covers file/URL presentation (`open-file`, `open-url`), HTTP forwards for web servers, notifications, visual companion setup (including the critical WSS patch), and kanban ticket management (full reference in `references/kanban.md` for progressive disclosure).
- **codex-review** — Standalone adversarial plan-review loop. Claude drafts a plan into `PLAN.md`, OpenAI Codex critiques it read-only across rounds (`VERDICT:APPROVED`/`REVISE`) until it converges or hits a round cap. `/codex-review` for when you already have a plan and just want the cross-model stress-test.
- **deep-analysis** — Explicitly-invoked depth harness (`/deep-analysis`) that runs a diverge → refute → converge loop with fresh-context adversarial sub-agents, killing weak directions on majority-refute with Claude as final arbiter. For high-stakes design, architecture, and tradeoff calls where getting it right beats getting it fast.
- **grill-me-codex** — Two-act plan hardening (`/grill-me-codex`). Act 1 interviews you one question at a time until intent is locked; Act 2 hands the plan to Codex for adversarial cross-model review. Builds on Matt Pocock's `grill-me` (MIT).
- **grill-with-docs-codex** — `grill-me-codex` plus living documentation (`/grill-with-docs-codex`). Act 1 challenges your plan against `CONTEXT.md`/ADRs and updates them inline as decisions crystallise; Act 2 is the Codex review loop. Builds on Matt Pocock's `grill-with-docs` (MIT).
- **local-llm-development** — Delegates implementation to a local LLM (LM Studio) while Claude orchestrates and reviews — a third execution option alongside sequential/parallel Claude subagents. Bundles an `llm-proxy.sh`, tool schemas, and an implementer prompt.
- **pickup** — Lightweight session recap (`/pickup`, or "where were we?") that reconstructs context from durable artifacts (session JSONL, git state, memory) instead of replaying the full conversation like `/resume`. Includes `scripts/extract_session.py`.
- **quality-gate** — Enforces that all test, lint, and quality check failures are fixed before work is considered complete. Prevents Claude from dismissing failures as "unrelated" or "pre-existing". If the suite is red, it gets fixed.
- **subagent-finder** — Searches the [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) catalog (150+ agents) to find specialist subagents without loading them all into context. Includes `/subagents` command to scan a project's tech stack, recommend matching agents, and install them to `.claude/agents/`.

### Configuration

- **Statusline** — Custom statusline showing cwd, git branch, model, context bar chart, token counts (cumulative + per-call with read/write/cached), session cost estimate, and clock.
- **Settings** — Opus model, dark theme, dangerous mode skip, in-process teammate mode, 5% skill listing budget.
- **Git** — Global user name and email (Jessica Smith \<jess@mintopia.net\>).
- **Keybindings** — Shift+Enter for newline in chat.
- **Decision memory** — ADR-based decision tracking appended to user `AGENTS.md`, teaching agents to search for and respect existing architecture decisions.

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
