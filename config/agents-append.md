
## Engineering principles

Always-apply reflexes (harvested from pstack; see ADR 0012). Apply them by default; they are guidance, not gates.

1. **Type-system discipline** — make illegal states unrepresentable, brand semantic primitives, parse external data at boundaries, exhaust variants, derive types from the authoritative schema. Never lie to the compiler to silence it.
2. **Model the domain** — encode the domain in a data structure, not scattered conditionals. When code branches a lot or repeats a shape assumption across files, the structure is wrong.
3. **Make operations idempotent** — commands, lifecycle steps, and processing loops must converge to the same end state regardless of partial prior runs, amid crashes, restarts, and retries.
4. **Prove it works** — before declaring done, verify against the real artifact (run the feature, read the actual value, inspect the diff). Not a proxy, not self-report, not "it compiles."
5. **Guard the context window** — route bulk work to subagents; keep summaries in the main thread, never raw payloads. When context fills (large outputs, long files, repeated reads, fan-out), fan out and summarise.

## Decision Memory

Before proposing architecture, tooling, style, testing, repo structure, or workflow changes in any project:

1. Check for a `docs/decisions/` directory in the project root.
2. If it exists, search it for relevant ADRs (Architecture Decision Records).
3. Treat accepted ADRs as binding unless explicitly overridden by the user.
4. If a decision is outdated, propose a new ADR that supersedes it rather than silently ignoring.
5. Do not re-litigate accepted decisions unless new constraints are introduced.

When creating new ADRs, use this format:

```markdown
# Decision: [Title]

Status: [proposed|accepted|deprecated|superseded]
Date: [YYYY-MM-DD]

## Context
[Why this decision is needed]

## Decision
[What was decided]

## Consequences
[Trade-offs and implications]

## Supersedes
[Reference to previous ADR, or "None"]
```
