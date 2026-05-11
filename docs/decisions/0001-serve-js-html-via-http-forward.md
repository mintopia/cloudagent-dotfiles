# Decision: Serve interactive HTML via web server and HTTP forward

Status: accepted
Date: 2026-05-11

## Context

`cloudagent open-file` renders files in the browser but does not execute
JavaScript. HTML files with JS (eval viewers, dashboards, interactive reports)
appear to load but are non-functional. This was discovered when attempting to
open the skill-creator eval viewer via `open-file`.

## Decision

When presenting an HTML file that contains JavaScript to the user in a Cloud
Agent environment:

1. Start a local web server (e.g. `python3 -m http.server <port> --bind 0.0.0.0`)
2. Create an HTTP forward (`cloudagent http-forwards add --container <port> --hostname <name> --json`)
3. Send the resulting HTTPS URL to the user via `cloudagent open-url`

Reserve `cloudagent open-file` for static content only: markdown, plain HTML
without JS, images, and other non-executable file types.

## Consequences

Slightly more setup than a single `open-file` call, but interactive content
actually works. The HTTP forward and server process need to be cleaned up when
no longer needed. This applies to any tool that generates interactive HTML
(eval viewers, Playwright reports, coverage dashboards, etc.).

## Supersedes

None
