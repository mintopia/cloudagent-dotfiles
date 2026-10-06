# Decision: Add a first-party, user-invoked `ui-design` skill

Status: accepted
Date: 2026-10-05

## Context

The installed design skills (`impeccable`, the `frontend-design` plugin) give
aesthetic direction but few checkable numbers, and agent-built UI fails most
often on things that look fine and behave wrongly: missing accessible names,
focus rings that vanish, forms that validate on the first keystroke, error
toasts that fade unread, layouts that break at zoom, on mobile or in
translation. A rulebook distilled from practitioner design videos (Kole Jain,
uxpeak) and a deep-research pass over WCAG 2.2, the ARIA Authoring Practices,
NN/g, Baymard and GOV.UK fills that gap with concrete values and a
verification step.

`impeccable` already claims nearly every UI trigger word in its description, so
a second model-invoked design skill would fire unpredictably against it.

## Decision

Add `ui-design` as a **first-party skill authored in this repo** under
`skills/ui-design/`, installed by the existing local-skills copy loop in
`install.sh` (all its files are top-level Markdown, which the loop already
copies).

- **User-invoked** (`disable-model-invocation: true`): it fires only on
  `/ui-design`, costs no always-loaded context, and never competes with
  `impeccable` for triggers.
- **Structure** follows the `writing-for-agents` reference: `SKILL.md` holds the
  7-step process and the rules every screen needs; branch material is disclosed
  behind pointers (`PRODUCT-UI`, `MARKETING`, `COLOR`, `MOTION`, `FORMS`,
  `WIDGETS`, `RESPONSIVE`, `I18N`, `REVIEW`).
- **Verification is the final step**: Playwright screenshots of every scripted
  state, axe-core, a keyboard walk, and 320px / 200% zoom checks.

## Consequences

- One more first-party skill to maintain; ten Markdown files, no scripts.
- Being user-invoked, it relies on the human remembering `/ui-design`.
- Some values are practitioner convention rather than research (e.g. spinner
  delays); the skill labels those, and `REVIEW.md` grades popular UX "laws".
- Retiring it is a `git rm` of `skills/ui-design/` plus a `DEPRECATED_SKILLS`
  entry.

## Supersedes

None. Complements `impeccable` ([ADR 0007](0007-move-impeccable-plugin-to-skill.md))
and the `frontend-design` plugin ([ADR 0003](0003-add-frontend-design-plugin.md)).
