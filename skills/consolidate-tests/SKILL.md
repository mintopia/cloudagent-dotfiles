---
name: consolidate-tests
description: Consolidate a sprawling test suite — hundreds of tiny TDD-generated tests — into fewer, faster tests that keep the same coverage and guarantees. Use when a test suite is slow, when tests should be merged or parameterized, when test-file sprawl needs reducing, or to review a finished feature's tests for consolidation.
---

# Consolidate tests

Shrink a suite that TDD grew — many tiny single-assertion tests with duplicated setup — into fewer, larger tests that run faster and cover exactly the same behavior. The one real risk is silent coverage loss: a merge that quietly drops an assertion still runs the same lines and stays green. So this is a **verification-gated loop**, not a free refactor. Every batch either proves it changed nothing observable, or it reverts.

If `CONTEXT.md` exists, read it so merged test names match the project's domain vocabulary, and respect ADRs covering the tested area.

## The tax is per-file, not per-test

A slow suite is rarely slow in its assertions. Vitest's own `Duration` line usually reads `tests 1%` — the cost is `import`, `environment`, and worker setup, paid once **per file** and again on every `beforeEach`. Consolidation buys speed by amortizing that fixed cost: fewer files, setup lifted out of the per-test path, expensive resources (DB, server) stood up once and shared. Parameterizing 40 tests into one table barely moves the clock — it earns its place by killing duplication so the next reader sees one behavior, not forty. Chase wall-clock in the setup phase, legibility in the test bodies.

## The loop

Work in **small reversible batches** — one file, or one pattern in one file. A batch that regresses coverage must revert cleanly and point at its cause, which a 30-file sweep cannot.

1. **Baseline.** The suite is green, or stop — never consolidate on red. Capture coverage to a file: `vitest run --coverage`. This snapshot is the invariant every batch is checked against.
2. **Find a target.** Pick one consolidation target (see *What to merge*). Skip anything that isn't duplication-with-trivial-variation.
3. **Consolidate.** Apply one technique (see [techniques.md](techniques.md)). Keep behavior identical; change only structure.
4. **Verify — the gate.** Re-run the suite: still green. Re-run coverage: line, branch, and function no worse on **every** file, not merely in the total. Then break the source on purpose — flip one assertion's subject, or mutate the code under test — and confirm the merged test goes **red**. A merge that stays green on a real fault has dropped a guarantee. Any check fails → revert the batch.
5. **Repeat**, then report: files merged, test count before/after, wall-clock before/after, and coverage delta (should be ~0).

## What to merge, what to leave

The unit is **behavior**, not method or assertion. The heuristic:

- **Same behavior, varying data → parameterize.** N tests that differ only in input→expected collapse to one body plus a literal table (`it.each` / `test.for`). Each row still reports as its own case, so failure isolation survives.
- **Same behavior, one result object → group assertions.** Many checks against fields of the *same* produced value are one behavior; keep them together with `toMatchObject` or `expect.soft` so every field reports, not just the first to fail.
- **Different behaviors → keep separate.** Never merge two behaviors to cut lines. Dedupe only their *setup*, via a shared fixture or builder.
- **Same unit, scattered files → merge the files** and share one builder set.

Preserve granularity where it carries signal. Two checks that fail *independently for different reasons* stay two tests — collapsing them loses which cause fired.

## Anti-patterns of over-consolidation

- **Assertion roulette** — unrelated assertions in one test, so a failure names no cause. Merge only same-behavior assertions; keep per-case titles and use soft assertions.
- **Eager test** — one test exercising several behaviors end to end. Split it back out.
- **Hidden shared mutable state** — a lifted fixture that tests mutate becomes a false-pass/false-fail source. Lift to `beforeAll` only when the resource is read-only or each test resets what it touched.
- **Logic in tests** — keep `if` / `for` / computed-expected out of a merged body. Use a *literal* table, never one that recomputes the code under test.

## Proving equivalence

Coverage percentages are necessary but weak — they prove lines *ran*, not that anything *asserted* on them. That is why step 4 pairs the coverage diff with a deliberate source break: the cheap proof that the merged test still catches the fault. For a suite guarding something high-stakes, escalate to a mutation-score check (StrykerJS) before and after — an equal-or-higher score proves the suite still catches the same faults, which coverage never shows.
