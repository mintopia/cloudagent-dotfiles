---
name: grill-ui
description: Protocol for presenting grill Rounds in the browser and collecting Submissions. Only loaded by entry skills such as grill-me-ui; do not invoke it directly.
---

# Grill UI protocol

Presents each Round on a web page served by `visual-companion`'s grill mode. Terms (Grill session, Round, Submission, Agent notes) are defined in `GLOSSARY.md`.

## Start or reuse the server

```bash
~/.claude/skills/visual-companion/scripts/launch-persistent.sh --grill --project-dir "$PWD" --open
```

The launch is synchronous and prints JSON. Keep `url`, `session_dir`, `round_pattern` and `answers_pattern`.

- Re-running reuses the project's port, key, forward and newest session directory, so an open tab keeps working.
- Give the user the full `url` including `?key=`. Requests without the key are rejected.
- In a Cloud Agent workspace the URL is a public HTTPS forward; also run `cloudagent open-url "<url>" --title "Grill"`. Elsewhere it is plain `localhost`.
- Never launch with `run_in_background`; the script keeps the server alive in tmux.

## Post a Round

Write `round-NNN.json` (zero-padded, next number) into `session_dir` with the file-creation tool. Never reuse a number.

```json
{
  "round": 1,
  "type": "questions",
  "title": "Scope",
  "notes": "Agent notes as Markdown",
  "questions": [
    {
      "id": "q1",
      "title": "Which store?",
      "body": "Markdown body",
      "options": [{"id": "a", "label": "SQLite"}, {"id": "b", "label": "Files"}],
      "recommendation": "Files, because ..."
    }
  ]
}
```

`options`, `recommendation` and `visual` are optional. Question ids are unique within a Round.

`notes`, `body` and `recommendation` render as Markdown, including fenced code, ` ```diff ` blocks and ` ```mermaid ` diagrams, and file or call trees as plain fenced blocks. `visual` is an HTML fragment shown under the body inside a mockup frame; use the mockup classes from `visual-companion` (`.split`, `.pros-cons`, `.placeholder`, `.mock-nav`, `.mock-button` and so on). Use it only for UI or layout choices. Notes stay visible alongside the Round after it is answered.

Then tell the user in one terminal line: the round number, question count and URL.

## Wait for the Submission

Right after posting, start a background wait so you get a turn when the user submits (Monitor with an until-loop, no terminal input needed):

```bash
until [ -f "<session_dir>/answers-NNN.json" ]; do sleep 2; done; cat "<session_dir>/answers-NNN.json"
```

At the start of any turn also check for an unread `answers-NNN.json`. If the user types in the terminal instead, treat that as the answer.

## Read the Submission

```json
{
  "round": 1,
  "answers": [
    {"id": "q1", "kind": "option", "option": "a", "text": "optional note"},
    {"id": "q2", "kind": "accept"},
    {"id": "q3", "kind": "skip"},
    {"id": "q4", "kind": "text", "text": "free text only"}
  ],
  "comment": "round-level comment",
  "submitted_at": "2026-10-13T12:00:00.000Z"
}
```

`accept` means the user took your recommendation. `skip` means revisit it in a later Round. Fold the answers into the grilling, then post the next Round.

## Finish

When the frontier is empty, say so in the terminal and summarise the decisions. Stop the server only if asked: `~/.claude/skills/visual-companion/scripts/stop-companion.sh <session_dir>`. The forward stays so the URL is stable.
