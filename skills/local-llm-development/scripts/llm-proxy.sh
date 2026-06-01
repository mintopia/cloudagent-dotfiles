#!/usr/bin/env bash
set -euo pipefail

# llm-proxy.sh — HTTP proxy between Claude and LM Studio's OpenAI-compatible API
# Subcommands: ping, start, chat

###############################################################################
# Helpers
###############################################################################

error_json() {
  jq -n --arg msg "$1" '{"type":"error","content":$msg}'
  exit 1
}

atomic_write() {
  local target="$1"
  local tmp
  tmp=$(mktemp "${target}.tmp.XXXX")
  cat > "$tmp"
  mv "$tmp" "$target"
}

safe_curl() {
  local tmp_body tmp_code
  tmp_body=$(mktemp)
  tmp_code=$(curl -s -o "$tmp_body" --write-out "%{http_code}" "$@" 2>/dev/null) || {
    rm -f "$tmp_body"
    echo ""
    echo "000"
    return 1
  }
  cat "$tmp_body"
  rm -f "$tmp_body"
  echo ""
  echo "$tmp_code"
}

usage() {
  cat <<'USAGE'
Usage: llm-proxy.sh <subcommand> [options]

Subcommands:
  ping   Check LM Studio connectivity
         --api-url URL   (default: $LMSTUDIO_API_URL or http://localhost:1234/v1)

  start  Start a new conversation session
         --api-url URL   (default: $LMSTUDIO_API_URL or http://localhost:1234/v1)
         --model MODEL   (default: $LMSTUDIO_MODEL or auto-detect)

  chat   Send a message or tool results
         --session FILE        Session file (required)
         --message MSG         User message (mutually exclusive with --tool-results)
         --tools FILE          Path to tool-schemas.json
         --tool-results JSON   JSON array of tool results
USAGE
  exit 1
}

resolve_api_url() {
  local url="${1:-}"
  if [[ -n "$url" ]]; then
    echo "$url"
  elif [[ -n "${LMSTUDIO_API_URL:-}" ]]; then
    echo "$LMSTUDIO_API_URL"
  else
    echo "http://localhost:1234/v1"
  fi
}

###############################################################################
# ping — Check LM Studio connectivity
###############################################################################

cmd_ping() {
  local api_url=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --api-url) api_url="$2"; shift 2 ;;
      *) error_json "ping: unknown option: $1" ;;
    esac
  done

  api_url="$(resolve_api_url "$api_url")"

  local response http_code body
  response=$(safe_curl --max-time 10 "${api_url}/models") || {
    error_json "Cannot reach LM Studio at ${api_url}. Check that LM Studio is running and the API server is enabled. If running remotely, verify your SSH tunnel."
  }

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    error_json "Cannot reach LM Studio at ${api_url}. HTTP status ${http_code}."
  fi

  local models
  models=$(echo "$body" | jq -r '.data[]?.id // empty') || {
    error_json "Cannot reach LM Studio at ${api_url}. Invalid response from /models endpoint."
  }

  if [[ -z "$models" ]]; then
    error_json "LM Studio is reachable but no models are loaded. Load a model in LM Studio before continuing."
  fi

  local model_list
  model_list=$(echo "$models" | tr '\n' ',' | sed 's/,$//')

  jq -n --arg models "$model_list" '{"type":"text","content":"LM Studio reachable. Models available: \($models)"}'
}

###############################################################################
# start — Start a new conversation session
###############################################################################

cmd_start() {
  local api_url="" model=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --api-url) api_url="$2"; shift 2 ;;
      --model)   model="$2"; shift 2 ;;
      *) error_json "start: unknown option: $1" ;;
    esac
  done

  api_url="$(resolve_api_url "$api_url")"

  # Resolve model
  if [[ -z "$model" ]]; then
    model="${LMSTUDIO_MODEL:-}"
  fi

  if [[ -z "$model" ]]; then
    local response http_code body
    response=$(safe_curl --max-time 10 "${api_url}/models") || {
      error_json "Cannot reach LM Studio at ${api_url} to auto-detect model."
    }

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
      error_json "Cannot reach LM Studio at ${api_url}. HTTP status ${http_code}."
    fi

    model=$(echo "$body" | jq -r '.data[0].id // empty')

    if [[ -z "$model" ]]; then
      error_json "No models loaded in LM Studio. Load a model before starting a session."
    fi
  fi

  local session_file
  session_file=$(mktemp "${TMPDIR:-/tmp}/llm-session-XXXX.json")

  jq -n \
    --arg api_url "$api_url" \
    --arg model "$model" \
    '{"api_url": $api_url, "model": $model, "messages": []}' \
    > "$session_file"

  jq -n \
    --arg session "$session_file" \
    --arg model "$model" \
    '{"type":"text","content":"Session started","session":$session,"model":$model}'
}

