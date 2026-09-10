---
name: comment-check
description: "Read-only comment-discipline check. Dispatches a hostile comment critic over a scope and reports its PASS/FAIL verdict. Use for /comment-check, a critic quality gate, or verifying a diff for narration, workaround sermons, and unsafe lint/TS suppressions. Never edits code."
---

# Comment check

The read-only sibling of `no-comments`. That skill deletes and fixes; this one
only checks. Dispatch a comment critic, then report its verdict verbatim. Touch
nothing — no deletions, no fixes, no edits. The caller (a critic or a human)
decides what to do with the findings.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base
branch (default `main`), including the working tree.

## Steps

1. **Dispatch the check.** Launch one `general-purpose` subagent via the
   Agent/Task tool. Its entire prompt is the critic persona in
   `references/comment-critic.md` plus the scope (the files or diff). Inherit the
   parent model tier; do not hardcode a model ID. The persona is read-only — do
   not restate its rules; the persona file is authoritative.

2. **Report the verdict.** Surface the subagent's report unchanged: the
   violation list, the skips, and its final `COMMENT-CHECK: PASS` or
   `COMMENT-CHECK: FAIL (<n>)` line. Do not edit, delete, or fix anything. Do
   not re-argue its calls. If the run produced no verdict line, say so and treat
   the check as errored, not passed.
