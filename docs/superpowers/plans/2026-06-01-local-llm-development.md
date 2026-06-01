# Local LLM Development Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a skill that lets Claude orchestrate plan execution by proxying tool-use calls to a local LLM running in LM Studio, instead of dispatching Claude subagents.

**Architecture:** A SKILL.md with orchestration instructions, a shell script (`llm-proxy.sh`) that handles the HTTP request/response cycle with LM Studio's OpenAI-compatible API, a JSON file with tool schemas, and an adapted implementer prompt. Claude acts as the trust boundary — inspecting and executing every tool call the local LLM requests.

**Tech Stack:** Bash, curl, jq, OpenAI-compatible chat completions API

---

### Task 1: Tool Schemas JSON

**Files:**
- Create: `skills/local-llm-development/scripts/tool-schemas.json`

- [ ] **Step 1: Create the tool schemas file**

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read the contents of a file at the given path. Returns the full file content as a string.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {
              "type": "string",
              "description": "Absolute or project-relative path to the file"
            }
          },
          "required": ["path"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "list_directory",
        "description": "List files and directories at the given path. Returns one entry per line.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {
              "type": "string",
              "description": "Absolute or project-relative path to the directory"
            }
          },
          "required": ["path"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "write_file",
        "description": "Create or overwrite a file with the given content. The parent directory must exist.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {
              "type": "string",
              "description": "Absolute or project-relative path to the file"
            },
            "content": {
              "type": "string",
              "description": "The full content to write to the file"
            }
          },
          "required": ["path", "content"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "edit_file",
        "description": "Replace a specific text span in an existing file. The old_text must appear exactly once in the file.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {
              "type": "string",
              "description": "Absolute or project-relative path to the file"
            },
            "old_text": {
              "type": "string",
              "description": "The exact text to find and replace (must be unique in the file)"
            },
            "new_text": {
              "type": "string",
              "description": "The replacement text"
            }
          },
          "required": ["path", "old_text", "new_text"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "run_command",
        "description": "Execute a shell command and return its stdout, stderr, and exit code. Use for running tests, linters, git commands, etc.",
        "parameters": {
          "type": "object",
          "properties": {
            "command": {
              "type": "string",
              "description": "The shell command to execute"
            }
          },
          "required": ["command"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "task_complete",
        "description": "Signal that the current task is finished. Call this when you have completed implementation, testing, and committing.",
        "parameters": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": ["DONE", "DONE_WITH_CONCERNS", "BLOCKED", "NEEDS_CONTEXT"],
              "description": "DONE: completed successfully. DONE_WITH_CONCERNS: completed but have doubts. BLOCKED: cannot complete. NEEDS_CONTEXT: need more information."
            },
            "summary": {
              "type": "string",
              "description": "What you implemented (or attempted), what you tested, files changed, any concerns."
            }
          },
          "required": ["status", "summary"]
        }
      }
    }
  ]
}
```

- [ ] **Step 2: Verify the JSON is valid**

Run: `cd /home/workspace/cloudagent-dotfiles && jq . skills/local-llm-development/scripts/tool-schemas.json > /dev/null`
Expected: exit 0, no output (valid JSON)

- [ ] **Step 3: Commit**

```bash
git add skills/local-llm-development/scripts/tool-schemas.json
git commit -m "feat(local-llm): add OpenAI function-calling tool schemas"
```

---

### Task 2: Proxy Script (`llm-proxy.sh`)

**Files:**
- Create: `skills/local-llm-development/scripts/llm-proxy.sh`

- [ ] **Step 1: Create the proxy script with the `ping` subcommand**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_API_URL="http://localhost:1234/v1"

usage() {
  cat <<'EOF'
Usage: llm-proxy.sh <command> [options]

Commands:
  ping   --api-url URL                Check LM Studio connectivity
  start  --api-url URL --model MODEL  Start a new session (prints session path)
  chat   --session FILE --message MSG Send a message or tool result

Options (chat):
  --tools FILE                        Path to tool-schemas.json (first message only)
  --tool-results JSON                 JSON array of tool results to send

Environment:
  LMSTUDIO_API_URL   Default API URL (default: http://localhost:1234/v1)
  LMSTUDIO_MODEL     Default model name (auto-detected if unset)
EOF
  exit 1
}

error_json() {
  printf '{"type":"error","content":"%s"}\n' "$1"
  exit 1
}

cmd_ping() {
  local api_url="${1:-${LMSTUDIO_API_URL:-$DEFAULT_API_URL}}"
  local response
  if ! response=$(curl -s --connect-timeout 5 --max-time 10 "${api_url}/models" 2>&1); then
    error_json "Cannot reach LM Studio at ${api_url}. Check that LM Studio is running and the API server is enabled. If running remotely, verify your SSH tunnel."
  fi
  local model_count
  model_count=$(echo "$response" | jq -r '.data | length' 2>/dev/null) || error_json "LM Studio responded but returned invalid JSON. Response: $(echo "$response" | head -c 200)"
  if [ "$model_count" -eq 0 ]; then
    error_json "LM Studio is reachable but no models are loaded. Load a model in LM Studio before continuing."
  fi
  local models
  models=$(echo "$response" | jq -r '.data[].id' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  printf '{"type":"text","content":"LM Studio reachable. Models available: %s"}\n' "$models"
}

# Parse top-level command
[ $# -lt 1 ] && usage
COMMAND="$1"; shift

case "$COMMAND" in
  ping)
    api_url=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --api-url) api_url="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    cmd_ping "$api_url"
    ;;
  start|chat)
    echo "Not yet implemented: $COMMAND" >&2; exit 1
    ;;
  *)
    usage
    ;;
esac
```

