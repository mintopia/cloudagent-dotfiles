# Kanban Ticket System — Full Reference

## Boards

Boards are the top-level containers. Most ticket operations require a `--board` ID.

```bash
cloudagent boards list --json            # list all boards
cloudagent boards get <board-id> --json  # board details with columns
```

## Tickets

### Create

```bash
cloudagent tickets create \
  --board <board-id> \
  --title "Ticket title" \
  --description "Details here" \
  --status <status-id-or-slug> \
  --type <type-id-or-slug> \
  --priority <priority> \
  --labels "label1,label2" \
  --assignee <user-id> \
  --parent <ticket-number> \
  --custom-field SLUG=VALUE \
  --json
```

Only `--board` and `--title` are required. Everything else is optional.
`--custom-field` is repeatable for multiple fields.

### List

```bash
cloudagent tickets list --board <board-id> --json
```

Filters (all optional):
- `--status <slug>` — filter by status
- `--type <slug>` — filter by type
- `--priority <level>` — filter by priority
- `--assignee <user-id>` — filter by assignee
- `--label <label>` — filter by label
- `--parent <ticket-id>` — filter by parent ticket
- `--search "query"` — full-text search
- `--include-closed` — include closed tickets (excluded by default)
- `--all` — fetch all pages
- `--limit <n>` — results per page (default 50)
- `--page <n>` — page number

### Get

```bash
cloudagent tickets get <ticket-id> --json
```

### Update

```bash
cloudagent tickets update <ticket-id> \
  --title "New title" \
  --description "Updated description" \
  --status <status-slug> \
  --type <type-slug> \
  --priority <level> \
  --assignee <user-id> \
  --parent <ticket-number>       # 0 to clear, -1 = not set
  --labels "label1,label2"       # replaces all labels
  --add-label "label-name"       # add a single label
  --remove-label "label-name"    # remove a single label
  --custom-field SLUG=VALUE \
  --json
```

All flags are optional — only specified fields are updated.

### Delete

```bash
cloudagent tickets delete <ticket-id>
```

## Comments

```bash
cloudagent tickets comments list <ticket-id> --json
cloudagent tickets comments add <ticket-id> --body "Comment text"
cloudagent tickets comments delete <ticket-id> --comment <comment-id>
```

## Attachments

```bash
cloudagent tickets attachments list <ticket-id> --json
cloudagent tickets attachments add <ticket-id> --file /path/to/file
cloudagent tickets attachments get <ticket-id> --attachment <attachment-id>
cloudagent tickets attachments delete <ticket-id> --attachment <attachment-id>
```

## Configuration lookups

These list the workspace's configured values. Useful for finding valid IDs/slugs
to pass to ticket create/update commands.

```bash
cloudagent labels list --json      # all labels (ID + name)
cloudagent statuses list --json    # all ticket statuses (ID + slug)
cloudagent types list --json       # all ticket types (ID + slug)
cloudagent fields list --json      # all custom field definitions
```

When creating or updating tickets, use these to discover valid values for
`--status`, `--type`, `--labels`, and `--custom-field` flags.
