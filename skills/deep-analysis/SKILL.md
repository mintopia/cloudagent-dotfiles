---
name: deep-analysis
description: Explicitly-invoked deep-reasoning harness that gives Claude Fable-5-style depth on a hard problem by running a diverge → refute → converge loop with fresh-context adversarial sub-agents. Frames the problem from first principles, enumerates >=3 genuinely distinct approaches, then dispatches skeptic sub-agents (fresh context — problem + candidate only, never Claude's own reasoning) to refute the leading direction, killing beliefs on majority-refute with Claude as final arbiter, until a direction survives a clean round or the rounds cap. Use ONLY when the user explicitly asks for it — "/deep-analysis", "deeply analyze this", "use deep-analysis on", "go deep on this", "stress-test this analysis/decision" — typically for high-stakes design, architecture, debugging strategy, or research/tradeoff decisions. Does NOT auto-trigger on generic "analyze this" asks. NOT for trivial questions, routine coding, or reviewing already-written code (use /code-review).
---

# Deep-Analysis — Make Claude Go Deep, On Purpose

A general-purpose depth harness. It ports the *elicitable* half of what makes
Anthropic's Mythos-class models (Fable 5 / Mythos 5) feel deep — explicit divergence,
and **fresh-context adversarial verification** ("separate, fresh-context verifier
subagents tend to outperform self-critique" — Anthropic's Fable 5 prompting guide) — onto
Claude here.

**Honest framing (tell the user this if they ask what it buys):** this raises the
*floor* — reliability, fewer missed angles, bad directions killed early — by spending
tokens and latency on externalized verification. It does **not** raise the raw reasoning
*ceiling*; that is innate to the model. Use it when getting the answer *right* is worth
more than getting it *fast*.

Run only when explicitly invoked. Don't reach for it on trivial asks.

---

## Tunables (read from the invocation args, else default)

| Arg | Default | Meaning |
|-----|---------|---------|
| `verifiers=N` | 3 | Fresh-context skeptic sub-agents per refutation round. |
| `rounds=N` | 3 | Hard cap on diverge→refute iterations. The loop ALWAYS terminates here. |
| `candidates=N` | 3 | Minimum distinct approaches enumerated in DIVERGE. |
| `artifact` | off | When present, also write the analysis to `decision-memory/`. |

Echo the resolved values before starting.

---

## The depth loop

### 1. FRAME (you, inline)
State, in a few lines:
- **Goal** — what a correct answer must achieve.
- **Intent** — the real *why* behind the request; what the answer unblocks.
- **Boundaries** — explicitly in scope vs. out of scope.
- **Assumptions** — anything you're taking as given. Mark the load-bearing ones.

If a fact can be settled by reading the codebase, docs, or running a command, settle it
now rather than assuming.

### 2. DIVERGE (you, inline)
Enumerate **at least `candidates` genuinely distinct** approaches / hypotheses / solutions
— distinct in *kind*, not three flavors of one idea. For each:
- core idea (1–2 lines),
- why it might be right,
- what observation would falsify it.

Pick a leading direction and say why.

### 3. REFUTE (fresh-context sub-agents — the heart)
Dispatch `verifiers` sub-agents **in parallel** (multiple `Agent` tool calls in one
message). Use `subagent_type: general-purpose`, or `Explore` when the problem is grounded
in this codebase.

Each verifier receives the **problem statement + the leading candidate ONLY**. Do **not**
include your FRAME/DIVERGE reasoning — fresh context is what makes this beat self-critique
and prevents an echo chamber.

When `verifiers >= 3`, give each a distinct lens so they don't all find the same thing:
1. **Correctness** — is the conclusion actually right?
2. **Hidden assumptions** — what unstated assumption does it rest on, and what if it's false?
3. **Edge cases / failure modes** — where does it break, scale badly, or misbehave?
4. **Simpler alternative** — is there a materially simpler approach that does as well?

(Assign lenses round-robin: extra verifiers beyond 4 repeat lenses 1–4 in order.)

Send each verifier this prompt (substitute `[PROBLEM]`, `[CANDIDATE]`, `[LENS]`):

> You are an adversarial verifier. You are given a PROBLEM and a CANDIDATE approach/answer.
> You do NOT have the author's reasoning — judge the candidate on its own merits.
> Your job is to find what is wrong with it, not to be agreeable. Focus your critique
> through this lens: [LENS]. Identify concrete flaws — wrong conclusions, unstated
> assumptions, ignored edge cases or failure modes, misreadings of the problem, or a
> materially simpler alternative. For each flaw, give a one-line fix. If you genuinely
> cannot find a material flaw, say so. Default to REFUTED when you are uncertain it holds.
> End your reply with EXACTLY one line: `VERDICT: HOLDS` or `VERDICT: REFUTED`.
>
> PROBLEM:
> [PROBLEM]
>
> CANDIDATE:
> [CANDIDATE]

### 4. ARBITRATE & ITERATE
Collect the verdicts.
- **Majority `REFUTED`** (half or more — ties count as refuted, matching the verifiers'
  "default to REFUTED when uncertain") → the belief is killed. Take what's valid, return
  to DIVERGE informed by the objections, and start the next round.
- **Majority `HOLDS`** → the direction survives this round.

**You are the final arbiter** — verifiers advise, they don't command. For every objection
you reject, log one line on *why* (factually wrong, out of scope, cost not worth it).
Don't cave to every objection (that defeats the check) and don't ignore them (that defeats
the point).

**Stop when** the leading direction survives a round with **majority `HOLDS` and no
*new material* objection**, or you hit `rounds`. The loop ALWAYS terminates. On deadlock at `rounds`, do NOT fake
convergence — present the unresolved disagreement (each open point + your counter-position)
and hand the tie to the user.

### 5. SYNTHESIZE & GROUND
Produce the answer:
- **Recommendation** + the key tradeoffs that decided it.
- **Considered & refuted** — the rejected approaches and the one-line reason each died.
- **Risks / open questions** — residuals; anything left genuinely unresolved.

Ground confident claims in evidence (a tool result, a file, a source). Flag anything you
could not verify rather than asserting it. Finish with a one-pass **completeness critic**:
"what approach, claim, or edge case did we not examine?" — and address or name it.

---

## Output artifact (only when `artifact` is set)

Inline answer is the default. When `artifact` is passed, ALSO write the analysis to
`decision-memory/YYYY-MM-DD-<topic>-analysis.md`, relative to the repo/working root
(create `decision-memory/` if missing)
with these sections:

```markdown
# Deep analysis: <topic>
_Run via deep-analysis — <date>, <N rounds run>, <verifiers> verifiers/round_

## Problem & intent
## Approaches considered
## Refutations & verdicts
<per round: each verifier's lens + verdict + key objections; what you accepted/rejected and why>
## Recommendation
## Risks / open questions
```

---

## Hard rules
- Verifiers get **fresh context** — the problem + candidate only, NEVER your FRAME/DIVERGE
  reasoning. This is the single most important rule; it is what makes the skill beat
  self-critique.
- Verifiers are advisory. **You are the final arbiter** and log one line for every
  objection you reject.
- The loop **ALWAYS terminates** at `rounds`. On deadlock, present the unresolved
  disagreement — never fake convergence.
- Explicit invocation only. Don't run this on trivial problems.
- Ground confident claims in evidence; flag the unverified ones.

## What NOT to do
- Don't feed verifiers your own reasoning (defeats the fresh-context advantage).
- Don't auto-trigger on routine "analyze this" asks.
- Don't fake convergence to end the loop early.
- Don't reach for the `Workflow` tool — direct parallel `Agent` dispatch is the design.
- Don't use this to review already-written code — that's `/code-review`.

## Honest limitation
This skill makes Claude *act* deep by orchestrating explicit divergence and adversarial,
fresh-context verification — paying tokens and latency for what a Mythos-class model does
internally. It improves reliability and catches bad directions early. It does **not** raise
the model's raw reasoning ceiling.
