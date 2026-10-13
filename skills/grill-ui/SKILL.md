---
name: grill-ui
description: Protocol for presenting grill Rounds in the browser and collecting Submissions. Only loaded by entry skills such as grill-me-ui; do not invoke it directly.
---

# Grill UI protocol

Presents each Round on a web page served by `visual-companion`'s grill mode. Terms (Grill session, Round, Submission, Agent notes) are defined in `GLOSSARY.md`.

## Resume or start

First check for an unfinished Grill session (does not start a server):

```bash
~/.claude/skills/visual-companion/scripts/start-server.sh --grill --grill-status --project-dir "$PWD"
```

If `unfinished` is not null, ask the user whether to resume it (`rounds` and `answered` say how far it got) or start fresh. Fresh means adding `--new` to the launch below. To resume, read every `round-NNN.json`, `answers-NNN.json` and `decisions.md` in that directory to rebuild context, then continue from the open frontier: an unanswered Round is still open (re-wait for its Submission), otherwise post the next Round.

## Start or reuse the server

```bash
~/.claude/skills/visual-companion/scripts/launch-persistent.sh --grill --project-dir "$PWD" --open
```

The launch is synchronous and prints JSON. Keep `url`, `session_dir`, `decision_log`, `round_pattern` and `answers_pattern`.

- Re-running reuses the project's port, key, forward and newest unfinished session directory, so an open tab keeps working.
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

`options` and `recommendation` are optional. Question ids are unique within a Round.

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

## Decision log

After folding in each Submission, append the decisions it settled to `decision_log` (`decisions.md`) as Markdown bullets. The page shows it, and it is what you reload on resume.

## Finish

When the frontier is empty, write `finished.json` (e.g. `{"finished_at": "<ISO time>"}`) into `session_dir` so the session is no longer offered for resume, say so in the terminal and summarise the decisions. Stop the server only if asked: `~/.claude/skills/visual-companion/scripts/stop-companion.sh <session_dir>`. The forward stays so the URL is stable.
