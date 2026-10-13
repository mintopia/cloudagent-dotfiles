---
name: grill-me-ui
description: Run a grilling session in the browser instead of the terminal. Each Round of questions appears on a project page with recommended answers; the user submits there and the agent continues automatically. Use when the user says /grill-me-ui or wants to be grilled in the browser.
disable-model-invocation: true
---

# Grill me (browser UI)

1. Invoke the Skill tool with `grilling` and follow it for what to ask, in what order, and the recommended answers.
2. Invoke the Skill tool with `grill-ui` and follow it for how every Round reaches the user and how their Submission comes back. Wherever `grilling` says to ask the user in the terminal, post a Round instead.

Do not copy or paraphrase `grilling`; load it fresh each run.
