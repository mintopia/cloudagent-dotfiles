#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

info()  { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m⚠\033[0m %s\n' "$*"; }
err()   { printf '\033[31m✘\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [--cleanup]

  --cleanup   Also purge components these dotfiles used to install but have
              since dropped (see the DEPRECATED_* lists in this script).
              Off by default: a plain run only adds and updates, never removes.
  -h, --help  Show this help.
EOF
}

CLEANUP=false
while [ $# -gt 0 ]; do
  case "$1" in
    --cleanup)  CLEANUP=true ;;
    -h|--help)  usage; exit 0 ;;
    *)          err "Unknown option: $1"; echo; usage; exit 1 ;;
  esac
  shift
done

# Atomically transform a JSON file with jq. The result is written to a temp file
# and only moved over <target> if jq succeeds AND produced non-empty output —
# so a jq error or empty result can never truncate the user's settings. Aborts
# loudly (leaving <target> untouched) on failure.
# Usage: jq_write <target> <jq args...>   (include the input file in the args)
jq_write() {
  local target="$1"; shift
  local tmp; tmp=$(mktemp)
  if jq "$@" > "$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$target"
  else
    rm -f "$tmp"
    err "Failed to update $target via jq; left it unchanged"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Cleanup (--cleanup)
# ---------------------------------------------------------------------------

# Components these dotfiles once installed but have since dropped. Retiring
# something in future means adding one line to the relevant list here.
DEPRECATED_PLUGINS=(
  "superpowers@claude-plugins-official"
)
# Empty: superpowers came from claude-plugins-official, which is shared with
# other installed plugins and must stay. Only add a marketplace here if this
# script added it and nothing else needs it.
DEPRECATED_MARKETPLACES=()
DEPRECATED_SKILLS=(
  "local-llm-development"
)

# Entries must be fully qualified (plugin@marketplace) so the cache path below
# can be derived unambiguously.
remove_plugin() {
  local plugin="$1"
  case "$plugin" in
    *@*) ;;
    *)   err "Expected plugin@marketplace, got: '$plugin'"; return ;;
  esac
  local name="${plugin%@*}" marketplace="${plugin##*@}"
  case "$name$marketplace" in
    *[/[:space:]]*|'') err "Refusing unsafe plugin spec: '$plugin'"; return ;;
  esac

  if claude plugin list 2>/dev/null | grep -q "$plugin"; then
    info "Uninstalling plugin: $plugin"
    if claude plugin uninstall "$plugin"; then
      ok "Uninstalled: $plugin"
    else
      err "Failed to uninstall plugin: $plugin"
    fi
  else
    ok "Plugin not installed: $plugin"
  fi

  # `claude plugin uninstall` clears the registry entry and the data dir but
  # leaves the downloaded plugin in the marketplace cache — megabytes per plugin,
  # for something we are never reinstalling. Best-effort by design: the cache is
  # regenerable, so if the layout ever changes this silently does nothing rather
  # than failing the run. The marketplace itself is left alone; other plugins
  # usually still need it.
  local cache="$CLAUDE_DIR/plugins/cache/$marketplace/$name"
  if [ -d "$cache" ]; then
    rm -rf "$cache"
    ok "Purged plugin cache: $marketplace/$name"
  fi
}

remove_marketplace() {
  local name="$1"
  if ! claude plugin marketplace list 2>/dev/null | grep -q "$name"; then
    ok "Marketplace not configured: $name"
    return
  fi
  info "Removing marketplace: $name"
  if claude plugin marketplace remove "$name"; then
    ok "Removed marketplace: $name"
  else
    err "Failed to remove marketplace: $name"
  fi
}

