---
name: visual-companion
description: Browser-based visual companion for showing mockups, wireframes, architecture diagrams, and side-by-side design options in the user's browser and capturing their clicks. Use in any design, frontend, or architecture discussion whenever a question is better SEEN than read — UI layouts, component designs, visual A/B comparisons, design polish, spatial/flow/state relationships. NOT for text or tabular questions (requirements, conceptual A/B/C choices, tradeoff lists, API/data-model decisions) — those stay in the terminal.
---

# Visual Companion

A local web server that shows HTML mockups, diagrams, and options in the user's
browser and records their clicks. You write HTML to a watched directory; the
browser shows the newest screen; the user clicks to select; you read their
selections next turn.

Vendored from the superpowers `brainstorming` skill (MIT, obra/superpowers) and
made standalone + Cloud Agent-aware. It is **not** tied to a brainstorming flow —
reach for it in any conversation where seeing beats reading.

## When to Use

Decide per-question, not per-session. The test: **would the user understand this
better by seeing it than reading it?**

**Use the browser** when the content itself is visual:

- **UI mockups** — wireframes, layouts, navigation structures, component designs
- **Architecture diagrams** — system components, data flow, relationship maps
- **Side-by-side visual comparisons** — two layouts, two colour schemes, two directions
- **Design polish** — look and feel, spacing, visual hierarchy
- **Spatial relationships** — state machines, flowcharts, entity relationships as diagrams

**Use the terminal** when the content is text or tabular:

- **Requirements / scope** — "what does X mean?", "which features are in scope?"
- **Conceptual A/B/C choices** — picking between approaches described in words
- **Tradeoff lists** — pros/cons, comparison tables
- **Technical decisions** — API design, data modelling, architectural selection
- **Clarifying questions** — anything where the answer is words, not a visual preference

A question *about* a UI topic is not automatically a visual question. "What kind
of wizard do you want?" is conceptual — terminal. "Which of these wizard layouts
feels right?" is visual — browser.

## Starting a Session

Launch **after** the user agrees to the visual companion. Always use
`start-companion.sh` — it is the Cloud Agent-aware wrapper (see below); off Cloud
Agent it transparently runs the plain localhost server.

```bash
# --project-dir persists mockups and enables same-port restart.
# --open auto-opens the browser on the first screen.
scripts/start-companion.sh --project-dir /path/to/project --open

# Returns: {"type":"server-started","port":52341,
#           "url":"https://visual-companion.<workspace>.cloudagent.../?key=ab12…",
#           "screen_dir":".../content","state_dir":".../state", ...}
```

Save `screen_dir` and `state_dir` from the response, and share the full `url`.

- **Give the user the complete `url`, including `?key=…`.** The server rejects any
  request without the key — never strip the query string or hand out a bare host.
- **Pass the project root as `--project-dir`** so mockups persist under
  `.superpowers/brainstorm/` and survive restarts. Without it files go to `/tmp`
  and get cleaned up. Remind the user to add `.superpowers/` to `.gitignore` if it
  isn't already.
- **If you background the launch,** read the URL/port back from
  `$STATE_DIR/server-info` on your next turn.

### Cloud Agent behaviour

In a Cloud Agent workspace (`CLOUDAGENT_API_URL` + the `cloudagent` CLI),
`start-companion.sh` does three things the plain server can't:

1. Binds `0.0.0.0` so the forward proxy can reach it.
2. Creates (or reuses) a TLS-terminated `http-forward` on the `visual-companion`
   hostname and rewrites the returned `url` to the public `https://` address.
3. Relies on the patched `helper.js`, which upgrades the WebSocket to `wss://`
   automatically on https pages — so live-reload and click tracking keep working
   behind the forward instead of silently dying on mixed-content.

Send the `https://` URL to the user with `cloudagent open-url "$URL" --title "Visual Companion"`.
Restarts reuse the same port, key, and forward, so an already-open tab reconnects
on its own.

## The Loop