- [ ] **Step 2: Make it executable and test ping against no server**

Run: `chmod +x /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh && /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh ping --api-url http://localhost:9999`
Expected: JSON output with `"type":"error"` and a message about not reaching LM Studio

- [ ] **Step 3: Add the `start` subcommand**

Replace the `start|chat)` placeholder case with the `start` subcommand. Add the `start` handler before the case statement:

```bash
cmd_start() {
  local api_url="${LMSTUDIO_API_URL:-$DEFAULT_API_URL}"
  local model="${LMSTUDIO_MODEL:-}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --api-url) api_url="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      *) usage ;;
    esac
  done

  # Auto-detect model if not specified
  if [ -z "$model" ]; then
    local models_response
    models_response=$(curl -s --connect-timeout 5 --max-time 10 "${api_url}/models" 2>/dev/null) || error_json "Cannot reach LM Studio at ${api_url}"
    model=$(echo "$models_response" | jq -r '.data[0].id' 2>/dev/null) || error_json "Failed to detect model from LM Studio"
    [ "$model" = "null" ] && error_json "No models loaded in LM Studio"
  fi

  local session_file
  session_file=$(mktemp /tmp/llm-session-XXXX.json)

  # Initialize session with metadata and empty messages array
  jq -n \
    --arg url "$api_url" \
    --arg model "$model" \
    '{api_url: $url, model: $model, messages: []}' > "$session_file"

  printf '{"type":"text","content":"Session started","session":"%s","model":"%s"}\n' "$session_file" "$model"
}
```

Update the case statement:

```bash
  start)
    cmd_start "$@"
    ;;
  chat)
    echo "Not yet implemented: chat" >&2; exit 1
    ;;
```

- [ ] **Step 4: Test start subcommand**

Run: `LMSTUDIO_API_URL=http://localhost:9999 /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh start --model test-model`
Expected: error JSON about not reaching LM Studio (since no server is running — but the argument parsing and session creation logic is exercised)

- [ ] **Step 5: Add the `chat` subcommand**

Add the `cmd_chat` function before the case statement:

