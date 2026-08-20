#!/usr/bin/env bash
# Ground-truth skill catalogue for /ask-jess.
# Lists every installed skill (name + description) from ~/.claude/skills so the
# router can enumerate what's ACTUALLY present rather than trust a hand-list.
set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

[ -d "$SKILLS_DIR" ] || { echo "No skills dir at $SKILLS_DIR" >&2; exit 1; }

count=0
for d in "$SKILLS_DIR"/*/; do
  f="$d/SKILL.md"
  [ -f "$f" ] || continue
  # Read frontmatter (between the first two --- lines).
  name=$(awk '/^---/{c++;next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,"");print;exit}' "$f")
  # Grab description. Handle folded/literal scalars (`description: >` or `|`) by
  # falling through to the first indented continuation line.
  desc=$(awk '
    /^---/{c++; next}
    c==1 && /^description:/{
      sub(/^description:[[:space:]]*/,""); v=$0
      if (v ~ /^[>|][0-9+-]*[[:space:]]*$/) { grab=1; next }
      print v; exit
    }
    c==1 && grab && /[^[:space:]]/{ sub(/^[[:space:]]+/,""); print; exit }
  ' "$f")
  [ -n "$name" ] || name=$(basename "$d")
  # Trim surrounding quotes and clip long descriptions.
  desc=${desc#\"}; desc=${desc%\"}
  [ "${#desc}" -gt 160 ] && desc="${desc:0:157}..."
  printf '%-32s %s\n' "$name" "$desc"
  count=$((count + 1))
done | sort

echo
echo "$count skills in $SKILLS_DIR" >&2
