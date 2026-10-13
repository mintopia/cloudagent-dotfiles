---
name: grill-with-docs-ui
description: Run a grill-with-docs session in the browser instead of the terminal. Like grill-me-ui, but the interview also sharpens the glossary and ADRs, and the page lists the doc files changed. Use when the user says /grill-with-docs-ui or wants to be grilled against the project's domain model in the browser.
disable-model-invocation: true
---

# Grill with docs (browser UI)

1. Invoke the Skill tool with `grilling` and follow it for what to ask, in what order, and the recommended answers.
2. Invoke the Skill tool with `domain-modeling` and follow it for challenging the plan against the project's domain model and for updating the glossary and ADRs as decisions settle. Use the glossary and ADR locations configured in `docs/agents/domain.md` (default `GLOSSARY.md`, `GLOSSARY-MAP.md` and `docs/decisions/`), not hardcoded paths.
3. Invoke the Skill tool with `grill-ui` and follow it for how every Round reaches the user and how their Submission comes back. Wherever `grilling` says to ask the user in the terminal, post a Round instead.

Each time you create or edit a glossary or ADR file, add its repo-relative path to `docs-changed.json` in the session directory (a JSON array of strings, no duplicates; write it with the file-creation tool). The page lists these in the summary panel and hides the section while the array is empty or the file is absent. Touch only glossary and ADR files there.

Do not copy or paraphrase `grilling` or `domain-modeling`; load them fresh each run.