```bash
cmd_chat() {
  local session_file="" message="" tools_file="" tool_results=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --session) session_file="$2"; shift 2 ;;
      --message) message="$2"; shift 2 ;;
      --tools) tools_file="$2"; shift 2 ;;
      --tool-results) tool_results="$2"; shift 2 ;;
      *) usage ;;
    esac
  done

  [ -z "$session_file" ] && error_json "Missing --session"
  [ ! -f "$session_file" ] && error_json "Session file not found: $session_file"

  local api_url model
  api_url=$(jq -r '.api_url' "$session_file")
  model=$(jq -r '.model' "$session_file")

  # Append user message or tool results to session
  if [ -n "$tool_results" ]; then
    # tool_results is a JSON array of {tool_call_id, content} objects
    local updated
    updated=$(jq --argjson results "$tool_results" '
      .messages += [
        $results[] | {role: "tool", tool_call_id: .tool_call_id, content: .content}
      ]
    ' "$session_file")
    echo "$updated" > "$session_file"
  elif [ -n "$message" ]; then
    local updated
    updated=$(jq --arg msg "$message" '.messages += [{role: "user", content: $msg}]' "$session_file")
    echo "$updated" > "$session_file"
  else
    error_json "Missing --message or --tool-results"
  fi

  # Build request body
  local request_body
  if [ -n "$tools_file" ] && [ -f "$tools_file" ]; then
    request_body=$(jq -n \
      --arg model "$model" \
      --argjson messages "$(jq '.messages' "$session_file")" \
      --argjson tools "$(jq '.tools' "$tools_file")" \
      '{model: $model, messages: $messages, tools: $tools, tool_choice: "auto"}')
  else
    request_body=$(jq -n \
      --arg model "$model" \
      --argjson messages "$(jq '.messages' "$session_file")" \
      '{model: $model, messages: $messages}')
  fi

  # POST to LM Studio
  local response http_code
  response=$(curl -s --connect-timeout 10 --max-time 300 \
    -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "${api_url}/chat/completions" 2>&1) || error_json "HTTP request failed to ${api_url}/chat/completions"

  http_code=$(echo "$response" | tail -1)
  response=$(echo "$response" | sed '$d')

  if [ "$http_code" != "200" ]; then
    local err_msg
    err_msg=$(echo "$response" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "$response" | head -c 500)
    error_json "LM Studio returned HTTP ${http_code}: ${err_msg}"
  fi

  # Extract the assistant message
  local assistant_message finish_reason
  assistant_message=$(echo "$response" | jq '.choices[0].message' 2>/dev/null) || error_json "Failed to parse LM Studio response"
  finish_reason=$(echo "$response" | jq -r '.choices[0].finish_reason // "stop"' 2>/dev/null)

  # Append assistant message to session
  local updated
  updated=$(jq --argjson msg "$assistant_message" '.messages += [$msg]' "$session_file")
  echo "$updated" > "$session_file"

  # Format output for Claude
  local has_tool_calls
  has_tool_calls=$(echo "$assistant_message" | jq 'has("tool_calls") and (.tool_calls | length > 0)' 2>/dev/null)

  if [ "$has_tool_calls" = "true" ]; then
    echo "$assistant_message" | jq '{
      type: "tool_calls",
      content: (.content // ""),
      tool_calls: [.tool_calls[] | {id: .id, function: {name: .function.name, arguments: .function.arguments}}]
    }'
  else
    local content
    content=$(echo "$assistant_message" | jq -r '.content // ""' 2>/dev/null)
    jq -n --arg content "$content" '{type: "text", content: $content}'
  fi
}
```

Update the case statement:

```bash
  chat)
    cmd_chat "$@"
    ;;
```

- [ ] **Step 6: Verify the complete script parses correctly**

Run: `bash -n /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh`
Expected: exit 0, no output (valid bash syntax)

- [ ] **Step 7: Commit**

