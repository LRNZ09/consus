#!/bin/sh
# Claude Code status line — mirrors the default fish prompt style
# Input: JSON via stdin

input=$(cat)

user=$(whoami)
host=$(hostname -s)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir=$(pwd)
# Shorten home directory to ~
dir=$(echo "$dir" | sed "s|^$HOME|~|")

model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build context info
ctx=""
[ -n "$used" ] && ctx=$(printf " ctx:%.0f%%" "$used")

# Rate limits (optional)
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
limits=""
[ -n "$five" ] && limits=$(printf " 5h:%.0f%%" "$five")
[ -n "$week" ] && limits=$(printf "%s 7d:%.0f%%" "$limits" "$week")

printf "\033[32m%s@%s\033[0m \033[34m%s\033[0m\033[33m%s%s%s\033[0m" \
  "$user" "$host" "$dir" \
  "${model:+ [$model]}" "$ctx" "$limits"
