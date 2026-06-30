#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

info()  { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m⚠\033[0m %s\n' "$*"; }
err()   { printf '\033[31m✘\033[0m %s\n' "$*" >&2; }

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

# --- Marketplaces -----------------------------------------------------------
info "Configuring plugin marketplaces..."
add_marketplace "pbakaus/impeccable"    "impeccable"
add_marketplace "mksglu/context-mode"   "context-mode"
echo

# --- Plugins ----------------------------------------------------------------
info "Installing plugins..."
install_plugin "superpowers"   "claude-plugins-official"
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
echo "  Plugins:     superpowers, impeccable, context-mode"
echo "  MCP servers: jcodemunch"
echo "  Skills:      $skills_joined"
echo "  Skills (mp): engineering + productivity categories ($(printf '%s' "$MATT_SKILLS" | wc -w) skills)"
echo "  Hooks:       night-handoff (overnight handoff), cloudagent-skill (session-start)"
echo "  Statusline:  ~/.claude/statusline-command.sh"
echo "  Settings:    ~/.claude/settings.json"
echo "  Keybindings: ~/.claude/keybindings.json"
echo "  AGENTS.md:   decision memory layer"
echo "  Git:         Jessica Smith <jess@mintopia.net>"
echo
echo "Restart Claude Code for all changes to take effect."
