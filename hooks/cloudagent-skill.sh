#!/usr/bin/env bash
# cloudagent-skill.sh — at session start, tell Claude to load the `cloudagent`
# skill so Cloud Agent workspace conventions are always in context.
# Wired to the SessionStart hook. Reads (and ignores) the hook event JSON on
# stdin; emits additionalContext that Claude receives at the start of the session.
set -euo pipefail

# Kill switch.
if [ -n "${CLOUDAGENT_SKILL_HOOK_DISABLE:-}" ]; then exit 0; fi

# Only act inside a Cloud Agent workspace — the same detection the skill uses.
if ! command -v cloudagent >/dev/null 2>&1 && [ -z "${CLOUDAGENT_API_URL:-}" ]; then
  exit 0
fi

context="You are in a Cloud Agent workspace. Before responding, invoke the \`cloudagent\` skill (via the Skill tool) to load the Cloud Agent workspace conventions. They govern how you present files and URLs to the user, expose web servers, and send notifications — follow them for the rest of this session."

jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
