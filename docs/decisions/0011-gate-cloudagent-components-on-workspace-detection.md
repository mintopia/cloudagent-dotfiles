# Decision: Install cloudagent-specific components only in a Cloud Agent workspace

Status: accepted
Date: 2026-08-08

## Context

Several components these dotfiles install are only meaningful inside a Cloud
Agent workspace:

- the vendored `cloudagent` skill (CLI reference + workspace conventions),
- the `cloudagent-skill.sh` SessionStart hook (loads that skill),
- the `harmonic-start.sh` SessionStart hook and the Harmonic npx warm-up.

Both hooks already self-gate at runtime (they exit early when not in a Cloud
Agent workspace), so installing them elsewhere was harmless but pointless — it
left inert hooks wired into `settings.json` and a cloudagent skill in the skill
list on machines that can never use them. The install should not add them at all
off-platform.

`install.sh` is also used on non-Cloud-Agent machines, so the gate must be an
install-time decision, using the same detection the skill and hooks use.

## Decision

Detect a Cloud Agent workspace once at the top of `install.sh` — the `cloudagent`
CLI on `PATH` or the `CLOUDAGENT_API_URL` env var — into `IS_CLOUDAGENT`, and
install the cloudagent-specific components only when it is true.

- The Hooks section (both hooks + their wiring) and the Harmonic warm-up run
  only when `IS_CLOUDAGENT=true`; otherwise they are skipped with a notice.
- The skills loop skips the `cloudagent` skill directory when not in a Cloud
  Agent workspace (all other vendored skills still install).
- The setup summary omits the Hooks/Harmonic lines and notes the skip when not
  on-platform. The skills summary is filesystem-derived, so it drops `cloudagent`
  automatically.

Everything else (other skills, plugins, MCP, statusline, settings, output style,
keybindings, git) installs regardless of environment.

## Consequences

Off-platform installs are cleaner: no inert cloudagent hooks in `settings.json`,
no unusable cloudagent skill, no Harmonic. On a Cloud Agent workspace behaviour
is unchanged. The gate matches the runtime detection the hooks/skill already use,
so there is a single, consistent definition of "in a Cloud Agent workspace."

## Supersedes

None
