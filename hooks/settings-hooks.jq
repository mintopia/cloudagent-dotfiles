# Idempotently add our SessionStart hooks to settings:
#   - cloudagent-skill  (loads the cloudagent skill in Cloud Agent workspaces)
#   - harmonic-start    (starts Harmonic + its private HTTPS forward)
# Args: --arg session_start_cmd "<abs path to cloudagent-skill.sh>"
#       --arg harmonic_cmd       "<abs path to harmonic-start.sh>"
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
| add_hook("SessionStart"; $session_start_cmd)
| add_hook("SessionStart"; $harmonic_cmd)
