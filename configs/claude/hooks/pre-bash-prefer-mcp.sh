#!/usr/bin/env bash
# PreToolUse hook on Bash: when a CLI that has a connected MCP equivalent is about
# to run, remind to prefer the MCP and surface the relevant memory files.
#
# The set of CLIs is data-driven — see cli-mcp-map.tsv next to this script. The
# logic here is generic; add a row to the map to cover a new tool.
# Detects the CLI even when it sits inside a pipe / ; / & chain.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAP_FILE="$SCRIPT_DIR/cli-mcp-map.tsv"

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')
[ -z "$command" ] && exit 0
[ -f "$MAP_FILE" ] || exit 0

# Drop leading env-var assignments (e.g. `FOO=bar cmd ...`)
command=$(echo "$command" | sed -E 's/^([A-Z_][A-Z0-9_]*=[^ ]+ +)+//')

# Look a CLI up in the map. Prints the MCP label and exits 0 on a hit, else 1.
# Tolerates tab- or space-separated rows; ignores comments/blank lines.
mcp_for() {
  awk -v cli="$1" '
    /^[[:space:]]*#/ || !NF { next }
    $1 == cli {
      label = $0
      sub(/^[^[:space:]]+[[:space:]]+/, "", label)
      print label
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }
  ' "$MAP_FILE"
}

# Walk the chain (split on | ; &); fire on the first segment whose leading
# command is in the map.
cli=""
mcp=""
while IFS= read -r seg; do
  first=$(awk '{print $1}' <<<"$seg")
  [ -z "$first" ] && continue
  if mcp=$(mcp_for "$first"); then
    cli="$first"
    break
  fi
done < <(tr '|;&' '\n' <<<"$command")

[ -z "$cli" ] && exit 0

# Global memory + this project's memory dir, derived from the hook's cwd
# (~/.claude/projects/<sanitized-cwd>/memory) so it works in any repo.
cwd=$(echo "$input" | jq -r '.cwd // ""')
MEM_DIRS=("$HOME/.claude/memory")
[ -n "$cwd" ] && MEM_DIRS+=("$HOME/.claude/projects/$(printf %s "$cwd" | sed 's#[^a-zA-Z0-9]#-#g')/memory")

# Surface the "prefer MCP over CLI" principle plus any memory naming this CLI.
matches=()
for d in "${MEM_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] && matches+=("$f")
  done < <(grep -l -i -E -e 'prefer.{0,40}mcp' -e "\\b$cli\\b" "$d"/*.md 2>/dev/null | grep -v '/MEMORY\.md$' || true)
done

ctx=$(printf '%s\n' "${matches[@]+"${matches[@]}"}" | awk 'NF && !seen[$0]++' | while IFS= read -r f; do
  desc=$(grep -m1 -E '^description:' "$f" 2>/dev/null | sed 's/^description: *//')
  echo "- $f"
  [ -n "$desc" ] && echo "    ↳ $desc"
done)

jq -n --arg cli "$cli" --arg mcp "$mcp" --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: (
      "`" + $cli + "` has an MCP alternative: " + $mcp + " — prefer the MCP unless it cannot do this specific operation, in which case fall back to the CLI."
      + (if $ctx == "" then "" else "\n" + $ctx end)
    )
  }
}'
