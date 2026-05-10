#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${HOME}/.cache/awesome-claude-code-subagents"
REPO_URL="https://github.com/VoltAgent/awesome-claude-code-subagents.git"
MAX_AGE_HOURS=24

usage() {
  echo "Usage: $0 <keyword> [keyword...]"
  echo ""
  echo "Searches the awesome-claude-code-subagents catalog by keyword."
  echo "Returns matching agents with name, category, description, and model."
  echo ""
  echo "Examples:"
  echo "  $0 security audit"
  echo "  $0 frontend react"
  echo "  $0 database migration"
  exit 1
}

[ $# -eq 0 ] && usage

ensure_repo() {
  if [ -d "$CACHE_DIR/.git" ]; then
    local last_fetch
    last_fetch=$(stat -c %Y "$CACHE_DIR/.git/FETCH_HEAD" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local age=$(( (now - last_fetch) / 3600 ))
    if [ "$age" -ge "$MAX_AGE_HOURS" ]; then
      git -C "$CACHE_DIR" pull --quiet 2>/dev/null || true
    fi
  else
    mkdir -p "$CACHE_DIR"
    git clone --depth 1 --quiet "$REPO_URL" "$CACHE_DIR" 2>/dev/null
  fi
}

extract_frontmatter() {
  local file="$1"
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file"
}

extract_field() {
  local frontmatter="$1"
  local field="$2"
  echo "$frontmatter" | grep -E "^${field}:" | sed "s/^${field}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/'
}

ensure_repo

keywords=("$@")
pattern=$(IFS='|'; echo "${keywords[*]}")

results=()

for agent_file in "$CACHE_DIR"/categories/*/[!R]*.md; do
  [ -f "$agent_file" ] || continue

  fm=$(extract_frontmatter "$agent_file")
  name=$(extract_field "$fm" "name")
  description=$(extract_field "$fm" "description")
  model=$(extract_field "$fm" "model")
  tools=$(extract_field "$fm" "tools")

  searchable="${name} ${description}"
  searchable_lower=$(echo "$searchable" | tr '[:upper:]' '[:lower:]')
  pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')

  match_count=0
  for kw in "${keywords[@]}"; do
    kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
    if echo "$searchable_lower" | grep -qi "$kw_lower"; then
      match_count=$((match_count + 1))
    fi
  done

  if [ "$match_count" -gt 0 ]; then
    category_dir=$(basename "$(dirname "$agent_file")")
    category=$(echo "$category_dir" | sed 's/^[0-9]*-//' | tr '-' ' ')
    results+=("${match_count}|${name}|${category}|${model}|${description}|${agent_file}")
  fi
done

if [ ${#results[@]} -eq 0 ]; then
  echo "No agents found matching: $*"
  echo ""
  echo "Available categories:"
  for cat_dir in "$CACHE_DIR"/categories/*/; do
    cat_name=$(basename "$cat_dir" | sed 's/^[0-9]*-//' | tr '-' ' ')
    count=$(find "$cat_dir" -name "*.md" ! -name "README.md" | wc -l)
    echo "  - ${cat_name} (${count} agents)"
  done
  exit 0
fi

IFS=$'\n' sorted=($(printf '%s\n' "${results[@]}" | sort -t'|' -k1 -rn))
unset IFS

echo "## Matching Agents"
echo ""

shown=0
for entry in "${sorted[@]}"; do
  [ "$shown" -ge 5 ] && break
  IFS='|' read -r score name category model description filepath <<< "$entry"
  echo "### ${name}"
  echo "- **Category:** ${category}"
  echo "- **Model:** ${model}"
  echo "- **Tools:** $(extract_field "$(extract_frontmatter "$filepath")" "tools")"
  echo "- **Description:** ${description}"
  echo "- **File:** ${filepath}"
  echo ""
  shown=$((shown + 1))
done

remaining=$(( ${#sorted[@]} - shown ))
if [ "$remaining" -gt 0 ]; then
  echo "_${remaining} more matches not shown. Refine your search to narrow results._"
fi
