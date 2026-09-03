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
  # impeccable is now installed as an npx skill, not a plugin.
  "impeccable@impeccable"
)
# The impeccable marketplace was added by this script solely for the impeccable
# plugin; nothing else needs it now that impeccable is an npx skill, so retire
# it. (superpowers came from claude-plugins-official, which is shared and stays.)
DEPRECATED_MARKETPLACES=(
  "impeccable"
)
DEPRECATED_SKILLS=(
  "local-llm-development"
  "quality-gate"
  # caveman family (dropped in v2) — confirmed via
  # `npx skills add JuliusBrussee/caveman --list`
  "caveman"
  "caveman-commit"
  "caveman-review"
  "caveman-compress"
  "caveman-stats"
  "cavecrew"
  "caveman-help"
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

# Detect a Cloud Agent workspace the same way the skill and hooks do: the
# `cloudagent` CLI on PATH or the CLOUDAGENT_API_URL env var. The cloudagent
# skill, the cloudagent-skill + harmonic-start hooks, and the Harmonic warm-up
# are installed ONLY in that environment; elsewhere they are skipped.
if command -v cloudagent >/dev/null 2>&1 || [ -n "${CLOUDAGENT_API_URL:-}" ]; then
  IS_CLOUDAGENT=true
  info "Cloud Agent workspace detected — cloudagent skill/hooks + Harmonic will install"
else
  IS_CLOUDAGENT=false
  warn "No Cloud Agent workspace detected — skipping cloudagent skill/hooks + Harmonic"
fi
echo

# Purge before installing, so a removal can never race a fresh install.
if [ "$CLEANUP" = true ]; then
  run_cleanup
fi

# --- Marketplaces -----------------------------------------------------------
info "Configuring plugin marketplaces..."
add_marketplace "mksglu/context-mode"   "context-mode"
echo

# --- Plugins ----------------------------------------------------------------
# impeccable is installed as an npx skill (see Skills), not a plugin.
# context-mode stays a plugin: its skills wrap the ctx_* MCP server and a
# PreToolUse routing hook that only the plugin provides.
info "Installing plugins..."
install_plugin "context-mode"  "context-mode"
install_plugin "frontend-design" "claude-plugins-official"
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
# npm global dependencies
# ---------------------------------------------------------------------------

info "Installing npm global dependencies..."
if command -v npm &>/dev/null; then
  # @openai/codex — the OpenAI Codex CLI, used by codex-review and the
  # tsmura grill/codex skills. Idempotent: skip if already on PATH.
  if command -v codex &>/dev/null; then
    ok "Already installed: @openai/codex"
  else
    info "Installing @openai/codex..."
    if npm install -g @openai/codex; then
      ok "Installed: @openai/codex"
    else
      err "Failed to install @openai/codex"
    fi
  fi
else
  err "npm not found — cannot install @openai/codex"
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
# Output style — "I Have ADHD"
# ---------------------------------------------------------------------------
# Installed as a native Claude Code output style: the file goes in
# ~/.claude/output-styles/, and config/settings.json sets "outputStyle" to make
# it the active style (merged into ~/.claude/settings.json in the Settings step).

info "Installing output style..."
OUTPUT_STYLES_DIR="$CLAUDE_DIR/output-styles"
mkdir -p "$OUTPUT_STYLES_DIR"
cp "$DOTFILES_DIR/config/output-styles/i-have-adhd.md" "$OUTPUT_STYLES_DIR/i-have-adhd.md"
ok "Installed output style: I Have ADHD"
echo

# ---------------------------------------------------------------------------
# Hooks (Cloud Agent workspaces only)
# ---------------------------------------------------------------------------
# Both hooks are cloudagent-specific — cloudagent-skill loads the cloudagent
# skill, harmonic-start manages Harmonic + its private forward — so they are
# installed and wired only inside a Cloud Agent workspace.

if [ "$IS_CLOUDAGENT" = true ]; then
  info "Installing hooks..."
  HOOKS_DIR="$CLAUDE_DIR/hooks"
  mkdir -p "$HOOKS_DIR"

  cp "$DOTFILES_DIR/hooks/cloudagent-skill.sh" "$HOOKS_DIR/cloudagent-skill.sh"
  chmod +x "$HOOKS_DIR/cloudagent-skill.sh"
  ok "Installed cloudagent-skill.sh"

  cp "$DOTFILES_DIR/hooks/harmonic-start.sh" "$HOOKS_DIR/harmonic-start.sh"
  chmod +x "$HOOKS_DIR/harmonic-start.sh"
  ok "Installed harmonic-start.sh"

  # Wire the SessionStart hooks idempotently, preserving any existing hooks.
  # Absolute paths are machine-specific, so this is done here (not in
  # config/settings.json) and is safe to re-run.
  SESSION_START_CMD="$HOOKS_DIR/cloudagent-skill.sh"
  HARMONIC_CMD="$HOOKS_DIR/harmonic-start.sh"
  jq_write "$CLAUDE_DIR/settings.json" \
     --arg session_start_cmd "$SESSION_START_CMD" \
     --arg harmonic_cmd "$HARMONIC_CMD" \
     -f "$DOTFILES_DIR/hooks/settings-hooks.jq" \
     "$CLAUDE_DIR/settings.json"
  ok "Wired cloudagent-skill + harmonic-start hooks into settings.json"
  echo

  # --- Harmonic: warm the npx build ---
  # Harmonic runs straight from GitHub via npx; its first run clones and builds
  # (~1-2 min). Prime that once now so the harmonic-start SessionStart hook
  # starts instantly on the first real session. Best-effort: if this fails
  # (offline, etc.) the hook still builds on first use.
  info "Warming Harmonic npx build (first run clones + builds, ~1-2 min)..."
  if command -v npx &>/dev/null; then
    # `status` exits non-zero when no daemon is running, which is expected at
    # install time — the npx clone+build (the point of warming) still happens.
    # So don't treat its exit code as a build failure.
    npx -y github:mintopia/harmonic status >/dev/null 2>&1 || true
    ok "Harmonic build warmed (no daemon running yet, as expected)"
  else
    warn "npx not found — skipping Harmonic warm-up"
  fi
  echo
else
  info "Skipping hooks + Harmonic (not a Cloud Agent workspace)"
  echo
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

# Local skills from this dotfiles repo. Collect names so the summary below is
# derived from the filesystem rather than a hand-maintained (drift-prone) list.
INSTALLED_SKILLS=()
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  # The cloudagent skill is only useful in a Cloud Agent workspace.
  if [ "$skill_name" = "cloudagent" ] && [ "$IS_CLOUDAGENT" != true ]; then
    info "Skipping cloudagent skill (not a Cloud Agent workspace)"
    continue
  fi
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

# mattpocock/skills — install by explicit name. (mattpocock-skills also exists
# as a plugin in claude-plugins-official, but the npx-where-possible rule keeps
# it on npx.) We name each skill instead of using --skill '*' (a.k.a. --all):
# the glob-all install fails most of the time. Refresh this list with:
#   npx skills add mattpocock/skills --list
MATTPOCOCK_SKILLS=(
  ask-matt
  claude-handoff
  code-review
  codebase-design
  diagnosing-bugs
  domain-modeling
  git-guardrails-claude-code
  grill-me
  grill-with-docs
  grilling
  handoff
  implement
  improve-codebase-architecture
  loop-me
  migrate-to-shoehorn
  prototype
  research
  resolving-merge-conflicts
  scaffold-exercises
  setup-matt-pocock-skills
  setup-pre-commit
  setup-ts-deep-modules
  tdd
  teach
  to-questionnaire
  to-spec
  to-tickets
  triage
  wait-what
  wayfinder
  wizard
  writing-beats
  writing-for-agents
  writing-fragments
  writing-shape
)
mp_skill_flags=()
for s in "${MATTPOCOCK_SKILLS[@]}"; do
  mp_skill_flags+=(--skill "$s")
done
info "Installing ${#MATTPOCOCK_SKILLS[@]} mattpocock/skills by name..."
if npx -y skills add mattpocock/skills "${mp_skill_flags[@]}" -g -y --copy; then
  ok "Installed mattpocock/skills (${#MATTPOCOCK_SKILLS[@]} named)"
else
  err "Failed to install mattpocock/skills"
fi
echo

# pstack (cursor/plugins) — install four skills UNCHANGED from upstream by name.
# These need no Cursor->Claude rework, so they track upstream instead of being
# vendored. The rework-heavy pstack skills (why, interrogate, create-verification-
# skill, maintain-verification-skill, reflect) are vendored as first-party skills
# under skills/ instead — see ADR 0012. cursor/plugins is a monorepo of ~79 skills;
# we name the four we want. Refresh the available list with:
#   npx skills add cursor/plugins --list
PSTACK_SKILLS=(
  unslop
  blast-radius
  typescript-best-practices
  show-me-your-work
)
pstack_skill_flags=()
for s in "${PSTACK_SKILLS[@]}"; do
  pstack_skill_flags+=(--skill "$s")
done
info "Installing ${#PSTACK_SKILLS[@]} pstack skills by name (unchanged from upstream)..."
if npx -y skills add cursor/plugins "${pstack_skill_flags[@]}" -g -y --copy; then
  ok "Installed pstack skills (${#PSTACK_SKILLS[@]} named)"
else
  err "Failed to install pstack skills"
fi
echo

# Third-party skills installed via npx. The whole set is pulled from each repo
# — no --skill filter. impeccable moved here from a plugin (it is a single
# self-contained skill with no MCP/hooks).
declare -A THIRDPARTY_SKILLS=(
  [pbakaus/impeccable]="impeccable skill"
  [DietrichGebert/ponytail]="ponytail family"
  [tsmura/grill-me-codex]="grill + codex-plan-review family"
  [petergyang/no-ai-slop]="no-ai-slop skill"
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
echo "  Plugins:     context-mode, frontend-design"
echo "  MCP servers: jcodemunch"
echo "  npm:         @openai/codex"
echo "  Skills:      $skills_joined"
echo "  Skills (mp): ${#MATTPOCOCK_SKILLS[@]} mattpocock/skills (named)"
echo "  Skills (ps): ${#PSTACK_SKILLS[@]} pstack skills (named, unchanged from upstream)"
echo "  Skills (3p): impeccable, ponytail family, tsmura grill/codex family, no-ai-slop (via npx skills)"
if [ "$IS_CLOUDAGENT" = true ]; then
  echo "  Hooks:       cloudagent-skill (session-start), harmonic-start (session-start)"
fi
echo "  Output style: I Have ADHD (~/.claude/output-styles, active via settings)"
if [ "$IS_CLOUDAGENT" = true ]; then
  echo "  Harmonic:    auto-starts + private HTTPS forward (hostname 'harmonic', port 4700)"
else
  echo "  (cloudagent skill, hooks + Harmonic skipped — not a Cloud Agent workspace)"
fi
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