```bash
git add skills/local-llm-development/scripts/llm-proxy.sh
git commit -m "feat(local-llm): add llm-proxy.sh with ping, start, and chat subcommands"
```

---

### Task 3: Implementer Prompt for Local LLM

**Files:**
- Create: `skills/local-llm-development/implementer-prompt.md`

This adapts the superpowers `implementer-prompt.md` template for the tool-use proxy context. The key difference: instead of referencing Claude Code tools, it tells the LLM to use the function-calling tools (`read_file`, `write_file`, `edit_file`, `run_command`, `task_complete`).

- [ ] **Step 1: Create the implementer prompt template**

```markdown
# Local LLM Implementer Prompt Template

Use this template when building the system prompt for a local LLM implementation task.

The `[PLACEHOLDERS]` are filled in by Claude (the orchestrator) before sending to the LLM.

## System Prompt

```
You are an implementation agent. You have access to tools for reading, writing,
and editing files, running shell commands, and signaling task completion.

Your workflow:
1. Read any files you need to understand
2. Implement the requested changes
3. Run tests to verify
4. Commit your work
5. Call task_complete with your status

IMPORTANT: You MUST call task_complete when finished. This is how the orchestrator
knows you are done. Do not simply stop responding.
```

## User Message

```
You are implementing [TASK_NAME].

## Task Description

[FULL TEXT of task from plan — pasted here, not a file reference]

## Context

[Scene-setting: where this fits in the project, dependencies, what was built
in prior tasks, architectural context the LLM needs]

## Working Directory

[Absolute path to the project root]

## Before You Begin

If something in the task description is ambiguous or you need more context,
use read_file and list_directory to explore. Do not guess — investigate.

## Your Job

1. Implement exactly what the task specifies — nothing more, nothing less
2. Write tests (following TDD if the task says to)
3. Run tests with run_command to verify they pass
4. Commit your work with run_command:
   git add <files> && git commit -m "<message>"
5. Self-review: re-read what you wrote. Check completeness, naming, patterns.
   If you find issues, fix them before completing.
6. Call task_complete with your status and summary

## Code Organization

- Follow the file structure defined in the task
- Each file should have one clear responsibility
- Follow existing patterns in the codebase
- If a file is growing beyond what the task describes, report it as
  DONE_WITH_CONCERNS rather than restructuring on your own

## When You Are Stuck

It is OK to stop. Bad work is worse than no work.

Call task_complete with status BLOCKED or NEEDS_CONTEXT when:
- The task requires architectural decisions with multiple valid approaches
- You need to understand code beyond what was provided
- You are uncertain whether your approach is correct
- The task involves restructuring the plan did not anticipate

Describe specifically what you are stuck on and what kind of help you need.

## Report via task_complete

- status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- summary: What you implemented, what you tested, files changed, any concerns
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/local-llm-development/implementer-prompt.md
git commit -m "feat(local-llm): add implementer prompt template for local LLM"
```

---

### Task 4: SKILL.md — The Orchestration Skill

**Files:**
- Create: `skills/local-llm-development/SKILL.md`

This is the core skill file — it tells Claude how to orchestrate the entire flow, run the proxy loop, handle permissions, and integrate with the superpowers lifecycle.

- [ ] **Step 1: Create the SKILL.md**

```markdown
---
name: local-llm-development
description: >
  Use when executing implementation plans with a local LLM (via LM Studio)
  instead of Claude subagents. Claude orchestrates and reviews, external LLM
  implements. Supplements superpowers:subagent-driven-development as a third
  execution option after superpowers:writing-plans creates a plan. Use when
  the user asks to use a local model, LM Studio, or external LLM for
  implementation work.
---

# Local LLM Development

Execute a plan by proxying tool-use calls to a local LLM running in LM Studio. Claude stays as orchestrator and reviewer. The local LLM implements, tests, and commits via function-calling tools that Claude executes on its behalf.

