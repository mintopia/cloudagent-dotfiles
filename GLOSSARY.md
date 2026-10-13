# Cloud Agent Dotfiles

Setup of skills, plugins, hooks and settings for Cloud Agent workspaces, plus the local skills this repo authors.

## Grill UI

**Grill session**:
One run of a grilling interview, from first round to an empty frontier, presented in the browser.
A session is unfinished until it has a `finished.json`; the newest unfinished one is offered for resume.
_Avoid_: Grill, interview session

**Round**:
One batch of frontier questions with their recommended answers and the agent's notes, presented together.
_Avoid_: Step, page, batch

**Submission**:
The user's answers to one round, sent back as a whole.
_Avoid_: Response, reply

**Decision log**:
The running record of decisions a grill session has settled, kept beside its rounds and reloaded on resume.
_Avoid_: History, transcript

**Agent notes**:
Agent output attached to a round that isn't a question: findings, sub-agent reports, glossary and ADR changes.
_Avoid_: Commentary, log

**Docs changed**:
The glossary and ADR files a grill-with-docs session created or edited, listed in the summary panel and empty (hidden) otherwise.
_Avoid_: Changelog

**Shared understanding**:
The final Round of a grill session, posted once the frontier is empty. It summarises every decision and offers the end actions: To spec, To tickets, Keep grilling, End session.
_Avoid_: Summary page, wrap-up

**Done page**:
The page shown after the spec or tickets are published (`done.json`), linking to the spec or to every published issue.

**Tickets Round**:
A Round of type `tickets` showing a proposed `to-tickets` breakdown: a card per ticket, a dependency graph, per-ticket approve / merge / split / note controls and a granularity question. Revisions are new Rounds until approved.
_Avoid_: Breakdown page
