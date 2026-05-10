#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

info()  { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m⚠\033[0m %s\n' "$*"; }
err()   { printf '\033[31m✘\033[0m %s\n' "$*" >&2; }

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
if grep -q '"jcodemunch"' "$HOME/.claude.json" 2>/dev/null; then
  ok "MCP server already configured: jcodemunch"
else
  info "Adding jcodemunch MCP server..."
  if claude mcp add -s user jcodemunch -- uvx jcodemunch-mcp; then
    ok "Added MCP server: jcodemunch"
  else
    err "Failed to add jcodemunch MCP server"
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
  tmp=$(mktemp)
  jq -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$DOTFILES_DIR/config/settings.json" > "$tmp"
  mv "$tmp" "$CLAUDE_DIR/settings.json"
  ok "Merged settings.json"
else
  cp "$DOTFILES_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
  ok "Installed settings.json"
fi

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

for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  action="Installed"
  [ -d "$SKILLS_DIR/$skill_name" ] && [ -f "$SKILLS_DIR/$skill_name/SKILL.md" ] && action="Updated"
  mkdir -p "$SKILLS_DIR/$skill_name"
  cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
  # Copy bundled resources (scripts/, references/, assets/) if present
  for res_dir in scripts references assets; do
    if [ -d "$skill_dir/$res_dir" ]; then
      cp -r "$skill_dir/$res_dir" "$SKILLS_DIR/$skill_name/"
    fi
  done
  ok "$action skill: $skill_name"
done
echo

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

printf '\033[32m━━━ Setup complete ━━━\033[0m\n'
echo
echo "Installed:"
echo "  Plugins:     superpowers, impeccable, context-mode"
echo "  MCP servers: jcodemunch"
echo "  Skills:      adr, cloudagent, subagent-finder"
echo "  Statusline:  ~/.claude/statusline-command.sh"
echo "  Settings:    ~/.claude/settings.json"
echo "  Keybindings: ~/.claude/keybindings.json"
echo "  AGENTS.md:   decision memory layer"
echo
echo "Restart Claude Code for all changes to take effect."
