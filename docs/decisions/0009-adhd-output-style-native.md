# Decision: Install the "I Have ADHD" output style natively

Status: accepted
Date: 2026-08-08

## Context

The user maintains an output style, `i-have-adhd.md` (frontmatter
`name: I Have ADHD`, `keep-coding-instructions: true`), that shapes output to be
action-first: next step first, numbered steps, no preamble. They want it applied
by default.

An earlier draft, prompted by a report that classic standalone output styles
were deprecated in Claude Code 2.x, wrapped the style in a `SessionStart` hook
that injected its body as `additionalContext` (mirroring Anthropic's successor
output-style plugins). The user corrected this: the file is already an output
style and should be installed as one; a hook would be a redundant second copy of
the same content.

## Decision

Install `i-have-adhd.md` as a native Claude Code output style.

- Vendor it at `config/output-styles/i-have-adhd.md`.
- `install.sh` copies it to `~/.claude/output-styles/i-have-adhd.md`.
- `config/settings.json` sets `"outputStyle": "I Have ADHD"` (the frontmatter
  `name`), which the settings merge makes active.
- No hook and no `settings-hooks.jq` change for this feature.

## Consequences

The output style is applied through Claude Code's own mechanism, with a single
source of truth (the installed style file) and no duplicated content. The
`outputStyle` value is the frontmatter `name` (`"I Have ADHD"`) — confirmed as
how Claude Code keys output styles, not the filename slug.

## Supersedes

None
