---
name: quality-gate
description: Enforce that all tests, linting, and quality checks pass before work is considered complete. Use this skill whenever tests fail, linting fails, type checking fails, CI checks fail, or any automated quality tool reports errors — even if the failures appear unrelated to the current task. Also use before claiming any task is finished to ensure checks have actually been run. This skill is non-negotiable — if something is red, it gets fixed.
---

# Quality Gate

## The Rule

**Every failure gets fixed. No exceptions.**

When tests, linting, type checking, or any automated quality tool fails, fix every failure before moving on. It does not matter whether you introduced the failure. It does not matter whether the failure is "unrelated" to the current task. If the suite is red, your job is to make it green.

## Why This Matters

The user's codebase is a shared artifact. Dismissing failures as "unrelated" or "pre-existing" means broken things stay broken and accumulate. The user has asked you to help maintain their codebase — that means leaving it in a passing state, every time. A green suite is the baseline, not a stretch goal.

When you say "these failures are unrelated to my changes," what the user hears is: "I see the problem but I'm choosing not to fix it." That's not helpful. Fix it.

## Before Claiming Work Is Complete

Run the project's full quality suite. This means whatever combination of test runners, linters, type checkers, and formatters the project uses. Look for configuration files, scripts, CI definitions, and Makefiles to discover what checks exist. Common patterns:

- Test runners (pytest, jest, phpunit, go test, rspec, etc.)
- Linters (eslint, phpstan, pylint, rubocop, golangci-lint, etc.)
- Type checkers (mypy, pyright, tsc, etc.)
- Formatters (prettier, black, gofmt, php-cs-fixer, etc.)

If you are unsure what checks the project uses, look at CI configuration, package.json scripts, Makefile targets, or ask the user. Do not guess and do not skip.

## When Failures Occur

1. **Read every failure.** Do not skim. Understand what each one is telling you.
2. **Fix every failure.** Not just the ones that look related to your changes. All of them.
3. **Re-run the full suite** after your fixes to confirm everything passes.
4. **If a fix introduces new failures**, fix those too. Keep going until the suite is fully green.

## Phrases You Must Never Use

These are signs you are about to dismiss a failure instead of fixing it:

- "These failures appear to be unrelated to my changes"
- "These were pre-existing failures"
- "The test suite was already failing before my changes"
- "This is a flaky test"
- "This failure is in a different module"
- "Ignoring unrelated failures"

If you catch yourself reaching for any of these, stop and fix the failure instead. If you genuinely believe a test is flaky (produces different results on identical code), re-run it to confirm. If it passes on re-run, fine. If it fails again, fix it.

## The Only Exception

If fixing a failure would require changes so large that they should be a separate piece of work (e.g., a major dependency upgrade, a fundamental architectural change), tell the user explicitly what the failure is, why you believe it is out of scope, and ask for their decision. Do not silently skip it. The user decides what is in scope, not you.