1. **Confirm the server is alive, then write HTML** to a new file in `screen_dir`:
   - Alive = `$STATE_DIR/server-info` exists and `$STATE_DIR/server-stopped` does
     not. If it shut down, relaunch with `start-companion.sh` and the **same
     `--project-dir`** — same port/URL, the open tab reconnects itself. (Auto-exits
     after 4h idle; tune with `--idle-timeout-minutes`.)
   - Semantic filenames: `layout.html`, `visual-style.html`. **Never reuse a
     filename** — each screen is a fresh file. Server serves the newest.
   - Use your file-creation tool — **never cat/heredoc** (dumps noise into terminal).

2. **Tell the user what to expect and end your turn:**
   - Remind them of the URL (every step, not just the first).
   - One-line summary of what's on screen ("Showing 3 homepage layouts").
   - "Take a look and let me know what you think. Click to select if you'd like."

3. **Next turn** — after the user responds in the terminal:
   - Read `$STATE_DIR/events` if it exists (JSON lines of their clicks/selections).
   - Merge with their terminal text. Terminal is primary; events add structure.

4. **Iterate or advance** — feedback on the current screen → new file
   (`layout-v2.html`). Only move on once the current step is validated.

5. **Unload when returning to terminal** — push a waiting screen so the user isn't
   staring at a resolved choice while the conversation has moved on:

   ```html
   <!-- filename: waiting.html -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

6. Repeat until done.

## Writing Content Fragments

Write just the content that goes inside the page — the server wraps it in the
frame template (header, theme CSS, connection status, interactive infrastructure).
Only write a full `<!DOCTYPE>`/`<html>` document when you need complete control;
the server then serves it as-is (just injecting the helper script).

```html
<h2>Which layout works better?</h2>
<p class="subtitle">Consider readability and visual hierarchy</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>Single Column</h3><p>Clean, focused reading</p></div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content"><h3>Two Column</h3><p>Sidebar nav with main content</p></div>
  </div>
</div>
```

No `<html>`, CSS, or `<script>` needed — the server provides all of it.

## CSS Classes Available

The frame template (`scripts/frame-template.html`) provides:

- **Options (A/B/C):** `.options` > `.option[data-choice][onclick="toggleSelect(this)"]`
  > `.letter` + `.content`. Add `data-multiselect` to `.options` for multi-select.
- **Cards (visual designs):** `.cards` > `.card` > `.card-image` + `.card-body`.
- **Mockup container:** `.mockup` > `.mockup-header` + `.mockup-body`.
- **Split view (side-by-side):** `.split` > two `.mockup`.
- **Pros/Cons:** `.pros-cons` > `.pros` + `.cons`.
- **Wireframe blocks:** `.mock-nav`, `.mock-sidebar`, `.mock-content`,
  `.mock-button`, `.mock-input`, `.placeholder`.
- **Typography:** `h2` page title, `h3` section heading, `.subtitle`, `.section`,
  `.label` (small uppercase).

## Browser Events Format

Clicks are recorded to `$STATE_DIR/events` (one JSON object per line), cleared
automatically when you push a new screen:

```jsonl
{"type":"click","choice":"a","text":"Option A - Simple Layout","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Complex Grid","timestamp":1706000108}
```

The last `choice` is typically the final selection; the full stream can reveal
hesitation worth asking about. No `events` file → the user didn't interact; use
their terminal text only.

## Design Tips

- **Scale fidelity to the question** — wireframes for layout, polish for polish.
- **Explain the question on each page** — "Which feels more professional?" not "Pick one".
- **2–4 options max** per screen.
- **Use real content when it matters** (e.g. actual images for a portfolio).
- **Keep mockups simple** — layout and structure over pixel-perfection.

## Cleaning Up

```bash
scripts/stop-companion.sh <session_dir>
```

Removes the http-forward (Cloud Agent) and stops the server. Mockups under
`.superpowers/brainstorm/` persist for later review; `/tmp` sessions are deleted.

## Reference

- `scripts/start-companion.sh` / `scripts/stop-companion.sh` — Cloud Agent-aware wrappers
- `scripts/start-server.sh` / `scripts/stop-server.sh` — upstream server (unmodified)
- `scripts/server.cjs` — the watching web server (unmodified)
- `scripts/frame-template.html` — frame CSS reference
- `scripts/helper.js` — client script (patched: `ws://`→`wss://` on https pages)
