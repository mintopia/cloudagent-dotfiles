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

Execute a plan by proxying tool-use calls to a local LLM running in LM Studio. Claude stays as orchestrator and reviewer — the local LLM implements.

This skill is a third execution option alongside `superpowers:executing-plans` (Claude does it sequentially) and `superpowers:subagent-driven-development` (Claude subagents do it in parallel). Here, Claude delegates implementation to an external model while retaining full control over tool execution, safety, and quality gates.

## Announce at Start

When this skill activates, announce:

> I'm using the **local-llm-development** skill. Claude will orchestrate and review; the local LLM will implement via LM Studio.

## Prerequisites

Before using this skill, confirm:

1. **LM Studio is running** with a model loaded and the API server enabled (Settings > Local Server > Start).
2. **The API is reachable** from this environment. If LM Studio runs on your local machine and this is a cloud workspace, an SSH tunnel or port forward is required (e.g. `ssh -R 1234:localhost:1234 ...`).
3. **curl and jq** are available in the shell (`which curl jq`).

If any prerequisite fails, report `BLOCKED` with the specific failure and instructions for the user to fix it.

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `LMSTUDIO_API_URL` | `http://localhost:1234/v1` | Base URL for the LM Studio OpenAI-compatible API. |
| `LMSTUDIO_MODEL` | *(auto-detected)* | Model identifier. If unset, the proxy queries `/v1/models` and uses the first loaded model. |
| `LMSTUDIO_ROLES` | `implementer` | Comma-separated list of roles to route to the local LLM. Options: `implementer`, `spec-reviewer`, `code-quality-reviewer`, `all`. |

Set these via environment variables or export them in the shell before starting.

## When to Offer This Option

After `superpowers:writing-plans` creates a plan and presents execution options, offer a third option:

> **Option 3: Local LLM** — Implementation delegated to a local model via LM Studio. Claude orchestrates, reviews, and gates all tool calls. Cost-effective for mechanical tasks.

Present this option only when LM Studio connectivity is confirmed (the ping check in the startup sequence passes). If the ping fails, do not offer this option — fall back to options 1 and 2.

## Startup Sequence

When the user selects local LLM execution:

1. **Ping check** — Run `./scripts/llm-proxy.sh ping` to verify LM Studio is reachable and a model is loaded. If this fails, report `BLOCKED` and stop.

2. **Start session** — Run `./scripts/llm-proxy.sh start-session` to initialize a session directory under `.local-llm-sessions/` with timestamps, model info, and token counters.

3. **Read plan** — Read the plan file (from the writing-plans output) in full.

4. **Extract tasks** — Parse all tasks from the plan. Each task has: an ID, a title, a description, acceptance criteria, and dependencies.

5. **Create TodoWrite** — Create a TodoWrite checklist with all tasks so progress is visible. Mark each task as `[ ]` initially.

## Role Routing

Before dispatching each piece of work, check `LMSTUDIO_ROLES`:

- **If the role is listed** (or `LMSTUDIO_ROLES=all`): route to the local LLM via the proxy loop (below).
- **If the role is NOT listed**: dispatch as a Claude subagent using the standard `superpowers:subagent-driven-development` templates.

This means you can mix and match. For example, with `LMSTUDIO_ROLES=implementer`, the local LLM implements but Claude handles spec review and code quality review directly.

## The Proxy Loop

For each unit of work routed to the local LLM, execute this loop:

### Step 1: Build Prompt

Construct the prompt from `./implementer-prompt.md`:

- Replace `[TASK_NAME]` with the task title.
- Replace `[FULL TEXT]` with the task description and acceptance criteria.
- Replace `[Context]` with relevant codebase context (file tree, related files, patterns to follow).
- Replace `[Working Directory]` with the absolute path to the working directory.

Include the tool schemas from `./scripts/tool-schemas.json` so the LLM knows its available tools.

### Step 2: Send to LLM

Send the prompt via:

```bash
./scripts/llm-proxy.sh chat "<system_prompt>" "<user_message>"
```

This returns a JSON response with the LLM's reply.

### Step 3: Parse and Execute

Parse the response JSON. The response `type` field determines the action:

- **`text`** — The LLM is reasoning or reporting. Log it and continue the loop (send it back as context in the next turn).

- **`tool_calls`** — The LLM wants to use tools. For each tool call, apply the permission model:

  | Tool | Action | Permission |
  |---|---|---|
  | `read_file` | Read tool | Auto-execute |
  | `list_directory` | `Bash ls` | Auto-execute |
  | `write_file` | Check path is within project directory, then Write tool | Standard permission prompt (normal mode) or auto (yolo mode) |
  | `edit_file` | Check path is within project directory, then Edit tool | Standard permission prompt (normal mode) or auto (yolo mode) |
  | `run_command` | Inspect the command. Categorize as safe, dangerous, or hard-blocked (see Safety below). Safe commands auto-execute. Dangerous commands are surfaced to the user for approval. Hard-blocked commands are refused. | Varies by category |
  | `task_complete` | Exit the proxy loop. Record status and summary. | Auto-execute |

  Execute each tool call, collect the results, and send them back to the LLM as the next message in the conversation.

