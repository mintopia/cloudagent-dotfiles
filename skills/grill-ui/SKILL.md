---
name: grill-ui
description: Protocol for presenting grill Rounds in the browser and collecting Submissions. Only loaded by entry skills such as grill-me-ui and grill-with-docs-ui; do not invoke it directly.
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

`options`, `recommendation` and `visual` are optional. Question ids are unique within a Round.

`notes`, `body` and `recommendation` render as Markdown, including fenced code, ` ```diff ` blocks and ` ```mermaid ` diagrams, and file or call trees as plain fenced blocks. `visual` is an HTML fragment shown under the body inside a mockup frame; use the mockup classes from `visual-companion` (`.split`, `.pros-cons`, `.placeholder`, `.mock-nav`, `.mock-button` and so on). Use it only for UI or layout choices. Notes stay visible alongside the Round after it is answered.

The server sends a `cloudagent notify` for each new Round (number and question count) by itself. Print only one terminal line per Round: the round number, question count and URL. Do not repeat the questions in the terminal.

## Wait for the Submission

Right after posting, start a background wait so you get a turn when the user submits (Monitor with an until-loop, no terminal input needed):

```bash
until [ -f "<session_dir>/answers-NNN.json" ]; do sleep 2; done; cat "<session_dir>/answers-NNN.json"
```

**At the start of every turn**, before anything else, list `answers-*.json` and process any Submission you have not yet read, even if the background wait died or never started. Any terminal message from the user is a reason to do this check.

### Answering in the terminal

If the user answers the open Round in the terminal instead, map their reply to every question of that Round and write `answers-NNN.json` yourself (file-creation tool, only if it does not exist), in the shape below with `"source": "terminal"` and a `submitted_at` timestamp. The page then shows the Round as answered in the terminal and the status moves to "Answered. Agent working". Use `text` for free-form replies, `accept` for "go with your recommendations", and `skip` for anything not addressed.

On the page, **Accept all recommendations** fills every untouched question that has a `recommendation`, so give each question one where you can. Submit stays disabled until every question is answered or skipped. A side panel (a top bar on phones) shows the Round number, answered / skipped / remaining counts, links to unanswered questions, and a log of decisions settled in earlier Rounds. Earlier Rounds appear collapsed with their answers.

The page shows the status live (waiting for you, agent working, Round ready) by polling `/state` every 2 seconds, and shows "Connection lost. Retrying…" if the server is unreachable.

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

## Docs changed

Only `grill-with-docs-ui` uses this. When it edits glossary or ADR files it writes their repo-relative paths as a JSON array to `docs-changed.json` in `session_dir`. The summary panel lists them and hides the section when the array is empty or the file is absent, so it never shows in `grill-me-ui`.

## Shared understanding and end actions

When the frontier is empty, post a final Round with `"type": "shared-understanding"` instead of questions. `summary` (Markdown) restates every decision once; `notes` is optional.

```json
{"round": 7, "type": "shared-understanding", "title": "Wrap up", "summary": "- Store: files\n- ..."}
```

The page shows the summary with four actions: To spec, To tickets, Keep grilling, End session. The Submission has no answers; it carries the choice:

```json
{"round": 7, "answers": [], "action": "to-spec", "note": "", "comment": "", "source": "browser", "submitted_at": "..."}
```

`action` is `to-spec`, `to-tickets`, `keep-grilling` or `end`. `keep-grilling` always has a non-empty `note`: dig into it in the next Round, then post a new Shared understanding Round when the frontier is empty again. If the user answers in the terminal, write `answers-NNN.json` with `action` (and `note`) yourself.

- `to-spec`: invoke the Skill tool with `to-spec` at runtime (never copy it). Post its seam check as a normal `questions` Round and wait for the Submission as usual. Once the spec is published, write `done.json` with `{"spec_url": "<url>", "title": "<spec title>"}` into `session_dir`; the page then shows a Done page linking to it.
- `to-tickets`: invoke the Skill tool with `to-tickets`.
- `end`: go to Finish.

## Finish

When the frontier is empty, write `finished.json` after any hand-off completes (e.g. `{"finished_at": "<ISO time>"}`) into `session_dir` so the session is no longer offered for resume, say so in the terminal and summarise the decisions. Stop the server only if asked: `~/.claude/skills/visual-companion/scripts/stop-companion.sh <session_dir>`. The forward stays so the URL is stable.
