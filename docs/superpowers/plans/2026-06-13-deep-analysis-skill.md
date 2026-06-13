# deep-analysis Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an explicitly-invoked `deep-analysis` skill that gives Opus Fable-5-style depth on hard problems via a diverge → fresh-context adversarial sub-agent refutation → converge loop.

**Architecture:** A single `skills/deep-analysis/SKILL.md` in the repo house style (rich frontmatter, numbered prose steps, Hard rules, What NOT to do), plus `skills/deep-analysis/evals/evals.json`. The skill instructs Claude to run the depth loop and dispatch fresh-context skeptic sub-agents via the `Agent`/`Task` tool. No code, no Workflow tool, no new dependencies. `install.sh` auto-discovers the skill dir — no install change needed.

**Tech Stack:** Markdown (SKILL.md), JSON (evals). Skill is consumed by the Claude Code harness; sub-agents are dispatched with the `Agent` tool (`subagent_type: general-purpose`, or `Explore` for codebase-grounded problems).

---

## File Structure

- `skills/deep-analysis/SKILL.md` — the skill. One responsibility: drive the depth loop on explicit invocation. Built up over Tasks 1–3, committed in Task 4.
- `skills/deep-analysis/evals/evals.json` — trigger + behavior evals (positive and negative). Task 5. Not copied by install.sh (matches `subagent-finder`, `quality-gate`).

Reference spec: `docs/superpowers/specs/2026-06-13-deep-analysis-skill-design.md`.

---

### Task 1: Scaffold skill + frontmatter and intro

**Files:**
- Create: `skills/deep-analysis/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p skills/deep-analysis/evals
```

- [ ] **Step 2: Write `skills/deep-analysis/SKILL.md` with the frontmatter, title, and intro**

Write exactly this content (it becomes the file; later tasks append):

