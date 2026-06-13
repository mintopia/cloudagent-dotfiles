# Design: `deep-analysis` skill

_Brainstormed with Jess — 2026-06-13_

## Motivation

Anthropic's Mythos-class model (Claude Fable 5 / Mythos 5) is not a new architecture
— staff have described "Mythos" as simply the largest, most capable base model in the
Haiku → Sonnet → Opus → Mythos line. Its perceived *depth* on hard problems comes from
two separable sources:

- **Innate** — a higher raw reasoning ceiling and always-on adaptive extended thinking
  (it explores approaches, checks its reasoning, and hunts edge cases internally before
  answering). Not portable to Opus.
- **Elicitable** — externally observable process behaviors: plan in stages, dispatch
  **fresh-context verifier sub-agents** to check its own work ("separate, fresh-context
  verifier subagents tend to outperform self-critique" — Anthropic's official Fable 5
  prompting guide), ground every claim in evidence, kill its own incorrect beliefs.

This skill ports the **elicitable** half to Opus 4.8. It raises Opus's *floor*
(reliability, fewer misses, bad ideas killed early) by spending tokens on externalized
adversarial verification. It does **not** raise the raw *ceiling* — that is innate to
the model. This trade-off is stated honestly inside the skill itself.

Sources: [Anthropic — Fable 5 & Mythos 5](https://www.anthropic.com/news/claude-fable-5-mythos-5),
[Prompting Claude Fable 5 (official guide)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5),
[Introducing Fable 5 (docs)](https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5).

## Decisions (locked during brainstorming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | **General-purpose** | Any hard analytical problem — design, debugging strategy, research, tradeoffs. Mirrors Fable's cross-domain reasoning. |
| Mechanism | **Sub-agent adversarial verification** | Fresh-context refuters are Anthropic's #1 Fable-5 recommendation and beat self-critique. |
| Harness | **Direct sub-agent dispatch (NOT the Workflow tool)** | Keeps the skill self-contained, predictable, and friendly to explicit invocation. The heavy `Workflow` fan-out was considered and rejected as overkill for the default path. |
| Invocation | **Explicit only** | Slash command `/deep-analysis`. Description is scoped to fire on explicit invocation, **not** generic "analyze this" asks — zero surprise token spend. |
| Output | **Artifact optional (flag)** | Inline deep answer by default; writes a structured doc to `decision-memory/` only with the `artifact` arg. |
| Final authority | **Claude is arbiter** | Verifiers advise; Claude incorporates valid refutations and rejects bad ones with a logged reason. |

## The depth loop

1. **FRAME** *(inline)* — Restate the problem from first principles. State the goal, the
   real intent/why, and explicit in/out-of-scope boundaries. Surface assumptions.
2. **DIVERGE** *(inline)* — Enumerate **≥3 genuinely distinct** approaches/hypotheses
   (not three flavors of one). For each: core idea, why it might be right, what would
   falsify it.
3. **REFUTE** *(fresh-context sub-agents — the heart)* — For the leading direction,
   dispatch N skeptic sub-agents (default 3) whose only job is to break it against the
   goal. Each receives the **problem + candidate only — never Opus's reasoning** (this is
   what beats self-critique and prevents an echo chamber). Diverse lenses: correctness,
   hidden assumptions, edge/failure modes, simpler alternative. Each returns
   `VERDICT: REFUTED` or `VERDICT: HOLDS` + specific objections + one-line fixes, biased
   toward "refuted if uncertain."
4. **ARBITRATE & ITERATE** — Majority-refute kills the belief → revise and loop back to
   DIVERGE with what was learned. Claude is final arbiter: incorporates valid
   refutations, rejects bad ones **with a logged reason**. Stop when a direction survives
   a round with no new material objection, or at `MAX_ROUNDS` (default 3). The loop
   **always terminates**; on deadlock, surface the unresolved disagreement rather than
   fake convergence.
5. **SYNTHESIZE & GROUND** — Recommendation + key tradeoffs + what was
   considered-and-refuted (and why) + residual risks/open questions. Ground confident
   claims in evidence (code/tool results/sources); flag the unverified. Final
   completeness-critic pass: "what approach/claim/edge-case did we miss?"

## Tunables (read from args, else default)

| Arg | Default | Meaning |
|-----|---------|---------|
| `verifiers=N` | 3 | Fresh-context skeptic sub-agents per refutation round. |
| `rounds=N` | 3 | Hard cap on diverge→refute iterations. The loop always terminates here. |
| `candidates=N` | 3 | Minimum distinct approaches enumerated in DIVERGE. |
| `artifact` | off | When present, write the structured analysis doc to `decision-memory/`. |

## Output artifact (when `artifact` set)

Written to `decision-memory/YYYY-MM-DD-<topic>-analysis.md`:

- **Problem & intent** — the framing settled in step 1.
- **Approaches considered** — the candidates from step 2.
- **Refutations & verdicts** — what each round's verifiers found; what Claude accepted/rejected and why.
- **Recommendation** — the surviving direction + tradeoffs.
- **Risks / open questions** — residuals and anything left genuinely unresolved.

## Files

- `skills/deep-analysis/SKILL.md` — matching repo house style: frontmatter (`name`,
  rich `description` scoped to **explicit** invocation), numbered prose steps, the
  refutation sub-agent prompt, **Hard rules**, **What NOT to do**.
- `skills/deep-analysis/evals/evals.json` — optional, added later to test triggering and behavior.

## Hard rules (will appear in the skill)

- Verifiers get **fresh context** — the problem + candidate only, never Opus's chain of
  reasoning. This is the single most important rule; it is what makes the skill beat
  self-critique.
- Verifiers are advisory. **Claude is final arbiter** and logs why it rejects any refutation.
- The loop **always terminates** at `MAX_ROUNDS`. On deadlock, present the unresolved
  disagreement — never fake convergence.
- Explicit invocation only. Do not run on trivial problems.
- Ground confident claims in evidence; flag unverified ones.

## What NOT to do

- Don't feed verifiers Opus's reasoning (defeats the fresh-context advantage).
- Don't auto-trigger on routine asks.
- Don't fake convergence to end the loop early.
- Don't reach for the `Workflow` tool — direct sub-agent dispatch is the design.

## Honest limitation (stated in the skill)

This skill makes Opus *act* deep by orchestrating explicit divergence and adversarial,
fresh-context verification — paying in tokens and latency for what Fable 5 does
internally. It improves reliability and catches bad directions early. It does **not**
raise Opus's raw reasoning ceiling.
