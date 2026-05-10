# Mintopia's Cloud Agent Dotfiles

Dotfiles for Cloud Agent environments. Run `./install.sh` to set up a new workspace.

## What It Does

The install script configures:

- **Plugins:** [Superpowers](https://github.com/obra/superpowers), [Impeccable](https://impeccable.style), [Context Mode](https://github.com/mksglu/context-mode)
- **MCP servers:** [jCodeMunch](https://j.gravelle.us/jCodeMunch) (via uvx)
- **Statusline:** Custom statusline with git, model, context window, token counts, and cost
- **Settings:** Model, theme, keybindings
- **Skills:** ADR enforcement (`/adr`), Cloud Agent environment conventions
- **Decision memory:** ADR-based decision tracking appended to user `AGENTS.md`

## Usage

```bash
./install.sh
```

The script is idempotent — safe to run multiple times.

## Structure

```
├── install.sh              # Main setup script
├── statusline-command.sh   # Custom Claude Code statusline
├── config/
│   ├── settings.json       # Claude Code settings
│   ├── keybindings.json    # Keybinding overrides
│   └── agents-append.md    # Decision memory instructions (appended to ~/.claude/AGENTS.md)
├── skills/
│   ├── adr/SKILL.md        # ADR skill — enforces existing ADRs, /adr creates new ones
│   └── cloudagent-env/SKILL.md  # Cloud Agent conventions — file/URL presentation, http-forwards, visual companion
└── decision-memory/
    ├── decision-memory.md  # How the decision memory system works
    └── example-adr.md      # ADR template
```