````markdown
---
name: deep-analysis
description: Explicitly-invoked deep-reasoning harness that gives Claude Fable-5-style depth on a hard problem by running a diverge → refute → converge loop with fresh-context adversarial sub-agents. Frames the problem from first principles, enumerates >=3 genuinely distinct approaches, then dispatches skeptic sub-agents (fresh context — problem + candidate only, never Claude's own reasoning) to refute the leading direction, killing beliefs on majority-refute with Claude as final arbiter, until a direction survives a clean round or MAX_ROUNDS. Use ONLY when the user explicitly asks for it — "/deep-analysis", "deeply analyze this", "use deep-analysis on", "go deep on this", "stress-test this analysis/decision" — typically for high-stakes design, architecture, debugging strategy, or research/tradeoff decisions. Does NOT auto-trigger on generic "analyze this" asks. NOT for trivial questions, routine coding, or reviewing already-written code (use /code-review).
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
````

- [ ] **Step 3: Verify the frontmatter parses**

Run:
```bash
head -3 skills/deep-analysis/SKILL.md
python3 -c "import sys,re; t=open('skills/deep-analysis/SKILL.md').read(); m=re.match(r'^---\n(.*?)\n---\n', t, re.S); assert m, 'no frontmatter'; import yaml; d=yaml.safe_load(m.group(1)) if 'yaml' in sys.modules or True else None" 2>/dev/null || python3 -c "import re; t=open('skills/deep-analysis/SKILL.md').read(); m=re.match(r'^---\n(.*?)\n---\n', t, re.S); assert m, 'no frontmatter'; assert 'name: deep-analysis' in m.group(1); assert 'description:' in m.group(1); print('frontmatter OK')"
```
Expected: prints `frontmatter OK` (the second command is the fallback if PyYAML is absent).

---

### Task 2: Write the depth-loop body

**Files:**
- Modify: `skills/deep-analysis/SKILL.md` (append)

- [ ] **Step 1: Append the depth loop, verifier prompt, and tunables**

Append exactly this content to `skills/deep-analysis/SKILL.md`:

````markdown

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

(Extra verifiers beyond 4 repeat lenses 1–4.)

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
- **Majority `REFUTED`** (more than half) → the belief is killed. Take what's valid, return
  to DIVERGE informed by the objections, and start the next round.
- **Majority `HOLDS`** → the direction survives this round.

**You are the final arbiter** — verifiers advise, they don't command. For every objection
you reject, log one line on *why* (factually wrong, out of scope, cost not worth it).
Don't cave to every objection (that defeats the check) and don't ignore them (that defeats
the point).

**Stop when** the leading direction survives a full round with no *new material* objection,
or you hit `rounds`. The loop ALWAYS terminates. On deadlock at `rounds`, do NOT fake
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
````

- [ ] **Step 2: Verify the body landed**

Run:
```bash
grep -c "VERDICT: HOLDS" skills/deep-analysis/SKILL.md && grep -n "^### 3. REFUTE" skills/deep-analysis/SKILL.md
```
Expected: prints a count `>= 1` then the matching `### 3. REFUTE ...` line.

---

### Task 3: Write the artifact spec, hard rules, and limits

**Files:**
- Modify: `skills/deep-analysis/SKILL.md` (append)

- [ ] **Step 1: Append the artifact section, Hard rules, What NOT to do, and limitation**

Append exactly this content to `skills/deep-analysis/SKILL.md`:

````markdown

---

## Output artifact (only when `artifact` is set)

Inline answer is the default. When `artifact` is passed, ALSO write the analysis to
`decision-memory/YYYY-MM-DD-<topic>-analysis.md` (create `decision-memory/` if missing)
with these sections:

```markdown
# Deep analysis: <topic>
_Run via deep-analysis — <date>, <rounds> round(s), <verifiers> verifiers/round_

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
````

- [ ] **Step 2: Verify all required sections are present**

Run:
```bash
for s in "## Tunables" "## The depth loop" "### 1. FRAME" "### 3. REFUTE" "### 5. SYNTHESIZE" "## Output artifact" "## Hard rules" "## What NOT to do" "## Honest limitation"; do
  grep -q "$s" skills/deep-analysis/SKILL.md && echo "OK  $s" || echo "MISSING  $s"
done
```
Expected: every line prints `OK ...`, none `MISSING`.

---

### Task 4: Validate and commit the SKILL.md

**Files:**
- Verify: `skills/deep-analysis/SKILL.md`

- [ ] **Step 1: Validate frontmatter and check description length**

Run:
```bash
python3 -c "
import re
t=open('skills/deep-analysis/SKILL.md').read()
m=re.match(r'^---\n(.*?)\n---\n', t, re.S); assert m, 'no frontmatter'
fm=m.group(1)
assert 'name: deep-analysis' in fm, 'name missing'
desc=re.search(r'description:\s*(.+)', fm).group(1)
assert 200 < len(desc) < 1400, f'description length {len(desc)} out of range'
print('SKILL.md valid; description length', len(desc))
"
```
Expected: `SKILL.md valid; description length <N>` with N between 200 and 1400.

- [ ] **Step 2: Commit the skill**

```bash
git add skills/deep-analysis/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skills): add deep-analysis depth harness

Diverge -> fresh-context adversarial sub-agent refutation -> converge.
Ports Fable 5's elicitable depth behaviors to Opus. Explicit invocation only.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Write and commit evals

**Files:**
- Create: `skills/deep-analysis/evals/evals.json`

- [ ] **Step 1: Write `skills/deep-analysis/evals/evals.json`**

Write exactly this content:

```json
{
  "skill_name": "deep-analysis",
  "evals": [
    {
      "id": 1,
      "prompt": "Use deep-analysis on this: should we move our session store from Postgres to Redis? Go deep before recommending.",
      "expected_output": "Should run the depth loop: FRAME the goal/intent/boundaries, DIVERGE >=3 distinct options (e.g. stay on Postgres, Redis, hybrid), dispatch fresh-context skeptic sub-agents to refute the leading option, arbitrate, and synthesize a grounded recommendation with refuted alternatives and risks.",
      "files": []
    },
    {
      "id": 2,
      "prompt": "/deep-analysis rounds=2 verifiers=4 artifact   Our checkout conversion dropped 8% after the last release. Deeply analyze the most likely cause.",
      "expected_output": "Should echo resolved tunables (rounds=2, verifiers=4, artifact on), enumerate >=3 distinct hypotheses, dispatch 4 fresh-context verifiers with distinct lenses, iterate at most 2 rounds, and ALSO write a decision-memory/ analysis artifact.",
      "files": []
    },
    {
      "id": 3,
      "prompt": "Stress-test this analysis with deep-analysis: I've concluded the memory leak is in the image-resize worker because RSS climbs during batch jobs.",
      "expected_output": "Should treat the stated conclusion as the leading candidate, dispatch fresh-context refuters (NOT given the user's reasoning) to attack it, and either kill it on majority-refute or confirm it survives, with Claude as final arbiter.",
      "files": []
    },
    {
      "id": 4,
      "prompt": "What's the capital of France?",
      "expected_output": "Should NOT trigger deep-analysis. This is a trivial factual question; answer directly.",
      "files": []
    },
    {
      "id": 5,
      "prompt": "Can you review the changes on my current branch?",
      "expected_output": "Should NOT trigger deep-analysis. Reviewing already-written code is /code-review's job, not this skill.",
      "files": []
    }
  ]
}
```

