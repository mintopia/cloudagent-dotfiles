# Decision: Install the `show-me` skill from humanlayer/skills

Status: accepted
Date: 2026-10-12

## Context

Explanations in the terminal tend to be prose-heavy when a call tree, file
tree, or sequence diagram would land faster. `visual-companion` covers
browser mockups and click capture, but there was no lightweight "show me the
shape of this" skill for the current conversation topic.

[humanlayer/skills](https://github.com/humanlayer/skills) (MIT) ships
`show-me`: a user-invoked skill (`disable-model-invocation: true`) that picks
the smallest visual — pseudocode, call/component/file tree, Mermaid, diff, or
a focused HTML artifact — and keeps prose brief.

## Decision

Install only `show-me` via
`npx skills add humanlayer/skills --skill show-me -g -y --copy` in its own
block in `install.sh`, after the third-party loop. The `THIRDPARTY_SKILLS`
loop pulls whole repos, and the rest of humanlayer/skills is not wanted.

## Consequences

- `/show-me` is available; it never auto-triggers, so it does not compete with
  `visual-companion` or `philosopher`.
- Tracks upstream unchanged — no vendored copy to maintain.
- Retiring it is removing the install block and README entry.
