# Decision: Install the `no-ai-slop` skill and fold its patterns into the ADHD output style

Status: accepted
Date: 2026-09-03

## Context

[petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop) is a single
self-contained editing skill (MIT) that strips 20+ AI-slop patterns — binary
contrasts, colon reveals, faux-insight setups, importance puffery, weasel
attribution, decorative em dashes, banned words — from a draft while preserving
the writer's voice. It runs on demand (`/no-ai-slop <draft>`) for editing and
detecting slop in prose.

The skill only fires when explicitly invoked on a piece of writing. We also want
its texture rules applied to *every* response by default, not just documents fed
to the skill. The [I Have ADHD output style](0009-adhd-output-style-native.md)
already governs response shape (action-first, no preamble/recap), but it polices
brevity, not slop texture — clipped output can still read as model-generated.

## Decision

Two changes:

1. **Install the skill via npx.** Add `[petergyang/no-ai-slop]="no-ai-slop skill"`
   to the `THIRDPARTY_SKILLS` map in `install.sh`, the same path used for
   impeccable, ponytail, and the tsmura grill/codex family
   ([ADR 0007](0007-move-impeccable-plugin-to-skill.md)). The repo has one skill,
   so the whole-repo `npx skills add` pull needs no `--skill` filter.

2. **Fold the anti-slop patterns into the output style.** Add Rule 11 ("No AI
   slop") to `config/output-styles/i-have-adhd.md` plus a slop line in its
   pre-send check. Rule 11 carries only the *texture* patterns the existing rules
   don't already cover — preamble/recap/closers are handled by Rules 3 and 10, so
   Rule 11 adds binary contrasts, colon reveals, puffery, weasel attribution,
   banned words, em-dash policy, concrete-over-abstract, and active voice.

The skill stays installed for on-demand editing of other people's drafts and for
detect/audit runs; the output-style rule makes the same discipline the default
for our own responses.

## Consequences

- Every response is held to the slop patterns, not just drafts passed to the
  skill. Rule 11 duplicates none of Rules 3/10; it references them instead.
- One more third-party npx skill to keep working; unlike the vendored pstack
  skills ([ADR 0012](0012-adopt-selected-pstack-skills.md)) this one installs
  unchanged, so upstream fixes flow in for free and we own no copy.
- Rule 11 and its banned-word list will drift from upstream `SKILL.md` over time —
  the output style is a hand-curated subset, not a mirror. Accepted: the two
  serve different jobs (default texture vs. explicit deep edit).
- Retiring either half is independent: drop the `THIRDPARTY_SKILLS` entry, or
  delete Rule 11.

## Supersedes

None. Complements [ADR 0009](0009-adhd-output-style-native.md) (adds a rule to
that style) and follows the npx-skill install pattern from
[ADR 0007](0007-move-impeccable-plugin-to-skill.md).
