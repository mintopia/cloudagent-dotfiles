# Mintopia's Cloud Agent Dotfiles

Dotfiles for [Cloud Agent](https://cloudagent.mintopia.net) environments. Automates the setup of plugins, skills, MCP servers, statusline, settings, and agent instructions for a new workspace.

## Install

```bash
git clone https://github.com/mintopia/cloudagent-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script is idempotent — safe to run multiple times. Restart Claude Code after running for all changes to take effect.

The **cloudagent skill**, the **cloudagent-skill + harmonic-start hooks**, and
**Harmonic** are installed only when a Cloud Agent workspace is detected (the
`cloudagent` CLI on `PATH` or the `CLOUDAGENT_API_URL` env var). On other
machines they are skipped; everything else installs normally.

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
skill, the **quality-gate** skill, the **caveman** family, and the **impeccable**
plugin + marketplace (impeccable is now installed as a skill instead).

## What It Does

### Plugins

- [Context Mode](https://github.com/mksglu/context-mode) — context window protection and FTS5 knowledge base. Stays a plugin: its skills wrap the `ctx_*` MCP server and a PreToolUse routing hook that only the plugin provides.
- **Frontend Design** — Claude Code's `frontend-design` plugin skill (from the built-in `claude-plugins-official` marketplace), for building and refining UI.

(Impeccable used to be a plugin here; it is now installed as a skill — see below.)

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
- **impeccable** — Frontend design/critique skill (`/impeccable`) covering UX review, visual hierarchy, accessibility, theming, and reusable design systems. Moved from a plugin to a skill in v2 (it is a single self-contained skill with no MCP/hooks), installed via `npx skills add pbakaus/impeccable` from [pbakaus/impeccable](https://github.com/pbakaus/impeccable).
- **mattpocock/skills** — All of [Matt Pocock's skills](https://github.com/mattpocock/skills) (MIT), installed via `npx skills add mattpocock/skills --skill '*' -g -y --copy`.
- **pickup** — Lightweight session recap (`/pickup`, or "where were we?") that reconstructs context from durable artifacts (session JSONL, git state, memory) instead of replaying the full conversation like `/resume`. Includes `scripts/extract_session.py`.
- **ponytail** (+ family) — Laziest-solution-that-works mode (`/ponytail`). Channels a senior dev enforcing YAGNI, stdlib-before-custom, native-before-dependency, and shortest-working-diff, with `lite`/`full`/`ultra` intensity levels. The full family is installed: `ponytail-review` (review for over-engineering), `ponytail-audit` (whole-repo over-engineering scan), `ponytail-debt` (harvest `ponytail:` comments into a debt ledger), `ponytail-gain` (impact scoreboard), and `ponytail-help` (reference card). Installed via `npx skills add` from [DietrichGebert's ponytail](https://github.com/DietrichGebert/ponytail) (MIT).
- **roast** — Pressure-tests an idea before you build it (`/roast`). Convenes a 5-persona adversarial council (Contrarian, Expansionist, Logician, Researcher, Buyer) in parallel to attack and defend the idea from every angle, then a Judge synthesizes one `GO`/`RESHAPE`/`KILL` verdict with the cheapest test to de-risk it.
- **subagent-finder** — Searches the [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) catalog (150+ agents) to find specialist subagents without loading them all into context. Includes `/subagents` command to scan a project's tech stack, recommend matching agents, and install them to `.claude/agents/`.
- **visual-companion** — Browser-based visual companion that serves HTML mockups, wireframes, and diagrams to the user's browser and records their click selections, for design/frontend/architecture questions that are better *seen* than read. Vendored from the superpowers `brainstorming` skill (MIT, obra/superpowers) as a standalone skill so it survives the superpowers drop ([ADR 0002](docs/decisions/0002-drop-superpowers-and-retire-via-cleanup-flag.md)); made Cloud Agent-aware — `start-companion.sh` auto-creates a TLS `http-forward` and the patched `helper.js` upgrades the WebSocket to `wss://` on https pages, while off Cloud Agent it runs plain localhost. See [ADR 0014](docs/decisions/0014-vendor-visual-companion-as-standalone-skill.md).

#### pstack skills (see [ADR 0012](docs/decisions/0012-adopt-selected-pstack-skills.md))

A curated subset of [pstack](https://github.com/cursor/plugins/tree/main/pstack) (poteto's Cursor plugin), in two lanes. Most of pstack is deliberately **not** adopted — it duplicates skills we already run, and `poteto-mode` is skipped as a driver (it competes with ponytail + the wayfinder pipeline).

- **Installed unchanged from upstream** via `npx skills add cursor/plugins --skill …` (need no rework): **unslop** (cut AI tells from prose), **blast-radius** (prove what a change breaks by running code), **typescript-best-practices** (always-on for `.ts/.tsx`), **show-me-your-work** (TSV decision log for unattended runs).
- **Vendored as first-party skills** under `skills/` with light generic Cursor→Claude rework (model panel → Claude subagents + codex; UI driving → playwright; no ticket-MCP wiring):
  - **why** — evidence-backed design rationale; discovers MCPs at runtime and queries each evidence category in parallel.
  - **interrogate** — multi-model adversarial diff review (independent Claude subagents + a codex reviewer). Separate from `code-review`.
  - **create-verification-skill** / **maintain-verification-skill** — generate and maintain a per-repo skill that drives the app like a user (playwright for UI/web).
  - **reflect** — spawn review subagents over the transcript and route each learning into an edit on an existing skill.

The five cherry-picked pstack **principles** (type-system discipline, model the domain, idempotency, prove it works, guard the context window) are encoded as always-apply notes in `config/agents-append.md`, not installed as skills.

#### ask-jess

- **ask-jess** — a router over the whole installed stack (`/ask-jess`). Given a situation, it points to the skill or flow that fits — the Matt Pocock idea→ship flow, the vendored pstack skills, the ponytail/caveman modes, and the first-party skills here. Falls back to `scripts/catalog.sh`, which lists every installed skill from `~/.claude/skills`, when the situation isn't in its curated map.

Beyond what this repo installs, the `skills` CLI ships its own discovery tool: run `npx skills find [query]` to search for third-party skills without installing anything.

### Configuration

- **Statusline** — Custom statusline showing cwd, git branch, model, context bar chart, token counts (cumulative + per-call with read/write/cached), session cost estimate, and clock.
- **Settings** — Opus model, dark theme, dangerous mode skip, in-process teammate mode, 5% skill listing budget.
- **Git** — Global user name and email (Jessica Smith \<jess@mintopia.net\>).
- **Keybindings** — Shift+Enter for newline in chat.
- **Decision memory** — ADR-based decision tracking appended to user `AGENTS.md`, teaching agents to search for and respect existing architecture decisions.
- **Output style ("I Have ADHD")** — action-first output shaping (next step first, numbered steps, no preamble). Installed as a native Claude Code output style: `config/output-styles/i-have-adhd.md` is copied to `~/.claude/output-styles/` and `settings.json` sets `"outputStyle": "I Have ADHD"` to make it active.

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

Run the hook tests with `bash hooks/tests/hooks.test.sh`.

## Harmonic auto-start hook

`hooks/harmonic-start.sh` is a `SessionStart` hook that keeps
[Harmonic](https://github.com/mintopia/harmonic) — an agent UI / task scheduler —
running and reachable in a Cloud Agent workspace.

How it works:

- On `SessionStart` (inside a Cloud Agent workspace only), it runs
  `npx github:mintopia/harmonic start`, which launches Harmonic as a single
  background daemon (logs to `~/.harmonic`). Harmonic's `start` is a **singleton**
  — it refuses if a daemon is already running — so repeated sessions never spawn
  a second instance. The daemon is started detached, so a slow first-run build
  never blocks session start.
- It then ensures a **private HTTPS forward** on the `harmonic` hostname exists
  (`cloudagent http-forwards add --container 4700 --hostname harmonic --private`),
  adding it only when one is not already present.
- It surfaces the resulting private URL to Claude via `additionalContext`.

Harmonic binds `0.0.0.0` (required so the forward's proxy can reach it) and runs
ungated — the `--private` forward is the auth boundary. `install.sh` warms the
npx build once so the first session starts instantly.

Configuration (environment variables):

| Var | Default | Meaning |
|-----|---------|---------|
| `HARMONIC_PORT` | `4700` | Port Harmonic listens on / the forward targets. |
| `HARMONIC_HOSTNAME` | `harmonic` | Subdomain for the private HTTPS forward. |
| `HARMONIC_HOOK_DISABLE` | _(unset)_ | Set to any value to disable the hook. |

## Structure

```
├── install.sh                              # Main setup script
├── statusline-command.sh                   # Custom Claude Code statusline
├── config/
│   ├── settings.json                       # Claude Code settings (incl. active outputStyle)
│   ├── keybindings.json                    # Keybinding overrides
│   ├── agents-append.md                    # Decision memory (appended to ~/.claude/AGENTS.md)
│   └── output-styles/i-have-adhd.md        # "I Have ADHD" output style
├── hooks/
│   ├── cloudagent-skill.sh                 # SessionStart: load the cloudagent skill
│   ├── harmonic-start.sh                   # SessionStart: start Harmonic + private forward
│   ├── settings-hooks.jq                   # Idempotent SessionStart hook wiring
│   └── tests/hooks.test.sh                 # Hook + jq tests
├── skills/
│   ├── adr/SKILL.md                        # ADR enforcement and /adr command
│   ├── cloudagent/SKILL.md                 # CLI reference and workspace conventions
│   ├── codex-review/SKILL.md               # Standalone Claude↔Codex plan-review loop
│   ├── deep-analysis/SKILL.md              # Diverge→refute→converge depth harness
│   ├── pickup/
│   │   ├── SKILL.md                        # /pickup session recap from artifacts
│   │   └── scripts/extract_session.py      # Session JSONL extractor
│   ├── roast/SKILL.md                      # 5-persona adversarial idea council
│   ├── subagent-finder/
│   │   ├── SKILL.md                        # Agent search and /subagents command
│   │   └── scripts/
│   │       ├── search.sh                   # Keyword search against agent catalog
│   │       └── assess.sh                   # Project tech stack scanner
│   └── visual-companion/
│       ├── SKILL.md                        # Browser mockup/diagram companion
│       └── scripts/
│           ├── start-companion.sh          # Cloud Agent-aware launcher (auto http-forward)
│           ├── stop-companion.sh           # Teardown: remove forward + stop server
│           ├── helper.js                   # Client script (patched ws://→wss:// on https)
│           └── …                           # server.cjs + start/stop-server + frame-template (upstream)
├── decision-memory/
│   ├── decision-memory.md                  # How the decision memory system works
│   └── example-adr.md                      # ADR template
└── docs/decisions/
    └── 0001-serve-js-html-via-http-forward.md  # Use web server for interactive HTML
```
