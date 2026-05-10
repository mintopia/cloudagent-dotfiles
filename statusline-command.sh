#!/usr/bin/env bash
input=$(cat)

SEP='\033[90m │ \033[0m'

# --- cwd ---
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
home="$HOME"
display_dir="${cwd/#$home/~}"

# --- git branch + dirty flag ---
git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
git_dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- context window ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- tokens: cumulative totals ---
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
total_tokens=$((total_in + total_out))

# --- tokens: current call breakdown (read/write/cached) ---
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
cur_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
cur_cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
cur_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')

# --- session cost estimate ---
# Input: $3/M, Output: $15/M, Cache write: $3.75/M, Cache read: $0.30/M
cost=$(echo "$total_in $total_out" | awk '{printf "%.2f", ($1/1000000)*3 + ($2/1000000)*15}')

# --- clock ---
clock=$(date +%H:%M:%S)

# helper: format a token count as Xk or X.XM
fmt_tok() {
  local n="$1"
  if   [ "$n" -ge 1000000 ]; then echo "$n" | awk '{printf "%.1fM", $1/1000000}'
  elif [ "$n" -ge 1000 ];    then echo "$n" | awk '{printf "%.1fk", $1/1000}'
  else echo "$n"
  fi
}

# ── Build output ──────────────────────────────────────────────────────────────

# cwd (cyan)
printf '\033[36m%s\033[0m' "$display_dir"

# git branch (yellow) + dirty marker (red asterisk)
if [ -n "$git_branch" ]; then
  printf '%b' "$SEP"
  printf '\033[33m(%s\033[0m' "$git_branch"
  if [ -n "$git_dirty" ]; then
    printf '\033[31m*\033[0m'
  fi
  printf '\033[33m)\033[0m'
fi

# model (magenta)
if [ -n "$model" ]; then
  printf '%b' "$SEP"
  printf '\033[35m%s\033[0m' "$model"
fi

# context bar chart (10 cells)
if [ -n "$used" ]; then
  filled=$(echo "$used" | awk '{n=int($1/10+0.5); if(n>10)n=10; print n}')
  empty=$((10 - filled))
  bar=""
  for i in $(seq 1 "$filled"); do bar="${bar}█"; done
  for i in $(seq 1 "$empty");  do bar="${bar}░"; done
  pct=$(printf '%.0f' "$used")
  # colour: green <50, yellow <80, red >=80
  if   [ "$pct" -ge 80 ]; then color='\033[31m'
  elif [ "$pct" -ge 50 ]; then color='\033[33m'
  else                         color='\033[32m'
  fi
  printf '%b' "$SEP"
  printf "${color}[%s] %s%%\033[0m" "$bar" "$pct"
fi

# tokens section
if [ "$total_tokens" -gt 0 ] || [ -n "$cur_input" ]; then
  printf '%b' "$SEP"

  # cumulative totals (dim white)
  if [ "$total_tokens" -gt 0 ]; then
    tok_display=$(fmt_tok "$total_tokens")
    printf '\033[90m%s tok\033[0m' "$tok_display"
  fi

  # per-call breakdown: read (green) / write (yellow) / cached (blue)
  if [ -n "$cur_input" ] && [ "$cur_input" -gt 0 ]; then
    r=$(fmt_tok "$cur_input")
    printf ' \033[32m↑%s\033[0m' "$r"
  fi
  if [ -n "$cur_output" ] && [ "$cur_output" -gt 0 ]; then
    w=$(fmt_tok "$cur_output")
    printf ' \033[33m↓%s\033[0m' "$w"
  fi
  if [ -n "$cur_cache_write" ] && [ "$cur_cache_write" -gt 0 ]; then
    cw=$(fmt_tok "$cur_cache_write")
    printf ' \033[34m✎%s\033[0m' "$cw"
  fi
  if [ -n "$cur_cache_read" ] && [ "$cur_cache_read" -gt 0 ]; then
    cr=$(fmt_tok "$cur_cache_read")
    printf ' \033[34m⚡%s\033[0m' "$cr"
  fi
fi

# session cost (green)
printf '%b' "$SEP"
printf '\033[32m$%s\033[0m' "$cost"

# clock (cyan)
printf '%b' "$SEP"
printf '\033[36m%s\033[0m' "$clock"
