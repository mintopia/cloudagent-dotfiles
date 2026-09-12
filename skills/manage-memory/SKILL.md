---
name: manage-memory
description: Browse, edit, and delete this project's Claude memories in a browser, then persist the changes.
disable-model-invocation: true
---

# Manage Memory

Serves the project's memory files as an editable web page from a fixed template,
then applies whatever the user changed. The page is deterministic — the server
renders it and captures the user's edits/deletions to a changeset; **you** do the
persisting on save. You do not write the HTML.

## The memory directory

Use the memory directory from your auto-memory system — the path named in your
system prompt under "auto memory". Do not hardcode it here; it is project-specific.
Call it `$MEMORY_DIR` below. If it is missing or holds no `*.md` files besides
`MEMORY.md`, tell the user there are no memories to manage and stop.

## Steps

1. **Launch the server** and capture its JSON output (`url`, `state_dir`, ...):

   ```bash
   scripts/start.sh --memory-dir "$MEMORY_DIR"
   ```

   Save `state_dir` — you read the changeset back from it. On Cloud Agent the
   `url` is a private HTTPS forward; hand it over with
   `cloudagent open-url "$URL" --title "Manage Memory"`.

2. **Give the user the `url`** and tell them: browse the memories, edit the
   description or content, tick **Delete** on any to remove, click **Save
   changes**, then say when they're done. **End your turn** — the user edits at
   their own pace.

3. **On return, read the changeset.** `$STATE_DIR/saved` exists only after a save;
   if it's absent, the user hasn't saved yet — say so and wait. When present, read
   `$STATE_DIR/changeset.json` (schema below).

4. **Apply every entry**, exhaustively:
   - `delete: true` → remove that memory file, and later drop its line from the index.
   - otherwise → rewrite the file with the entry's `body`, and update its
     `description:` line if it changed. **Preserve the frontmatter** (`name`,
     `metadata.type`, and its shape). Skip files whose `body` and `description`
     are unchanged.
   - Keep each memory's `description:` frontmatter and its `MEMORY.md` hook in
     agreement; if an edit changed what a memory is about, sharpen both.

5. **Rebuild `MEMORY.md`** so it indexes exactly the files that remain — no stale
   lines, no missing ones. One line per memory: `- [Title](file.md) — one-line
   hook`. No frontmatter; keep it under ~150 chars per line.

6. **Confirm and clean up.** Summarize what changed (edited / deleted / index),
   then `scripts/stop.sh "$STATE_DIR"`.

**Done when** every changeset entry has been applied to disk and `MEMORY.md` lists
exactly the surviving memory files.

## Changeset format

`$STATE_DIR/changeset.json`, overwritten on each save (last save wins):

```json
{
  "savedAt": "2026-09-12T10:00:00.000Z",
  "memories": [
    { "filename": "user_role.md", "description": "…", "body": "…", "delete": false }
  ]
}
```

`filename` identifies the file in `$MEMORY_DIR`. `description` and `body` are the
user's current values (edited or not). The changeset carries no `name` or `type` —
those are structural; read them from the original file and preserve them.
