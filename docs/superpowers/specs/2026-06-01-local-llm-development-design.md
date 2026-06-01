# Local LLM Development — Design Spec

## Goal

Add a third execution option to the superpowers writing-plans flow that delegates coding work to a local LLM running via LM Studio, with Claude acting as orchestrator, tool-use proxy, and reviewer.

## Architecture

### Execution Options (after writing-plans)

1. **Subagent-Driven** — Claude subagents via Agent tool (existing)
2. **Inline Execution** — same session via executing-plans (existing)
3. **Local LLM** — external model via LM Studio API (new)

### Components

- `skills/local-llm-development/SKILL.md` — orchestration skill (Claude's instructions)
- `skills/local-llm-development/scripts/llm-proxy.sh` — shell script handling HTTP request/response cycle with LM Studio
- `skills/local-llm-development/scripts/tool-schemas.json` — tool definitions sent to the LLM

### Configuration (env vars)

| Variable | Default | Purpose |
|----------|---------|---------|
| `LMSTUDIO_API_URL` | `http://localhost:1234/v1` | LM Studio API endpoint |
| `LMSTUDIO_MODEL` | auto-detected from LM Studio | Model name for completions |
| `LMSTUDIO_ROLES` | `implementer` | Comma-separated roles to route to local LLM (`implementer`, `spec-reviewer`, `code-quality-reviewer`, `all`) |

The LM Studio server may be running remotely (e.g. on the user's local machine) with a reverse SSH tunnel exposing it to the Cloud Agent environment.

---

## Tool-Use Proxy Loop

Claude mediates all interactions between the local LLM and the codebase. The local LLM requests tool calls via OpenAI function calling; Claude inspects and executes each one.

### Tool Schemas

| Tool | Purpose | Permission tier |
|------|---------|----------------|
| `read_file(path)` | Read file contents | Read-only — auto-approve |
| `list_directory(path)` | List files in a directory | Read-only — auto-approve |
| `write_file(path, content)` | Create/overwrite a file | Write — Claude executes via Write/Edit |
| `edit_file(path, old_text, new_text)` | Patch a file | Write — Claude executes via Edit |
| `run_command(command)` | Run a shell command | Shell — Claude inspects, surfaces dangerous commands |
| `task_complete(status, summary)` | Signal task completion | Control flow — ends the loop |

### Loop Mechanics

1. Claude builds the initial prompt (task text + context, reusing implementer-prompt.md template)
2. Claude calls `llm-proxy.sh chat` with the prompt + tool schemas
3. Script POSTs to LM Studio, returns response JSON
4. Claude parses response:
   - Text content → accumulate as conversation context
   - `tool_call` → Claude inspects, executes via its own tools, feeds result back
   - `task_complete` → exit loop, return status + summary
5. Repeat until `task_complete` or max iterations (default 50)

---

## Proxy Script (`llm-proxy.sh`)

### Interface

```bash
# Check connectivity
llm-proxy.sh ping --api-url $URL

# Start a new session
llm-proxy.sh start --api-url $URL --model $MODEL

# Send a message / tool result, get response
llm-proxy.sh chat \
  --session /tmp/llm-session-XXXX.json \
  --message "..." \
  [--tools tool-schemas.json] \
  [--tool-result '{"tool_call_id":"...","content":"..."}']
```

### Session State

Conversation history maintained in a temp JSON file (`/tmp/llm-session-*.json`). Each `chat` call appends the new message, POSTs the full conversation to `/v1/chat/completions`, appends the response, and prints the assistant's response to stdout.

### Output Format

```json
{
  "type": "text|tool_calls|error",
  "content": "...",
  "tool_calls": [
    {
      "id": "call_123",
      "function": {
        "name": "write_file",
        "arguments": "{\"path\":\"src/app.ts\",\"content\":\"...\"}"
      }
    }
  ]
}
```

### Error Handling

- Connection refused → `{"type":"error","content":"Cannot reach LM Studio at $URL"}`
- Model not found → error with suggestion to check `LMSTUDIO_MODEL`
- Malformed response → return raw response, let Claude decide whether to parse or abort

---

## Integration with Superpowers Flow

### Discoverability

The skill's description makes it trigger-able when the user asks for local LLM execution. After `writing-plans` presents options 1 and 2, Claude — with this skill loaded — offers option 3.

### Task Lifecycle (mirrors subagent-driven-development exactly)

1. Read plan, extract tasks, create TodoWrite
2. Per task:
   - **Implementer** → routed per `LMSTUDIO_ROLES` (default: local LLM)
   - **Spec reviewer** → routed per config (default: Claude subagent)
   - **Code quality reviewer** → routed per config (default: Claude subagent)
3. After all tasks → final review → `finishing-a-development-branch`

### Connectivity Check

Before starting, Claude runs `llm-proxy.sh ping`. On failure: surface error, suggest checking LM Studio / SSH tunnel, or fall back to option 1 (Claude subagents).

### Prompt Reuse

The implementer prompt from `subagent-driven-development/implementer-prompt.md` is reused. The task description, context framing, self-review instructions, and status reporting (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT) all stay the same. The only adaptation is that the LLM receives tool schemas instead of having native Claude Code tool access.

---

## Permission Model & Safety

### Principle

The local LLM is untrusted. Claude is the trust boundary. Every action passes through Claude's judgment.

### Permission Tiers

| Tier | Tools | Normal mode | Yolo mode |
|------|-------|-------------|-----------|
| Read-only | `read_file`, `list_directory` | Auto-execute | Auto-execute |
| Write | `write_file`, `edit_file` | Standard permission prompts via Claude's tools | Auto-execute |
| Shell | `run_command` | Claude inspects; safe commands execute, dangerous ones surface to user | Auto-execute (Claude still refuses clearly destructive commands) |

### Hard Blocks (regardless of mode)

- Writes outside the project directory
- Commands that push to remote, send external network requests, or modify system files
- Access to secrets/credentials files

### Runaway Protection

- Max 50 iterations per task (configurable)
- 3 consecutive identical tool calls → break loop, treat as BLOCKED
- 3 consecutive unparseable responses → abort, suggest checking model compatibility

### Audit Trail

Claude logs each tool call and result as conversation output. The user sees exactly what the local LLM requested and what Claude executed.
