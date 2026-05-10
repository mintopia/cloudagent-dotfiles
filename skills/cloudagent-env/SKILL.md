---
name: cloudagent-env
description: >
  Cloud Agent workspace conventions. Use this skill whenever you are working in a
  Cloud Agent environment (detectable by the presence of the `cloudagent` CLI or
  the CLOUDAGENT_API_URL environment variable). Governs how to present files and
  URLs to the user, how to expose web servers, and how to configure tools that
  need browser access. Use before opening any file or URL for the user, before
  starting any web server the user should access, and before setting up the
  superpowers visual companion.
---

# Cloud Agent Environment Conventions

Cloud Agent workspaces are containerised development environments where the user
interacts through a browser-based platform. Direct filesystem paths and
localhost URLs are not accessible to the user — everything must go through the
platform's relay.

## Presenting files and URLs to the user

The user cannot open files or URLs directly from the container. Always use the
`cloudagent` CLI to surface them:

- **Markdown files or documents** the user should review:
  ```bash
  cloudagent open-file /path/to/file.md
  cloudagent open-file ./report.html --title "Test Report"
  ```

- **URLs** the user should visit:
  ```bash
  cloudagent open-url https://example.com
  cloudagent open-url https://example.com --title "API Docs"
  ```

Do this any time you would normally say "open this file" or "visit this URL".
The user sees a toast notification in their browser and can click to view it.

## Exposing web servers

When you start a web server that the user needs to access (dev servers, review
tools, documentation viewers, dashboards), **always use `cloudagent http-forwards`
rather than `cloudagent ports`**. HTTP forwards provide TLS-terminated URLs that
work reliably in the browser.

```bash
# Start the server
nohup python3 -m http.server 8080 > /dev/null 2>&1 &

# Create an HTTP forward — NOT a port forward
cloudagent http-forwards add --container 8080 --hostname my-app --json
```

The response includes a `url` field with the public HTTPS URL. Use
`cloudagent open-url` to send it to the user.

Never use `cloudagent ports add` for browser-facing services — port forwards
expose raw TCP which lacks TLS and produces unreliable URLs. HTTP forwards are
the correct mechanism.

When the server is no longer needed, clean up:
```bash
cloudagent http-forwards remove <id>
```

## Superpowers visual companion

The visual companion needs three Cloud Agent-specific adaptations that it will
not figure out on its own. All three are required or the companion will break.

### 1. Bind to 0.0.0.0

The start script defaults to `127.0.0.1`, which the HTTP forward proxy cannot
reach. Pass `--host 0.0.0.0` so the proxy can connect:

```bash
start-server.sh --project-dir <project-dir> --host 0.0.0.0 --url-host localhost
```

### 2. Create an HTTP forward (not a port forward)

After the server starts and reports its port, create an HTTP forward:

```bash
cloudagent http-forwards add --container <port> --hostname visual-companion --json
```

Capture the `url` field from the JSON response — this is the HTTPS URL the user
will use.

### 3. Patch ws:// to wss:// in helper.js

The HTTP forward terminates TLS, so the browser sees an HTTPS page. Browsers
block mixed-content `ws://` connections from HTTPS pages, which means the
companion's live-reload and click-tracking WebSocket will silently fail.

The fix: find `helper.js` in the superpowers brainstorming scripts directory and
replace the hardcoded `ws://` protocol with `wss://`:

```
# The line to change (helper.js, line 2):
const WS_URL = 'ws://' + window.location.host;

# Change it to:
const WS_URL = 'wss://' + window.location.host;
```

This is the single most important step — without it the companion appears to
load but all interactivity (click selections, live reloads) is silently broken.

### 4. Send the URL to the user

```bash
cloudagent open-url <https-url-from-step-2> --title "Visual Companion"
```