###############################################################################
# chat — Send a message or tool results
###############################################################################

cmd_chat() {
  local session="" message="" tools="" tool_results=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session)      session="$2"; shift 2 ;;
      --message)      message="$2"; shift 2 ;;
      --tools)        tools="$2"; shift 2 ;;
      --tool-results) tool_results="$2"; shift 2 ;;
      *) error_json "chat: unknown option: $1" ;;
    esac
  done

  # Validate
  if [[ -z "$session" ]]; then
    error_json "chat: --session is required"
  fi

  if [[ ! -f "$session" ]]; then
    error_json "chat: session file not found: $session"
  fi

  if [[ -n "$message" && -n "$tool_results" ]]; then
    error_json "chat: --message and --tool-results are mutually exclusive"
  fi

  if [[ -z "$message" && -z "$tool_results" ]]; then
    error_json "chat: either --message or --tool-results is required"
  fi

  # Read session
  local api_url model
  api_url=$(jq -r '.api_url' "$session")
  model=$(jq -r '.model' "$session")

  # Append new messages to session
  if [[ -n "$message" ]]; then
    jq --arg msg "$message" \
      '.messages += [{"role": "user", "content": $msg}]' "$session" \
      | atomic_write "$session"
  fi

  if [[ -n "$tool_results" ]]; then
    jq --argjson results "$tool_results" \
      '.messages += [
        $results[] | {
          "role": "tool",
          "tool_call_id": .tool_call_id,
          "content": .content
        }
      ]' "$session" \
      | atomic_write "$session"
  fi

  # Build the API request body and POST to chat/completions
  local request_body
  if [[ -n "$tools" && -f "$tools" ]]; then
    request_body=$(jq -n \
      --arg model "$model" \
      --slurpfile sess "$session" \
      --slurpfile tfile "$tools" \
      '{
        "model": $model,
        "messages": $sess[0].messages,
        "tools": $tfile[0].tools,
        "tool_choice": "auto"
      }')
  else
    request_body=$(jq -n \
      --arg model "$model" \
      --slurpfile sess "$session" \
      '{
        "model": $model,
        "messages": $sess[0].messages
      }')
  fi

  local response http_code body
  response=$(echo "$request_body" | safe_curl --max-time 300 \
    -H "Content-Type: application/json" \
    --data-binary @- \
    "${api_url}/chat/completions") || {
    error_json "Failed to reach LM Studio at ${api_url}/chat/completions."
  }

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    local err_msg
    err_msg=$(echo "$body" | jq -r '.error.message // empty' 2>/dev/null || true)
    if [[ -n "$err_msg" ]]; then
      error_json "LM Studio API error (HTTP ${http_code}): ${err_msg}"
    else
      error_json "LM Studio API error (HTTP ${http_code}): ${body}"
    fi
  fi

  local choice
  choice=$(echo "$body" | jq '.choices[0].message') || {
    error_json "Invalid response from LM Studio: could not parse choices."
  }

  # Append assistant message to session atomically
  jq --argjson msg "$choice" '.messages += [$msg]' "$session" \
    | atomic_write "$session"

  # Check if the response contains tool calls
  local has_tool_calls
  has_tool_calls=$(echo "$choice" | jq 'has("tool_calls") and (.tool_calls | length > 0)' 2>/dev/null)

  if [[ "$has_tool_calls" == "true" ]]; then
    local content tool_calls
    content=$(echo "$choice" | jq -r '.content // ""')
    tool_calls=$(echo "$choice" | jq '[.tool_calls[] | {
      "id": .id,
      "function": {
        "name": .function.name,
        "arguments": .function.arguments
      }
    }]')

    jq -n \
      --arg content "$content" \
      --argjson tool_calls "$tool_calls" \
      '{"type":"tool_calls","content":$content,"tool_calls":$tool_calls}'
  else
    local content
    content=$(echo "$choice" | jq -r '.content // ""')
    jq -n --arg content "$content" '{"type":"text","content":$content}'
  fi
}

###############################################################################
# Main dispatch
###############################################################################

if [[ $# -lt 1 ]]; then
  usage
fi

subcommand="$1"
shift

case "$subcommand" in
  ping)  cmd_ping "$@" ;;
  start) cmd_start "$@" ;;
  chat)  cmd_chat "$@" ;;
  -h|--help|help) usage ;;
  *) error_json "Unknown subcommand: $subcommand" ;;
esac
