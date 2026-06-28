# Idempotently add our hooks to settings:
#   - night-handoff Stop / UserPromptSubmit hooks
#   - cloudagent-skill SessionStart hook
# Args: --arg stop_cmd "<abs path> stop"  --arg touch_cmd "<abs path> touch"
#       --arg session_start_cmd "<abs path>"
# Existing hooks for any event are preserved; our entry is added only if a
# hook with the same command string is not already present.

def has_cmd($event; $cmd):
  (.hooks[$event] // []) | any(.[].hooks[]?; .command == $cmd);

def add_hook($event; $cmd):
  if has_cmd($event; $cmd) then .
  else .hooks[$event] = ((.hooks[$event] // [])
       + [{hooks: [{type: "command", command: $cmd}]}])
  end;

.hooks = (.hooks // {})
| add_hook("Stop"; $stop_cmd)
| add_hook("UserPromptSubmit"; $touch_cmd)
| add_hook("SessionStart"; $session_start_cmd)
