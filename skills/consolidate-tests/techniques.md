# Consolidation techniques

The catalog for step 3. Each entry: when it applies, the before→after shape, and the safe-when rule. Examples reference the harmonic suite (Vitest + TypeScript) — a suite grown to 257 files / 2,557 tests / 82s wall clock, where `import` alone was 85s of worker time. The patterns are the same in any framework.

## 1. Parameterize repeated cases — `it.each` / `test.for`

When a run of tests differ only by input and expected output. Look for hand-rolled loops that generate tests, or copy-pasted `it()` blocks with one value changed.

`harmonic/tests/guardrail-budget.test.ts` builds 41 tests with a raw loop:

```ts
for (const stepType of STEP_TYPES) {
  it(`counts ${stepType} against the budget`, () => { /* ... */ })
}
```

A loop that calls `it` hides cases from the reporter and invites logic creep. Use a literal table:

```ts
it.each([
  ['plan',   1],
  ['edit',   1],
  ['review', 0],
])('counts %s against the budget as %i', (stepType, cost) => {
  expect(budgetCost(stepType)).toBe(cost)
})
```

Safe when: the table is **literal data**, not computed from the code under test. Each row reports as its own case, so failure isolation is preserved. Reach for `test.for` instead of `test.each` when the body also needs `TestContext`.

## 2. Lift setup out of the per-test path — shared fixture + `beforeAll`

The biggest wall-clock lever. Expensive setup — server boot, DB migration — repeated per `it` dominates the clock.

`harmonic/tests/conversation-keys.test.ts` boots a full Fastify server six times, once per test:

```ts
it('...', async () => { const server = await startServer(stubHarness()); /* ... */ })
it('...', async () => { const server = await startServer(stubHarness()); /* ... */ })
```

Read-only tests can share one server:

```ts
let server
beforeAll(async () => { server = await startServer(stubHarness()) })
afterAll(() => server.close())
```

Safe when: tests only read shared state, or each test resets what it mutates. If tests mutate and can't cheaply reset, keep `beforeEach`. For per-test *data* isolation without re-migrating, copy a pre-migrated DB template rather than migrating each time — see `harmonic/tests/helpers.ts` `migratedDbTemplate` (migrate once, `copyFileSync` per server).

## 3. Merge near-duplicate files + share builders

When many files test one unit or one feature area with copy-pasted scaffolding.

Harmonic has 44 `*-model.test.ts` files for pure view-model functions, many redefining near-identical factory builders (e.g. `epic-model.test.ts` defines local `member()` / `epic()` builders duplicated in sibling files). Merge by feature cluster (`conversation-*`, `attempt-*`) into one file per unit, sharing one builder set.

Safe when: the merged file stays one unit's worth of behavior. Don't merge unrelated units into a grab-bag — file boundaries that map to units are navigation, not waste.

## 4. Group assertions on one result — `toMatchObject` / `expect.soft`

When consecutive tests each assert one field of the *same* produced value:

```ts
// before: separate tests, each recomputing the same value
it('sets id',   () => expect(build().id).toBe('x'))
it('sets name', () => expect(build().name).toBe('y'))
```

```ts
// after: one behavior, all fields report
it('builds the record', () => {
  expect(build()).toMatchObject({ id: 'x', name: 'y' })
})
```

Use `expect.soft(...)` when fields need individual assertions but should all report on failure instead of stopping at the first.

Safe when: the fields describe *one* behavior on *one* value. Two independently-failing behaviors stay separate.

## 5. Vitest config levers

Suite-wide speed beyond per-file merges:

- **`isolate: false` with `pool: 'threads'` (or `'forks'`)** reuses the worker and environment across files instead of rebuilding per file — the single biggest config win when tests tolerate shared module state. Harmonic already applies this to its hot files via a `fast` project (`isolate:false` + a `fast-pool.list`), leaving the rest in an `isolated` project. Confirm the suite still passes under it, and check `vitest doctor`.
- **`test.concurrent` / `maxConcurrency`** run async tests within a file in parallel. Concurrent tests must use the context `expect`: `async ({ expect }) => { /* ... */ }`, or assertions attribute to the wrong case.
- **Profile before tuning.** The `Duration` line breaks down `environment` / `import` / `transform` / `tests` — attack the dominant phase, which in a tiny-test suite is almost never `tests`.