# Delete an installed skill directory (or symlink) from ~/.claude/skills.
# The name is validated first: an empty or path-bearing entry would otherwise
# let `rm -rf` escape the skill directory it is meant to be confined to.
remove_skill() {
  local name="$1"
  case "$name" in
    ''|.|..|*/*)
      err "Refusing to remove unsafe skill name: '$name'"
      return
      ;;
  esac
  local target="$CLAUDE_DIR/skills/$name"
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    ok "Skill not installed: $name"
    return
  fi
  info "Removing skill: $name"
  rm -rf "$target"
  ok "Removed skill: $name"
}

run_cleanup() {
  info "Purging deprecated components..."
  local item
  for item in "${DEPRECATED_PLUGINS[@]}";      do remove_plugin "$item";      done
  for item in "${DEPRECATED_MARKETPLACES[@]}"; do remove_marketplace "$item"; done
  for item in "${DEPRECATED_SKILLS[@]}";       do remove_skill "$item";       done
  echo
}

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

install_plugin() {
  local name="$1" marketplace="$2"
  if claude plugin list 2>/dev/null | grep -q "$name@$marketplace"; then
    ok "Plugin already installed: $name"
    return
  fi
  info "Installing plugin: $name from $marketplace"
  if claude plugin install "$name@$marketplace"; then
    ok "Installed: $name"
  else
    err "Failed to install plugin: $name"
  fi
}

add_marketplace() {
  local repo="$1" name="$2"
  if claude plugin marketplace list 2>/dev/null | grep -q "$name"; then
    ok "Marketplace already added: $name"
    return
  fi
  info "Adding marketplace: $repo"
  if claude plugin marketplace add "$repo"; then
    ok "Added marketplace: $name"
  else
    err "Failed to add marketplace: $repo"
  fi
}

info "Setting up Cloud Agent dotfiles..."
echo

# Purge before installing, so a removal can never race a fresh install.
if [ "$CLEANUP" = true ]; then
  run_cleanup
fi

# --- Marketplaces -----------------------------------------------------------
info "Configuring plugin marketplaces..."
add_marketplace "pbakaus/impeccable"    "impeccable"
add_marketplace "mksglu/context-mode"   "context-mode"
echo

# --- Plugins ----------------------------------------------------------------
info "Installing plugins..."
install_plugin "impeccable"    "impeccable"
install_plugin "context-mode"  "context-mode"
echo

# ---------------------------------------------------------------------------
# MCP Servers
# ---------------------------------------------------------------------------

info "Configuring MCP servers..."

JCODEMUNCH_REPO="https://github.com/jgravelle/jcodemunch-mcp.git"

if command -v pipx &>/dev/null; then
  JCODEMUNCH_CMD="pipx"
elif command -v pip &>/dev/null; then
  JCODEMUNCH_CMD="pip"
else
  err "Neither pipx nor pip found — cannot install jcodemunch-mcp"
  JCODEMUNCH_CMD=""
fi

if [ -n "$JCODEMUNCH_CMD" ]; then
  info "Installing jcodemunch-mcp via $JCODEMUNCH_CMD from $JCODEMUNCH_REPO..."
  if "$JCODEMUNCH_CMD" install "git+$JCODEMUNCH_REPO" 2>/dev/null; then
    ok "Installed jcodemunch-mcp via $JCODEMUNCH_CMD"
  else
    warn "jcodemunch-mcp may already be installed, continuing..."
  fi

  if grep -q '"jcodemunch"' "$HOME/.claude.json" 2>/dev/null; then
    ok "MCP server already configured: jcodemunch"
  else
    info "Adding jcodemunch MCP server..."
    if claude mcp add -s user jcodemunch -- jcodemunch-mcp; then
      ok "Added MCP server: jcodemunch"
    else
      err "Failed to add jcodemunch MCP server"
    fi
  fi
fi
echo

# ---------------------------------------------------------------------------
# Statusline
# ---------------------------------------------------------------------------

info "Setting up statusline..."
cp "$DOTFILES_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
ok "Statusline installed"
echo

# ---------------------------------------------------------------------------
# Settings & Keybindings
# ---------------------------------------------------------------------------

info "Configuring Claude Code settings..."

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  # Merge dotfile settings into existing settings (dotfile values win)
  jq_write "$CLAUDE_DIR/settings.json" \
    -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$DOTFILES_DIR/config/settings.json"
  ok "Merged settings.json"
else
  cp "$DOTFILES_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
  ok "Installed settings.json"
fi

# Wire the statusline into settings.json with the absolute installed path.
# Done here (not in config/settings.json) because the path is machine-specific;
# setting the key every run keeps it idempotent.
jq_write "$CLAUDE_DIR/settings.json" \
   --arg cmd "$CLAUDE_DIR/statusline-command.sh" \
   '.statusLine = {type: "command", command: $cmd}' \
   "$CLAUDE_DIR/settings.json"
ok "Wired statusline into settings.json"

# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

info "Installing hooks..."
HOOKS_DIR="$CLAUDE_DIR/hooks"
mkdir -p "$HOOKS_DIR"
cp "$DOTFILES_DIR/hooks/night-handoff.sh" "$HOOKS_DIR/night-handoff.sh"
chmod +x "$HOOKS_DIR/night-handoff.sh"
ok "Installed night-handoff.sh"

cp "$DOTFILES_DIR/hooks/cloudagent-skill.sh" "$HOOKS_DIR/cloudagent-skill.sh"
chmod +x "$HOOKS_DIR/cloudagent-skill.sh"
ok "Installed cloudagent-skill.sh"

# Wire the Stop / UserPromptSubmit / SessionStart hooks idempotently, preserving
# any existing hooks. Absolute paths are machine-specific, so this is done here
# (not in config/settings.json) and is safe to re-run.
STOP_CMD="$HOOKS_DIR/night-handoff.sh stop"
TOUCH_CMD="$HOOKS_DIR/night-handoff.sh touch"
SESSION_START_CMD="$HOOKS_DIR/cloudagent-skill.sh"
jq_write "$CLAUDE_DIR/settings.json" \
   --arg stop_cmd "$STOP_CMD" --arg touch_cmd "$TOUCH_CMD" \
   --arg session_start_cmd "$SESSION_START_CMD" \
   -f "$DOTFILES_DIR/hooks/settings-hooks.jq" \
   "$CLAUDE_DIR/settings.json"
ok "Wired night-handoff + cloudagent-skill hooks into settings.json"
echo

cp "$DOTFILES_DIR/config/keybindings.json" "$CLAUDE_DIR/keybindings.json"
ok "Installed keybindings.json"
echo

# ---------------------------------------------------------------------------
# AGENTS.md — append decision-memory block
# ---------------------------------------------------------------------------

info "Updating user AGENTS.md..."
AGENTS_FILE="$CLAUDE_DIR/AGENTS.md"
MARKER="## Decision Memory"

if [ -f "$AGENTS_FILE" ] && grep -qF "$MARKER" "$AGENTS_FILE"; then
  ok "Decision memory section already present in AGENTS.md"
else
  if [ ! -f "$AGENTS_FILE" ]; then
    touch "$AGENTS_FILE"
  fi
  cat "$DOTFILES_DIR/config/agents-append.md" >> "$AGENTS_FILE"
  ok "Appended decision memory section to AGENTS.md"
fi
echo

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

info "Installing skills..."
SKILLS_DIR="$CLAUDE_DIR/skills"
mkdir -p "$SKILLS_DIR"

# Local skills from this dotfiles repo. Collect names so the summary below is
# derived from the filesystem rather than a hand-maintained (drift-prone) list.
INSTALLED_SKILLS=()
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  action="Installed"
  [ -d "$SKILLS_DIR/$skill_name" ] && [ -f "$SKILLS_DIR/$skill_name/SKILL.md" ] && action="Updated"
  mkdir -p "$SKILLS_DIR/$skill_name"
  cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
  # Copy additional markdown files (prompt templates, etc.)
  find "$skill_dir" -maxdepth 1 -name '*.md' ! -name 'SKILL.md' -exec cp {} "$SKILLS_DIR/$skill_name/" \;
  # Copy bundled resources (scripts/, references/, assets/) if present
  for res_dir in scripts references assets; do
    if [ -d "$skill_dir/$res_dir" ]; then
      cp -r "$skill_dir/$res_dir" "$SKILLS_DIR/$skill_name/"
    fi
  done
  ok "$action skill: $skill_name"
  INSTALLED_SKILLS+=("$skill_name")
done

# mattpocock/skills — the full engineering + productivity categories via npx.
# (setup-matt-pocock-skills is omitted: it is the upstream installer meta-skill,
# redundant with this script.)
MATT_ENGINEERING="ask-matt codebase-design diagnosing-bugs domain-modeling \
grill-with-docs implement improve-codebase-architecture prototype \
resolving-merge-conflicts tdd to-issues to-prd triage"
MATT_PRODUCTIVITY="grill-me grilling handoff teach writing-great-skills"
MATT_SKILLS="$MATT_ENGINEERING $MATT_PRODUCTIVITY"
info "Installing mattpocock/skills: $MATT_SKILLS"
if npx -y skills add mattpocock/skills \
    --skill $MATT_SKILLS \
    -g -y --copy; then
  ok "Installed mattpocock/skills"
else
  err "Failed to install mattpocock/skills"
fi
echo

# Third-party skill families installed via npx (previously vendored verbatim).
# caveman (Julius Brussee) and ponytail (DietrichGebert), both MIT. The whole
# family is pulled from each repo — no --skill filter.
declare -A THIRDPARTY_SKILLS=(
  [JuliusBrussee/caveman]="caveman family"
  [DietrichGebert/ponytail]="ponytail family"
)
for repo in "${!THIRDPARTY_SKILLS[@]}"; do
  label="${THIRDPARTY_SKILLS[$repo]}"
  info "Installing $repo ($label)..."
  if npx -y skills add "$repo" -g -y --copy; then
    ok "Installed $repo"
  else
    err "Failed to install $repo"
  fi
done
echo

# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------

info "Configuring git..."
git config --global user.name "Jessica Smith"
git config --global user.email "jess@mintopia.net"
ok "Git user: Jessica Smith <jess@mintopia.net>"
echo

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

printf '\033[32m━━━ Setup complete ━━━\033[0m\n'
echo
# Join the collected skill names as "a, b, c" (derived, never drifts).
skills_joined=$(printf ', %s' "${INSTALLED_SKILLS[@]}"); skills_joined=${skills_joined:2}
echo "Installed:"
echo "  Plugins:     impeccable, context-mode"
echo "  MCP servers: jcodemunch"
echo "  Skills:      $skills_joined"
echo "  Skills (mp): engineering + productivity categories ($(printf '%s' "$MATT_SKILLS" | wc -w) skills)"
echo "  Skills (3p): caveman family, ponytail family (via npx skills)"
echo "  Hooks:       night-handoff (overnight handoff), cloudagent-skill (session-start)"
echo "  Statusline:  ~/.claude/statusline-command.sh"
echo "  Settings:    ~/.claude/settings.json"
echo "  Keybindings: ~/.claude/keybindings.json"
echo "  AGENTS.md:   decision memory layer"
echo "  Git:         Jessica Smith <jess@mintopia.net>"
# Derived from the DEPRECATED_* lists rather than hand-maintained, so the
# summary tracks the lists automatically.
if [ "$CLEANUP" = true ]; then
  purged_joined=$(printf ', %s' \
    "${DEPRECATED_PLUGINS[@]}" "${DEPRECATED_MARKETPLACES[@]}" "${DEPRECATED_SKILLS[@]}")
  echo
  echo "Purged (--cleanup):"
  echo "  ${purged_joined:2}"
fi
echo
echo "Restart Claude Code for all changes to take effect."