- [ ] **Step 2: Validate the JSON**

Run:
```bash
python3 -c "import json; d=json.load(open('skills/deep-analysis/evals/evals.json')); assert d['skill_name']=='deep-analysis'; assert len(d['evals'])==5; print('evals.json valid:', len(d['evals']), 'cases')"
```
Expected: `evals.json valid: 5 cases`

- [ ] **Step 3: Commit the evals**

```bash
git add skills/deep-analysis/evals/evals.json
git commit -m "$(cat <<'EOF'
test(deep-analysis): add trigger and behavior evals

Three positive cases (invoke + tunables + stress-test) and two negative
cases (trivial question, code review) to guard explicit-only triggering.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Spec-coverage verification and final report

**Files:**
- Verify only.

- [ ] **Step 1: Confirm every spec decision maps to skill content**

Run:
```bash
S=skills/deep-analysis/SKILL.md
echo "general-purpose framing:"; grep -qi "general-purpose depth harness" $S && echo OK
echo "fresh-context rule:";      grep -qi "fresh context" $S && echo OK
echo "claude is arbiter:";       grep -qi "final arbiter" $S && echo OK
echo "always terminates:";       grep -qi "ALWAYS terminate" $S && echo OK
echo "explicit-only:";           grep -qi "Explicit invocation only" $S && echo OK
echo "artifact optional:";       grep -qi "only when .artifact. is set" $S && echo OK
echo "no Workflow tool:";        grep -qi "Don't reach for the .Workflow. tool" $S && echo OK
echo "honest limitation:";       grep -qi "does .not. raise the model's raw reasoning ceiling" $S && echo OK
```
Expected: each label followed by `OK`.

- [ ] **Step 2 (optional): Run the eval suite with skill-creator**

If the `skill-creator` skill is available, invoke it to run `skills/deep-analysis/evals/evals.json` and confirm the three positive cases trigger the skill and the two negative cases do not. Record results. Skip if the eval harness is unavailable in this environment.

- [ ] **Step 3: Report**

Summarize to the user: files created, commit hashes, eval results (or that eval run was skipped), and a one-line reminder that the skill is explicit-invocation only and auto-installs via `install.sh` on next run.

---

## Self-Review

**Spec coverage:** Every decision in the spec table maps to a task — general-purpose (Task 1 intro), sub-agent adversarial verify (Task 2 REFUTE), direct dispatch not Workflow (Task 2 dispatch + Task 3 What-NOT-to-do), explicit-only (Task 1 description + Task 3 Hard rules), artifact-optional (Task 3 Output artifact), Claude-arbiter (Task 2 ARBITRATE). Tunables, hard rules, what-not-to-do, honest limitation all covered. Task 6 Step 1 re-checks coverage mechanically.

**Placeholder scan:** No TBD/TODO. All file content is given verbatim; all commands have expected output.

**Type/name consistency:** Section headings referenced in verification steps (`### 3. REFUTE`, `## Honest limitation`, etc.) match the headings written in Tasks 2–3. Arg names (`verifiers`, `rounds`, `candidates`, `artifact`) are used identically in the Tunables table, the loop body, and the evals. `VERDICT: HOLDS` / `VERDICT: REFUTED` are consistent between the verifier prompt and the ARBITRATE step.
