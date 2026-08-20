---
name: ask-jess
description: Ask which skill or flow fits your situation. A router over Jess's whole installed stack — the Matt Pocock idea→ship flow, the vendored pstack skills, the ponytail/caveman modes, and the first-party skills in this repo. Use for /ask-jess, "which skill", "what should I use", "what's next".
disable-model-invocation: true
argument-hint: "A situation to route, or nothing for the map"
---

# Ask Jess

You don't remember every skill, so ask. This routes a situation to the skill or flow that fits.

If the answer isn't in the map below, don't guess — run `scripts/catalog.sh` (or `ls ~/.claude/skills` and read each `SKILL.md` frontmatter) to see what's actually installed right now, and route from that. The map is curated; the catalog is ground truth.

## The main flow: idea → ship

The route most work travels. (For the granular Matt Pocock version of this flow — phase boundaries, context hygiene — see `/ask-matt`; this is the superset.)

1. **`/grill-with-docs`** — sharpen the idea by interview when you're in a working directory (leaves a `CONTEXT.md` + ADR paper trail). No repo? **`/grill-me`**. Want a second model on the plan too? **`/grill-with-docs-codex`** or **`/codex-review`**.
2. **Need a runnable answer** (state, logic, a UI you must see)? Detour through **`/prototype`**, bridged by **`/handoff`**.
3. **Multi-session build?** → **`/to-spec`** → **`/to-tickets`** → **`/implement`** per ticket (`/clear` between each). Single session → **`/implement`** right here. `/implement` drives **`/tdd`** internally and closes with **`/code-review`**.

## On-ramps (a situation that generates work, then merges onto the main flow)

- **Huge, foggy effort — greenfield or a feature too big for one session** → **`/wayfinder`**. Charts a map of decision tickets and resolves them until the way is clear, then hands off at `/to-spec`. The most demanding flow — save it for genuine fog, not a well-scoped feature.
- **Bugs / requests piling up (that you didn't create)** → **`/triage`** → produces agent-ready issues for `/implement`.
- **Something's broken** → **`/diagnosing-bugs`** (hard/intermittent/regression) or **`/diagnose`**. Refuses to theorise without a red feedback loop; fixes with a regression test.
- **Idea worth pressure-testing before building** → **`/roast`** (5-persona adversarial council → GO/RESHAPE/KILL) or **`/deep-analysis`** (diverge→refute→converge for high-stakes design/architecture/tradeoff calls).

## Review & verify

- **`/code-review`** — the default two-axis review (Standards + Spec) of a diff or branch. Your #1 review tool.
- **`/interrogate`** — multi-model *adversarial* review: several independent Claude subagents + a codex reviewer try to break the diff from different angles. Reach for it beyond code-review when a change is risky and you want cross-model blind spots surfaced.
- **`/blast-radius`** — before shipping a small-looking change, find what it could break *beyond the diff*, and prove the one fact it's safe by running real code. For risky infra/networking/hardware diffs.
- **`/create-verification-skill`** — generate a per-repo skill that drives this app the way a user does (playwright for UI/web). Run once per repo that has no scripted way to prove behaviour. **`/maintain-verification-skill`** keeps that skill honest later.
- **`/security-review`** — security pass over pending changes.
- **`/no-comments`** — adversarial comment sweep: a hostile reviewer hunts narration, workaround sermons, and lint/TS suppressions on a diff, then offers to encode real constraints as types/tests/CI. The after-the-fact heavy version of ponytail's write-time comment discipline.

## Understand & explain

- **`/why`** — design rationale, "why was it built this way", regressions, postmortems. Discovers available MCPs at runtime and queries each evidence category in parallel. Use for motivation.
- **`/research`** — delegate reading legwork to a background agent; it leaves a cited Markdown file. Feeds the thinking, doesn't replace it.
- **`/teach`** — explain a subsystem or change plainly for a human to actually understand.
- **`/subagent-finder`** / `/subagents` — find or install a specialist subagent for a task.

## Design & frontend

- **`/impeccable`** (+ its sub-skills: `arrange`, `animate`, `critique`, `polish`, `distill`…) — UX review, visual hierarchy, accessibility, theming, design systems.
- **`frontend-design`** — distinctive, non-templated UI when building or reshaping an interface.

## Prose & communication

- **`/unslop`** — cut AI tells from any writing. Reach for it on any prose you're about to ship. Complements, doesn't fight, the modes below.
- **caveman** — ultra-compressed communication when you want fewer tokens.
- **`/writing-for-agents`** — reference for docs agents consume (skills, AGENTS.md, pointed-at docs).

## Autonomous & unattended

- **`/show-me-your-work`** — keep a reviewable TSV decision log for long-running or overnight runs, so a reviewer can trust the result after you stepped away.
- **`/loop`** — run a prompt/command on a recurring interval. **`/schedule`** — cron a cloud agent.

## Modes & vocabulary underneath (run *beneath* the other skills)

- **ponytail** — the laziest-solution-that-works mode (YAGNI, stdlib-before-custom, shortest working diff). Sticky. Plus `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`.
- The **five engineering principles** in `AGENTS.md` (type-system discipline, model the domain, idempotency, prove it works, guard the context window) — always-apply reflexes.
- **`/domain-modeling`** — sharpen the project's ubiquitous language; record hard-to-reverse calls as ADRs.
- **`/codebase-design`** — deep-module vocabulary (module, interface, depth, seam, adapter) for shaping a module.
- **`/adr`** — record/enforce architecture decisions. Check `docs/decisions/` before proposing architecture, tooling, or workflow changes.
- **`/reflect`** — after a session, spawn review subagents over the transcript and route each learning into a concrete edit on an existing skill. The self-improvement loop for this whole stack.

## Session & context

- **`/pickup`** — lightweight recap ("where were we?") from durable artifacts, cheaper than `/resume`.
- **`/handoff`** — write a portable markdown file for a new harness, directory, or colleague.
- **`/clear`** — empty the window at a phase boundary when nothing here matters next.

## Codebase health

- **`/improve-codebase-architecture`** — periodic survey that surfaces deepening opportunities; picking one generates an idea for the main flow.
- **`/request-refactor-plan`** — plan a refactor as tiny commits, filed as an issue.

## Platform

- **`cloudagent`** — Cloud Agent workspace conventions (presenting files/URLs, HTTP forwards, notifications). Auto-loaded in a workspace.

## When unsure

Route from the catalog, not from memory:

```bash
bash scripts/catalog.sh   # lists every installed skill + its description
```

Then match the situation to the closest description. If two fit, prefer the one already on the main flow.
