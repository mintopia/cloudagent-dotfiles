# Decision: Vendor the `no-comments` pstack skill, reversing its skip in ADR 0012

Status: accepted
Date: 2026-08-20

## Context

[ADR 0012](0012-adopt-selected-pstack-skills.md) skipped `no-comments`, grouping
it with skills ponytail already covers — the always-on ponytail mode prunes
unnecessary comments as code is written. On reflection we want the heavier,
adversarial pass too: a dedicated skeptical sweep over an existing diff that
hunts narration, workaround sermons, and lint/TypeScript suppressions, and that
offers to encode claimed constraints as real types/tests/CI instead of prose.
That is a different lens from ponytail's write-time discipline, and worth the
overlap — the same way `interrogate` earns its place alongside `code-review`.

Upstream `no-comments` is not install-unchanged: it spawns a Cursor-registered
`Comment Sicko` subagent and calls `/architect`, `/how`, and `principle-*`
skills that this stack does not install. It therefore falls under ADR 0012's
Lane 2 (vendor with light generic rework), not Lane 1.

## Decision

Vendor `no-comments` into `skills/no-comments/` as a first-party skill, faithful
to upstream with only Cursor→Claude mechanics reworked:

- `subagent_type: "Comment Sicko"` → a `general-purpose` Agent/Task subagent
  whose prompt is the ported persona in `references/comment-sicko.md`. Same
  pattern as `interrogate`/`reflect`; no reliance on a registered agent type.
- `/how` + `/why` → `/why` (the only one of the pair we vendored).
- `/architect` → sketch in place, or `/codebase-design`; stop at the sketch.
- `principle-fix-root-causes` / `principle-redesign-from-first-principles` → the
  root-cause and first-principles reflexes already encoded in `AGENTS.md`
  (ADR 0012 Lane 3).
- Keep `disable-model-invocation: true`.

No `install.sh` change: it already copies every `skills/*/` dir (SKILL.md +
`references/`) wholesale. `ask-jess` picks it up via its catalog.

## Consequences

- One more vendored copy we own and must maintain; it will drift from upstream,
  the accepted cost of not modifying third-party skills in place (per ADR 0012).
- Deliberate overlap with ponytail's write-time comment discipline — different
  lens (adversarial after-the-fact sweep vs. always-on pruning), same rationale
  as keeping `interrogate` beside `code-review`.
- Retiring it later is one `rm -r skills/no-comments/`.

## Supersedes

Partially amends [ADR 0012](0012-adopt-selected-pstack-skills.md): moves
`no-comments` from its **Skip** list into Lane 2 (vendored). The rest of ADR 0012
stands.