**Announce at start:** "I'm using the local-llm-development skill. Claude will orchestrate and review; the local LLM will implement via LM Studio."

## Prerequisites

- LM Studio running with a model loaded and API server enabled
- LM Studio API reachable from this environment (may require SSH tunnel for remote setups)
- `curl` and `jq` available in PATH

## Configuration

| Env var | Default | Purpose |
|---------|---------|---------|
| `LMSTUDIO_API_URL` | `http://localhost:1234/v1` | LM Studio API endpoint |
| `LMSTUDIO_MODEL` | auto-detected | Model to use for completions |
| `LMSTUDIO_ROLES` | `implementer` | Roles to route to local LLM: `implementer`, `spec-reviewer`, `code-quality-reviewer`, `all` |

## When to Offer This Option

After `superpowers:writing-plans` presents options 1 (Subagent-Driven) and 2 (Inline Execution), offer:

**3. Local LLM** - Implementation delegated to a local model via LM Studio. Claude orchestrates, reviews, and gates all tool calls. Cost-effective for mechanical tasks.

## Startup Sequence

1. Check connectivity: run `./scripts/llm-proxy.sh ping --api-url $LMSTUDIO_API_URL`
2. If ping fails, tell the user and suggest:
   - Check LM Studio is running and API server is enabled
   - Check SSH tunnel if running remotely
   - Fall back to option 1 (Claude subagents)
3. Start a session: run `./scripts/llm-proxy.sh start --api-url $LMSTUDIO_API_URL --model $LMSTUDIO_MODEL`
4. Note the session file path and model name from the response
5. Read the plan, extract all tasks with full text, create TodoWrite

## Role Routing

Check `LMSTUDIO_ROLES` (default: `implementer`). For each role in the task lifecycle:

- If the role is listed (or `LMSTUDIO_ROLES=all`): route to local LLM via the proxy loop below
- If the role is NOT listed: dispatch as a Claude subagent using the standard superpowers templates:
  - Implementer: `superpowers:subagent-driven-development/implementer-prompt.md`
  - Spec reviewer: `superpowers:subagent-driven-development/spec-reviewer-prompt.md`
  - Code quality reviewer: `superpowers:subagent-driven-development/code-quality-reviewer-prompt.md`

## The Proxy Loop (for roles routed to local LLM)

For each task routed to the local LLM:

### Step 1: Build the prompt

