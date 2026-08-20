---
name: no-comments
description: "Spawn a Comment Sicko reviewer, fix accepted findings, and offer encodings for claimed constraints. Use for /no-comments, \"kill the comments\", \"delete these comments\", \"comment audit\", or an adversarial pass over narration/workaround comments and lint suppressions."
disable-model-invocation: true
---

# No comments

Spawn the Comment Sicko reviewer, act on its accepted findings, and delete
comments that survive on scent rather than proof. Authoring agents defend their
comments; defer to the reviewer's fresh, hostile perspective.

This is the heavy, adversarial version of comment discipline. The always-on
ponytail mode already prunes unnecessary comments as you write — reach for this
skill when you want a dedicated, skeptical sweep over an existing diff.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base
branch (default `main`), including the working tree.

## Steps

1. **Spawn the reviewer.** Launch one `general-purpose` subagent via the
   Agent/Task tool. Its entire prompt is the persona in
   `references/comment-sicko.md` plus the scope (the files or diff). Inherit the
   parent model tier; do not hardcode a model ID. Do not restate its rules — the
   persona file is authoritative.

2. **Judge its report.** Inspect the report and diff. Reject: application-code
   edits, scope escapes, exception-protected deletions, misstated `MUST KILL`
   reasons, and flags that treat kept intentional code as guilty. Reshape flags
   on our-code surprises stay actionable. Do not restore those comments. A keep
   survives only with proof it is about something we cannot change. Audit missed
   scoped lint and TypeScript suppressions — correctness or safety suppressions
   stay actionable `MUST KILL`s. Restore deletions only with exact exceptions and
   scoped proof. Before accepting thin `IMPORTANT` or `do not remove` kills or
   keeps, run `/why` on their symbol. If a kill is ambiguous, do not restore. If
   a keep is refuted or still ambiguous, delete it. Revert and rerun one rejected
   report with the failure named. Reject a second, report it open, and fail.

3. **Fix trivial accepted flags directly** — delete a dead path, drop a
   parameter, use the real API. If a fix needs a design shape, sketch it (or use
   `/codebase-design`) and stop at the sketch; step 4 implements.

4. **Implement the smallest root-cause fix in scope.** Remove every named
   workaround. If the root cause is out of scope, land the smallest in-scope fix
   and report the rest open. The root-cause and first-principles reflexes in
   `AGENTS.md` guide intent only: fix real causes, redesign as if the
   requirements always existed, never bolt on symptom guards. Neither authorizes
   widening the fence nor fixing instances outside it.

5. **Handle constraint comments** — `do not remove`, `do not change wording`,
   `talk to X before changing`. Leave keeps about things we cannot change. For
   the rest, offer the cheapest in-scope type, runtime, test, or CI lint that
   encodes the constraint, then wait for interactive approval (unattended or eval
   runs require caller pre-approval). If approved, encode then delete. Otherwise
   delete, report the constraint open, and sketch the out-of-scope work.

6. **Report** the deletion count, restored comments, reruns, any design sketch,
   fixes, encoding offers, encodings applied, unenforced constraints, and other
   open work.
