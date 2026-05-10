---
name: adr
description: >
  Enforce and create Architecture Decision Records (ADRs). Use this skill before
  proposing any change to architecture, tooling, dependencies, code style,
  testing strategy, repo structure, CI/CD, or development workflow. Also use when
  the user asks to create, review, list, or supersede an ADR, or when a
  conversation results in a technical decision that should be recorded. If you are
  about to recommend switching a library, changing a pattern, adding a tool, or
  restructuring code — check ADRs first. Every architectural choice deserves a
  paper trail.
---

# Architecture Decision Records

ADRs capture important technical decisions so they aren't re-litigated and so
new contributors understand why things are the way they are. This skill has two
jobs: **enforce** existing ADRs and **create** new ones.

## When invoked as /adr

When the user runs `/adr` directly, enter interactive ADR creation mode:

1. Locate the ADR directory (or note that one will be created).
2. List any existing ADRs so the user can see what's already recorded.
3. If the user provided arguments (e.g. `/adr use redis for session storage`),
   use that as the decision title and draft the ADR immediately.
4. If no arguments, ask the user what decision they want to record.
5. Draft the full ADR using the template below, then present it for review
   before writing the file.
6. Check existing ADRs for conflicts or supersession — if the new decision
   replaces an older one, handle the supersession workflow automatically.

## Finding the ADR directory

Search the project root for an existing ADR directory in this order:

1. `docs/decisions/`
2. `decisions/`
3. `doc/adr/`
4. `adr/`
5. `docs/adr/`

Use the first match. If none exists and you need to create an ADR, use
`docs/decisions/` and create it.

## Before proposing changes

Whenever you are about to propose a change to architecture, tooling,
dependencies, code style, testing strategy, repo structure, CI/CD pipelines, or
development workflow:

1. Locate the ADR directory.
2. Read all ADR files in it (they are short — typically under 30 lines each).
3. Check whether any **accepted** ADR is relevant to the change you are about to
   propose.
4. If a relevant accepted ADR exists and your proposal **conflicts** with it:
   - **Stop.** Do not proceed with the change.
   - Explain the conflict clearly: quote the ADR title, its decision, and why
     your proposal contradicts it.
   - Tell the user their options: they can explicitly ask you to override the ADR
     for this task, or they can ask you to create a new ADR that supersedes the
     old one.
   - Do not continue until the user has chosen one of those paths.
5. If a relevant accepted ADR exists and your proposal **aligns** with it,
   mention this briefly so the user knows the decision has prior backing.
6. If no ADR directory exists, note this and proceed normally.

The point of the hard block is that ADRs represent deliberate team decisions.
Silently contradicting them undermines the whole system — even if the new
approach seems better, the right move is to make the override explicit.

## Creating an ADR

Create a new ADR when:

- The user explicitly asks for one
- A conversation produces a significant technical decision that should be
  recorded (offer to create one — don't create silently)
- The user wants to supersede an existing ADR

### Numbering

ADRs use sequential four-digit numbers. To determine the next number:

1. List existing files in the ADR directory
2. Find the highest existing number
3. Increment by one

If the directory is empty or new, start at `0001`.

### Filename format

```
NNNN-kebab-case-title.md
```

Examples: `0001-use-postgres.md`, `0002-adopt-rest-api.md`

### ADR template

```markdown
# Decision: [Title]

Status: [proposed | accepted | deprecated | superseded]
Date: [YYYY-MM-DD]

## Context

[Why this decision is needed. What problem or question prompted it. Include
relevant constraints, requirements, and alternatives that were considered.]

## Decision

[What was decided. Be specific enough that someone reading this in six months
can understand exactly what to do.]

## Consequences

[Trade-offs, implications, and follow-up work. What becomes easier, what becomes
harder, what risks are accepted.]

## Supersedes

[Reference to the ADR this replaces, e.g. "0003-use-redis.md", or "None"]
```

### When superseding

When creating an ADR that supersedes an older one:

1. Create the new ADR with the `Supersedes` field pointing to the old one.
2. Update the old ADR's status from `accepted` to `superseded` and add a line:
   `Superseded by: NNNN-new-decision.md`

## Listing and reviewing ADRs

When the user asks to see existing ADRs, present them as a table:

| # | Title | Status | Date |
|---|-------|--------|------|

Include all ADRs, marking superseded and deprecated ones so the user can see the
full history.
