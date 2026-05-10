---
name: cloudagent
description: >
  How to use the `cloudagent` CLI and work correctly in Cloud Agent containerised
  workspaces. Use this skill whenever you are in a Cloud Agent environment
  (detectable by the `cloudagent` CLI or CLOUDAGENT_API_URL env var). Covers
  presenting files and URLs to the user, exposing web servers with TLS, sending
  notifications, workspace info, kanban ticket management, and configuring tools
  like the superpowers visual companion. Use before opening any file or URL for
  the user, before starting any web server the user should access, before sending
  notifications, before working with kanban tickets, and before setting up the
  visual companion.
---

# Cloud Agent Workspace Guide

Cloud Agent workspaces are containerised dev environments where the user interacts
through a browser-based platform. Direct filesystem paths and localhost URLs are
not accessible to the user — everything must go through the platform's relay via
the `cloudagent` CLI.

The CLI is pre-configured via environment variables — no auth flags needed. All
commands support `--json` for machine-readable output.

## Presenting content to the user

The user cannot open files or URLs directly from the container. Use the
`cloudagent` CLI any time you would normally say "open this file" or "visit this
URL". The user sees a toast notification in their browser and can click to view it.

```bash
# Files — must exist on the filesystem
cloudagent open-file /path/to/file.md
cloudagent open-file ./report.html --title "Test Report"

# URLs — must use http or https scheme
cloudagent open-url https://example.com
cloudagent open-url https://example.com --title "API Docs"
```

## Sending notifications

Alert the user about long-running tasks completing or important events.

```bash
cloudagent notify --title "Build complete" --body "All tests passed"
```

Both `--title` and `--body` are required.

## Exposing web servers

When you start a web server the user needs to access, always use
`cloudagent http-forwards` — never `cloudagent ports` for browser-facing services.

HTTP forwards provide TLS-terminated HTTPS URLs that work reliably in the browser.
Port forwards expose raw TCP which lacks TLS and produces unreliable browser URLs.

```bash
# Start server (must bind to 0.0.0.0, not 127.0.0.1)
nohup python3 -m http.server 8080 --bind 0.0.0.0 > /dev/null 2>&1 &

# Create an HTTP forward
cloudagent http-forwards add --container 8080 --hostname my-app --json
# → response includes "url" field with the public HTTPS URL

# Send the URL to the user
cloudagent open-url <url-from-response> --title "My App"

# List active forwards
cloudagent http-forwards list --json

# Clean up when done
cloudagent http-forwards remove <forward-id>
```

The `--hostname` flag sets the subdomain. The `--private` flag requires
authentication to access the URL.

### Port forwards (non-HTTP only)

Only use for non-HTTP protocols like databases or custom TCP services.

```bash
cloudagent ports add --container 5432 --json   # host port assigned by server
cloudagent ports list --json
cloudagent ports remove <forward-id>
```

## Superpowers visual companion

The visual companion needs three Cloud Agent-specific adaptations. All three are
required or the companion will break.

### 1. Bind to 0.0.0.0

The start script defaults to `127.0.0.1`, which the HTTP forward proxy cannot
reach:

```bash
start-server.sh --project-dir <project-dir> --host 0.0.0.0 --url-host localhost
```

### 2. Create an HTTP forward

After the server starts and reports its port:

```bash
cloudagent http-forwards add --container <port> --hostname visual-companion --json
```

Capture the `url` field from the JSON response.

### 3. Patch ws:// to wss:// in helper.js

The HTTP forward terminates TLS, so the browser sees an HTTPS page. Browsers
block mixed-content `ws://` connections from HTTPS pages, which means the
companion's live-reload and click-tracking WebSocket will silently fail.

Find `helper.js` in the superpowers brainstorming scripts directory and replace:

```
# Line 2 — change this:
const WS_URL = 'ws://' + window.location.host;

# To this:
const WS_URL = 'wss://' + window.location.host;
```

This is the single most important step — without it the companion appears to load
but all interactivity (click selections, live reloads) is silently broken.

### 4. Send the URL to the user

```bash
cloudagent open-url <https-url> --title "Visual Companion"
```

## Workspace info

```bash
cloudagent workspace info --json         # name, slug, status
cloudagent workspace network --json      # network configuration
cloudagent workspace permissions --json  # allowed API operations
```

## Kanban ticket system

The CLI includes a full kanban system for task tracking. Read
`references/kanban.md` for the complete reference when you need to work with
boards, tickets, comments, attachments, labels, statuses, types, or custom fields.

### Quick reference

```bash
cloudagent boards list --json
cloudagent tickets list --board <board-id> --json
cloudagent tickets create --board <board-id> --title "Fix login bug" --json
cloudagent tickets update <ticket-id> --status <status-slug> --json
cloudagent tickets comments add <ticket-id> --body "Fixed in commit abc123"
```
