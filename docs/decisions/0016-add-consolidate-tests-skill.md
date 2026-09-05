# Decision: Add a first-party `consolidate-tests` skill

Status: accepted
Date: 2026-09-05

## Context

A TDD workflow (the `tdd` skill from the Matt Pocock set,
[ADR 0006](0006-install-all-mattpocock-skills.md)) grows a suite one red→green
cycle at a time. That is correct during development but leaves suites with
hundreds or thousands of tiny single-assertion tests carrying duplicated setup —
harmonic, our reference project, has 257 test files / 2,557 tests / ~43k LOC and
an 82s run in which ~85s of worker time is `import`, not assertions. Nothing in
the installed stack condenses such a suite once a feature is done.

The obvious danger of "merge tests to go faster" is silently dropping coverage: a
merge that removes an assertion still executes the same lines and stays green. So
the skill has to be a verification loop, not a free refactor, and it has to teach
the per-file cost model (the tax is per-file setup, not per-test assertions) or it
will optimise the wrong phase.

No existing skill covers post-development test consolidation. `tdd` writes tests,
`code-review`/`ponytail-review` critique diffs, `simplify` does quality cleanups
of changed code — none condense a whole grown suite under a coverage guarantee.

## Decision

Add `consolidate-tests` as a **first-party skill authored in this repo** under
`skills/consolidate-tests/`, installed by the existing local-skills copy loop in
`install.sh` (the same path that installs `adr`, `pickup`, `visual-companion`,
etc.) — no npx dependency and no upstream to track, unlike the vendored skills in
[ADR 0012](0012-adopt-selected-pstack-skills.md) /
[ADR 0014](0014-vendor-visual-companion-as-standalone-skill.md).

- **Model-invoked** (keeps a `description`), so the agent can reach it on its own
  and other skills can call it, and the user can still type `/consolidate-tests`.
- **Structure** follows the `writing-for-agents` reference: `SKILL.md` holds the
  always-needed spine (the verification loop, the safe-to-merge heuristic,
  anti-patterns, the equivalence proof); `techniques.md` is disclosed reference
  (the before/after pattern catalog), reached by a pointer because which pattern
  applies is branchy.
- **Spine is a verification-gated loop**: baseline (green + coverage snapshot) →
  find one target → consolidate one small reversible batch → prove equivalence →
  revert-or-keep → report. The gate is coverage no-worse **per file** plus a
  deliberate source break that must turn the merged test red, escalating to a
  mutation-score check (StrykerJS) for high-stakes suites.

## Consequences

- One more first-party skill to maintain; it is self-contained (two Markdown
  files, no scripts, no MCP/hooks), so the maintenance surface is small.
- Its examples are grounded in harmonic file paths and its config advice is
  Vitest-specific. The loop and heuristic are framework-agnostic, but the
  concrete snippets will drift if harmonic's tests are restructured — accepted,
  since they are illustrations, not a contract.
- Retiring it is a clean `git rm` of `skills/consolidate-tests/`; nothing else
  depends on it.
- README skills list and directory tree updated to include it.

## Supersedes

None. Complements the `tdd` skill from
[ADR 0006](0006-install-all-mattpocock-skills.md) (this is the post-development
counterpart to test-first development) and follows the local first-party skill
pattern rather than the npx path of
[ADR 0007](0007-move-impeccable-plugin-to-skill.md).
