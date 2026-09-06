---
name: consolidate-tests
description: Consolidate a sprawling test suite — hundreds of tiny TDD-generated tests — into fewer, faster tests that keep the same coverage and guarantees. Use when a test suite is slow, when tests should be merged or parameterized, when test-file sprawl needs reducing, or to review a finished feature's tests for consolidation.
---

# Consolidate tests

Shrink a suite that TDD grew — many tiny single-assertion tests with duplicated setup — into fewer, larger tests that run faster and cover exactly the same behavior. The one real risk is silent coverage loss: a merge that quietly drops an assertion still runs the same lines and stays green. So this is a **verification-gated loop**, not a free refactor. Every batch either proves it changed nothing observable, or it reverts.

If `CONTEXT.md` exists, read it so merged test names match the project's domain vocabulary, and respect ADRs covering the tested area.

## The tax is per-file, not per-test

A slow suite is rarely slow in its assertions. Break the runtime down by phase and the assertions are usually a sliver — the cost is process/interpreter startup, module import or compilation, and fixture/environment setup, paid once **per file** and again on every per-test setup hook. Consolidation buys speed by amortizing that fixed cost: fewer files, setup lifted out of the per-test path, expensive resources (DB, server) stood up once and shared. Parameterizing 40 tests into one table barely moves the clock — it earns its place by killing duplication so the next reader sees one behavior, not forty. Chase wall-clock in the setup phase, legibility in the test bodies.

## Speed has a ceiling — memory and CPU

Parallel workers, reused processes, and shared test environments (see [techniques.md](techniques.md)) all buy wall-clock by keeping more suites resident and running at once — they trade **memory for speed**. Past the box's ceiling that trade inverts: a full run at max parallelism exhausts RAM and gets OOM-killed, which surfaces as a hang or a failed suite, not as "too fast." So resource load is a metric beside wall-clock:

- Run the full suite **once at a time, sequentially** — never overlap two runs. Background measurement runs stack, and two suites at full parallelism is the fastest way to OOM the box.
- When memory climbs, **cap the worker/process count** your runner spawns instead of chasing peak parallelism.
- **Measure peak, not just wall-clock**: `/usr/bin/time -v <your test command>` reports Maximum resident set size. A batch that halves wall-clock but doubles peak RSS on a shared box moved the cost, it didn't remove it.

## The loop

Work in **small reversible batches** — one file, or one pattern in one file. A batch that regresses coverage must revert cleanly and point at its cause, which a 30-file sweep cannot. Reversible means git-backed: branch once off the green base, commit each batch only after it passes the gate, so reverting is `git reset` of one commit — not hand-unpicking a sweep.

Batches are small, but the **scope is the whole suite the user named** — every area, not the first. Map every candidate target across that scope up front (step 2), then run the loop until the map is empty in one pass: take the next target the moment a batch lands, and keep going on your own authority. Finishing one file or one area is a checkpoint, not the finish line.

1. **Baseline.** The suite is green, or stop — never consolidate on red. If the base branch is still moving, rebase onto it first: consolidating on a drifting base folds its behavior changes into your coverage diff and disguises them as consolidation errors. Then branch off the green base and capture coverage to a file with your runner's coverage command. This snapshot is the invariant every batch is checked against.
2. **Map the scope, take the next target.** On the first pass, enumerate every consolidation target across the whole scope (see *What to merge*); that map is the definition of done. Take the next target from it. Skip anything that isn't duplication-with-trivial-variation — as a recorded skip, not a silent one.
3. **Consolidate.** Apply one technique (see [techniques.md](techniques.md)). Keep behavior identical; change only structure.
4. **Verify — the gate.** Re-run the suite: still green. Re-run coverage: line, branch, and function no worse on **every** file, not merely in the total. Then break the source on purpose — flip one assertion's subject, or mutate the code under test — and confirm the merged test goes **red**. A merge that stays green on a real fault has dropped a guarantee. Any check fails → revert the batch (drop its commit). When a merged test goes red, first separate a real regression from base drift or pre-existing flake — re-run that test on the untouched baseline; only a fault the baseline doesn't show is the merge's, and only that one is yours to fix here.
5. **Repeat until the map is empty.** Move straight to the next target without pausing for permission between files or areas — the work is done when every target in scope is merged or recorded as skipped, not when the first batch lands. The only reasons to stop early: the map is exhausted, a batch can't pass the gate, or the user capped the scope. Then report once: files merged, test count before/after, wall-clock and peak RSS before/after, coverage delta (~0), and any targets skipped with why.

## What to merge, what to leave

The unit is **behavior**, not method or assertion. The heuristic:

- **Same behavior, varying data → parameterize.** N tests that differ only in input→expected collapse to one body plus a literal table — your framework's parameterized form (`it.each`, `@pytest.mark.parametrize`, JUnit `@ParameterizedTest`, Go table-driven loop, …). Each row still reports as its own case, so failure isolation survives.
- **Same behavior, one result object → group assertions.** Many checks against fields of the *same* produced value are one behavior; keep them together with a whole-object match or soft assertions so every field reports, not just the first to fail.
- **Different behaviors → keep separate.** Never merge two behaviors to cut lines. Dedupe only their *setup*, via a shared fixture or builder.
- **Same unit, scattered files → merge the files** and share one builder set.

Preserve granularity where it carries signal. Two checks that fail *independently for different reasons* stay two tests — collapsing them loses which cause fired.

## Anti-patterns of over-consolidation

- **Assertion roulette** — unrelated assertions in one test, so a failure names no cause. Merge only same-behavior assertions; keep per-case titles and use soft assertions.
- **Eager test** — one test exercising several behaviors end to end. Split it back out.
- **Hidden shared mutable state** — a lifted fixture that tests mutate becomes a false-pass/false-fail source. Lift to a once-per-file setup hook only when the resource is read-only or each test resets what it touched.
- **Logic in tests** — keep `if` / `for` / computed-expected out of a merged body. Use a *literal* table, never one that recomputes the code under test.

## Proving equivalence

Scope the coverage diff to the unit under test (most runners take an include/filter flag): coverage of files only incidentally touched jitters run-to-run, and comparing the whole map turns that noise into false regressions. Coverage percentages are also necessary but weak — they prove lines *ran*, not that anything *asserted* on them. That is why step 4 pairs the coverage diff with a deliberate source break: the cheap proof that the merged test still catches the fault. For a suite guarding something high-stakes, escalate to a mutation-score check (a mutation-testing tool — StrykerJS, mutmut, PIT, …) before and after — an equal-or-higher score proves the suite still catches the same faults, which coverage never shows.
