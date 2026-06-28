# Idempotently add the night-handoff Stop / UserPromptSubmit hooks to settings.
# Args: --arg stop_cmd "<abs path> stop"  --arg touch_cmd "<abs path> touch"
# Existing hooks for either event are preserved; our entry is added only if a
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
