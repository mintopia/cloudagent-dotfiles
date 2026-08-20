# Decision: Adopt selected pstack skills — install unchanged where possible, vendor with light generic rework where not

Status: accepted
Date: 2026-08-20

## Context

[pstack](https://github.com/cursor/plugins/tree/main/pstack) (poteto's Cursor plugin) is a 44-skill engineering rigour toolkit. A usage analysis (314 local sessions + Prometheus online metrics) rated each skill against how we actually work. A handful fill real gaps; most duplicate skills we already run (wayfinder/implement pipeline, code-review, grill family, ponytail, deep-analysis, the Workflow tool) or only pay off under pstack's `poteto-mode` meta-mode, which competes with our ponytail sticky mode and wayfinder pipeline.

Constraint: third-party skills must not be modified in place. Skills that need Cursor→Claude rework therefore have to be re-homed as first-party skills in this repo; skills that need no rework can be installed unchanged from upstream.

pstack is built for Cursor: a `sol`/`grok`/`fable`/`opus` model panel, `.cursor-plugin` packaging, Graphite stacks, and Cursor `/loop`. None of that exists in Claude Code.

## Decision

Adopt a curated subset in two lanes, and skip poteto-mode as a driver.

**Lane 1 — install unchanged from upstream** (need no rework), via `npx skills add cursor/plugins --skill …`:
`unslop`, `blast-radius`, `typescript-best-practices`, `show-me-your-work`.

**Lane 2 — vendor into `skills/` as first-party, with light *generic* rework only** (faithful copies; the only edits are Cursor→Claude mechanics):
`why`, `interrogate`, `create-verification-skill`, `maintain-verification-skill`, `reflect`.
- Model routing → Claude subagents (Agent/Task) + the codex CLI for a genuine second model; no hardcoded model IDs.
- App/UI driving → the playwright MCP/CLI.
- Remove Cursor-runtime specifics; keep `disable-model-invocation` flags.
- Keep them generic — **not** wired to our cloud-agent ticket MCP.
- `interrogate` stays a separate skill from `code-review` (multi-model adversarial diff review), not folded in.

**Lane 3 — harvest, do not install:** the five cherry-picked pstack principles (`type-system-discipline`, `model-the-domain`, `make-operations-idempotent`, `prove-it-works`, `guard-the-context-window`) are encoded as always-apply notes in `config/agents-append.md`. The 23 `principle-*` skills are `disable-model-invocation` and inert without poteto-mode, so they are not installed.

**Skip:** `poteto-mode` (competing OS — mine its playbooks as reference only), `swarm`/`arena` (= our Workflow tool), `recall` (= our `pickup`), `tdd`/`no-comments`/`teach`/`bro`/`figure-it-out`/`setup-pstack`, and the remaining principles ponytail already covers.

A new first-party `ask-jess` router skill indexes the whole stack — including these additions — and recommends the next skill/flow.

## Consequences

- Four skills track upstream (auto-updated on `npx skills add`); five are vendored copies we own and must maintain — they will drift from upstream, which is the accepted cost of not modifying third-party skills in place.
- Lane 2 skills are deliberately generic (no ticket-MCP wiring), so they work in any repo but need per-use judgement to hook into our tracker.
- Retiring any of these later is a one-line addition to the `DEPRECATED_SKILLS`/`DEPRECATED_MARKETPLACES` arrays (Lane 1) or removing the `skills/<name>/` dir (Lane 2).
- We accept two verification skills and a multi-model `interrogate` alongside `code-review`; overlap is intentional (different lenses).

## Supersedes
None