Use the template in `./implementer-prompt.md`. Fill in:
- `[TASK_NAME]`: from the plan
- `[FULL TEXT]`: complete task description from the plan (paste it, don't reference the file)
- `[Context]`: scene-setting — where this fits, what prior tasks built, dependencies
- `[Working Directory]`: the project root path

### Step 2: Send to LM Studio

```bash
./scripts/llm-proxy.sh chat \
  --session $SESSION_FILE \
  --message "$PROMPT" \
  --tools ./scripts/tool-schemas.json
```

### Step 3: Parse and execute

Read the JSON response. Handle by `type`:

**`type: "text"`** — The LLM sent a text message (thinking aloud, asking a question). Log it. If it's a question you can answer from context, send your answer as the next message (without `--tools` since tools were already sent on the first call). If you cannot answer, treat the task as NEEDS_CONTEXT.

**`type: "tool_calls"`** — The LLM requested tool calls. For EACH tool call:

1. **Inspect the call.** Apply the permission model:

   | Tool | Action |
   |------|--------|
   | `read_file` | Execute immediately: use the Read tool. Return file contents. |
   | `list_directory` | Execute immediately: use Bash `ls -la`. Return output. |
   | `write_file` | Check path is within project directory. Execute via Write tool. Return "ok" or error. |
   | `edit_file` | Check path is within project directory. Execute via Edit tool. Return "ok" or error. |
   | `run_command` | **Inspect the command.** Safe commands (test runners, linters, `git add`, `git commit`, `git status`, `git diff`, `cat`, `ls`, `mkdir`): execute via Bash. Dangerous or ambiguous commands: surface to the user for approval. Hard-blocked commands (see Safety section): refuse and return error. Return stdout + stderr + exit code. |
   | `task_complete` | Exit the loop. Extract status and summary. |

2. **Collect all results** into a JSON array:
   ```json
   [
     {"tool_call_id": "call_123", "content": "file contents here..."},
     {"tool_call_id": "call_456", "content": "ok"}
   ]
   ```

3. **Send results back:**
   ```bash
   ./scripts/llm-proxy.sh chat \
     --session $SESSION_FILE \
     --tool-results '$RESULTS_JSON'
   ```

**`type: "error"`** — The proxy script hit a problem. Log the error. If it's a connectivity issue, retry once. If it persists, treat the task as BLOCKED.

### Step 4: Loop

Repeat Step 3 until:
- `task_complete` is called → extract status and proceed to review
- 50 iterations reached → treat as BLOCKED
- 3 consecutive identical tool calls → treat as BLOCKED (runaway loop)
- 3 consecutive unparseable responses → abort, suggest checking model compatibility

### Step 5: Handle status

Same as `superpowers:subagent-driven-development`:
- **DONE** → proceed to spec compliance review
- **DONE_WITH_CONCERNS** → read concerns, address if needed, then proceed to review
- **NEEDS_CONTEXT** → provide context, start a new session, re-run the task
- **BLOCKED** → assess and escalate (more context, more capable model, break into pieces, or ask the user)

## Safety — Hard Rules

These apply regardless of mode (normal or yolo):

**Hard-blocked operations** (refuse and return error to the LLM):
- Writes to files outside the project directory
- `git push`, `git push --force`, or any push to remote
- `curl`, `wget`, or any command making external network requests (except to `LMSTUDIO_API_URL`)
- `rm -rf /`, `rm -rf ~`, or any command targeting system/home directories
- Reading `.env`, `credentials.json`, `*.pem`, `*.key`, or similar secrets files
- `chmod 777`, `sudo`, or privilege escalation commands

**In normal mode:** Write operations (write_file, edit_file) go through Claude's standard tools which surface permission prompts as normal. Shell commands that aren't clearly safe get surfaced to the user: "The local LLM wants to run: `<command>`. Allow?"

**In yolo / dangerously-skip-permissions mode:** Safe and write operations auto-execute. Shell commands auto-execute. Hard-blocked operations are still refused.

## Per-Task Flow (full lifecycle)

```
For each task in the plan:
  1. Route implementer per LMSTUDIO_ROLES:
     - Local LLM: run proxy loop (above)
     - Claude: dispatch Agent per superpowers:subagent-driven-development/implementer-prompt.md
  2. Route spec reviewer per LMSTUDIO_ROLES:
     - Local LLM: new session, send spec review prompt via proxy loop
     - Claude: dispatch Agent per superpowers:subagent-driven-development/spec-reviewer-prompt.md
  3. If spec review fails → implementer fixes (same routing) → re-review
  4. Route code quality reviewer per LMSTUDIO_ROLES:
     - Local LLM: new session, send code review prompt via proxy loop
     - Claude: dispatch Agent per superpowers:subagent-driven-development/code-quality-reviewer-prompt.md
  5. If code quality review fails → implementer fixes → re-review
  6. Mark task complete in TodoWrite
```

After all tasks: use `superpowers:finishing-a-development-branch`

## Continuous Execution

Same as subagent-driven-development: do not pause between tasks. Execute all tasks without stopping. Only stop for: BLOCKED status you cannot resolve, genuine ambiguity, or all tasks complete.

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** — ensures isolated workspace
- **superpowers:writing-plans** — creates the plan this skill executes
- **superpowers:requesting-code-review** — code review template for reviewer subagents
- **superpowers:finishing-a-development-branch** — complete development after all tasks

**Supplements:**
- **superpowers:subagent-driven-development** — this skill is the local-LLM alternative
- **superpowers:executing-plans** — the inline alternative
```

- [ ] **Step 2: Commit**

```bash
git add skills/local-llm-development/SKILL.md
git commit -m "feat(local-llm): add orchestration skill for local LLM development"
```

---

### Task 5: Update `install.sh` Summary

**Files:**
- Modify: `skills/local-llm-development/` is already covered by the existing skills install loop in `install.sh:156-170` (it copies all `skills/*/SKILL.md` automatically). But the summary line at the end needs updating.

- [ ] **Step 1: Update the summary line**

In `install.sh`, find:
```
echo "  Skills:      adr, cloudagent, quality-gate, subagent-finder"
```

Replace with:
```
echo "  Skills:      adr, cloudagent, local-llm-development, quality-gate, subagent-finder"
```

- [ ] **Step 2: Verify the install loop handles the scripts/ subdirectory**

Check that `install.sh` lines 162-166 already copy `scripts/` directories:
```bash
for res_dir in scripts references assets; do
  if [ -d "$skill_dir/$res_dir" ]; then
    cp -r "$skill_dir/$res_dir" "$SKILLS_DIR/$skill_name/"
  fi
done
```

This already handles `skills/local-llm-development/scripts/`. No change needed.

Run: `grep -A4 'res_dir in scripts' /home/workspace/cloudagent-dotfiles/install.sh`
Expected: the loop above, confirming scripts/ is copied

- [ ] **Step 3: Verify the non-SKILL.md file (implementer-prompt.md) gets copied**

The install loop only copies `SKILL.md` and `scripts/`, `references/`, `assets/` subdirs. `implementer-prompt.md` sits at the skill root alongside `SKILL.md`. The install loop at line 161 only does `cp "$skill_dir/SKILL.md"` — it does NOT copy other root-level `.md` files.

Fix: add a line to copy any extra `.md` files from the skill directory:

In `install.sh`, after the line `cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"` (line 161), add:

```bash
  # Copy additional markdown files (prompt templates, etc.)
  find "$skill_dir" -maxdepth 1 -name '*.md' ! -name 'SKILL.md' -exec cp {} "$SKILLS_DIR/$skill_name/" \;
```

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(install): include local-llm-development skill and copy extra md files"
```

---

### Task 6: End-to-End Smoke Test (manual verification)

This task verifies the pieces fit together. Since there's no LM Studio server available, this is a dry-run verification.

**Files:**
- No files created or modified

- [ ] **Step 1: Verify all files exist**

Run: `find /home/workspace/cloudagent-dotfiles/skills/local-llm-development -type f | sort`
Expected:
```
skills/local-llm-development/SKILL.md
skills/local-llm-development/implementer-prompt.md
skills/local-llm-development/scripts/llm-proxy.sh
skills/local-llm-development/scripts/tool-schemas.json
```

- [ ] **Step 2: Verify tool-schemas.json is valid**

Run: `jq '.tools | length' /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/tool-schemas.json`
Expected: `6`

- [ ] **Step 3: Verify llm-proxy.sh syntax**

Run: `bash -n /home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 4: Verify llm-proxy.sh ping handles connection failure gracefully**

Run: `/home/workspace/cloudagent-dotfiles/skills/local-llm-development/scripts/llm-proxy.sh ping --api-url http://localhost:9999`
Expected: JSON with `"type":"error"` and a helpful message

- [ ] **Step 5: Verify install.sh would install the skill**

Run: `bash -n /home/workspace/cloudagent-dotfiles/install.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 6: Verify the skill's SKILL.md frontmatter is correct**

Run: `head -8 /home/workspace/cloudagent-dotfiles/skills/local-llm-development/SKILL.md`
Expected: frontmatter with `name: local-llm-development` and a description mentioning LM Studio