- **`error`** — The proxy or LLM returned an error. Log the error. If recoverable (e.g. timeout), retry once. If not, abort the task with `BLOCKED`.

### Step 4: Loop Controls

Continue the loop until one of these conditions:

- **`task_complete` called** — the LLM signals it is done. Exit the loop normally.
- **50 iterations reached** — hard cap on loop iterations. Abort with `BLOCKED: max iterations reached`.
- **3 consecutive identical tool calls** — the LLM is stuck in a loop. Abort with `BLOCKED: stuck in repeated calls`.
- **3 consecutive unparseable responses** — the LLM is not producing valid tool-use JSON. Abort with `BLOCKED: unable to parse LLM responses`.

### Step 5: Handle Status

When the loop exits, the LLM reports a status via `task_complete`. Handle it the same way as `superpowers:subagent-driven-development`:

- **DONE** — Task complete. Mark the TodoWrite item as `[x]`. Proceed to the next phase (review).
- **DONE_WITH_CONCERNS** — Task complete but with caveats. Log the concerns. Mark as `[x]` but flag for review. Proceed to review.
- **NEEDS_CONTEXT** — The LLM needs information it cannot find. Claude provides the missing context and re-runs the proxy loop for this task.
- **BLOCKED** — The LLM cannot proceed. Claude attempts to resolve the blocker. If unresolvable, surface to the user.

## Safety — Hard Rules

These rules apply regardless of mode (normal or yolo) and regardless of which model is executing:

### Hard-Blocked Operations (always refused)

- Writes to files outside the project directory
- `git push` (any variant)
- `curl`, `wget`, or any network request to external URLs (exception: `LMSTUDIO_API_URL` is always allowed)
- `rm -rf /` or `rm -rf ~` or any destructive command targeting root or home
- Reading `.env`, credentials files, API keys, or secrets
- `chmod 777`, `sudo`, or any privilege escalation

### Normal Mode

- Read operations (read_file, list_directory) auto-execute without prompts.
- Write operations (write_file, edit_file) get standard permission prompts — the user sees what will be written and approves.
- Dangerous shell commands (anything not in the safe list) are surfaced to the user with the full command for approval.

### Yolo Mode

- Read and write operations auto-execute without prompts.
- Shell commands auto-execute without prompts.
- Hard-blocked operations are STILL refused — yolo mode does not override safety rules.

## Per-Task Flow

For each task in the plan, execute this sequence:

1. **Route implementer** — Send the task to the implementer (local LLM or Claude subagent, per role routing). The implementer writes code, tests, and commits.

2. **Route spec reviewer** — Send the implementation to the spec reviewer. The reviewer checks that the implementation meets the task's acceptance criteria and the plan's requirements.
   - If the review **passes**: proceed to step 3.
   - If the review **fails**: send the feedback back to the implementer for fixes, then re-run the spec review. Max 2 fix cycles — if still failing after 2 rounds, mark as `DONE_WITH_CONCERNS` and proceed.

3. **Route code quality reviewer** — Send the implementation to the code quality reviewer. The reviewer checks for code style, patterns, test coverage, and maintainability.
   - If the review **passes**: proceed to step 4.
   - If the review **fails**: send the feedback back to the implementer for fixes, then re-run the code quality review. Max 2 fix cycles — if still failing after 2 rounds, mark as `DONE_WITH_CONCERNS` and proceed.

4. **Mark complete** — Update the TodoWrite checklist. Move to the next task.

After all tasks are complete: invoke `superpowers:finishing-a-development-branch` to handle merge, PR, or cleanup.

## Continuous Execution

Same as `superpowers:subagent-driven-development`: do not pause between tasks unless a task is `BLOCKED` or `NEEDS_CONTEXT` and requires user input. Execute all tasks in sequence without stopping for confirmation between them.

## Integration

### Required Skills

These skills must be available and are invoked during the workflow:

- **superpowers:using-git-worktrees** — ensures an isolated workspace for implementation
- **superpowers:writing-plans** — creates the plan that this skill executes
- **superpowers:requesting-code-review** — used for final review before completion
- **superpowers:finishing-a-development-branch** — handles PR creation, merge, or cleanup after all tasks complete

### Supplements

This skill is a third execution option alongside:

- **superpowers:subagent-driven-development** — Claude subagents implement in parallel
- **superpowers:executing-plans** — Claude implements sequentially with review checkpoints

All three skills consume plans produced by `superpowers:writing-plans` and produce completed branches ready for `superpowers:finishing-a-development-branch`.
