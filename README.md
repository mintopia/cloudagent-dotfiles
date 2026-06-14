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
