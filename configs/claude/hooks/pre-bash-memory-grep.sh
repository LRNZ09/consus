#!/usr/bin/env bash
# PreToolUse hook on Bash: surface memory files that mention this command's leading
# phrase verbatim. Tries 4-word, 3-word, then 2-word prefixes (longest match wins).
# Skips builtin/coreutil-only commands.
set -uo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')
[ -z "$command" ] && exit 0

# Drop leading env-var assignments (e.g. `FOO=bar BAR=baz cmd ...`)
command=$(echo "$command" | sed -E 's/^([A-Z_][A-Z0-9_]*=[^ ]+ +)+//')

SKIP_LIST=' sudo cd ls cat echo true false grep awk sed tr cut head tail wc sort uniq xargs read jq find test if then else fi do done for while case esac export unset local set env which type command exec eval source return exit break continue shift trap umask alias unalias let printf mkdir rmdir rm cp mv ln touch chmod chown stat file date sleep tee tar gzip gunzip zip unzip curl wget ssh scp rsync ps top kill pgrep pkill nohup disown bg fg jobs history pwd basename dirname realpath readlink mktemp diff dirs '

is_skip() { case "$SKIP_LIST" in *" $1 "*) return 0 ;; esac; return 1; }

# Walk the chain (split on | ; &) and find the first non-builtin segment
interesting=""
while IFS= read -r seg; do
  seg=$(echo "$seg" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
  [ -z "$seg" ] && continue
  first=$(awk '{print $1}' <<<"$seg")
  if ! is_skip "$first"; then
    interesting="$seg"
    break
  fi
done < <(tr '|;&' '\n' <<<"$command")

[ -z "$interesting" ] && exit 0

read -ra toks <<< "$interesting"
[ ${#toks[@]} -lt 1 ] && exit 0

# Global memory + this project's memory dir, derived from the hook's cwd
# (~/.claude/projects/<sanitized-cwd>/memory) so it works in any repo.
cwd=$(echo "$input" | jq -r '.cwd // ""')
MEM_DIRS=("$HOME/.claude/memory")
[ -n "$cwd" ] && MEM_DIRS+=("$HOME/.claude/projects/$(printf %s "$cwd" | sed 's#[^a-zA-Z0-9]#-#g')/memory")

grep_memory() {
  local phrase="$1"
  local files=()
  local d
  for d in "${MEM_DIRS[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      files+=("$f")
    done < <(find "$d" -maxdepth 1 -type f -name '*.md' ! -name 'MEMORY.md' 2>/dev/null)
  done
  [ ${#files[@]} -eq 0 ] && return 0
  grep -l -i -F -- "$phrase" "${files[@]}" 2>/dev/null | sort -u || true
}

# Try 4-, 3-, then 2-word prefixes. Longest verbatim match wins.
matches=""
matched_phrase=""
for n in 4 3 2; do
  [ "${#toks[@]}" -lt "$n" ] && continue
  phrase="${toks[0]}"
  for ((i=1; i<n; i++)); do phrase="$phrase ${toks[$i]}"; done
  # Require at least 6 chars in the phrase to avoid trivial matches
  [ "${#phrase}" -lt 6 ] && continue
  result=$(grep_memory "$phrase")
  if [ -n "$result" ]; then
    matches="$result"
    matched_phrase="$phrase"
    break
  fi
done

[ -z "$matches" ] && exit 0

ctx=$(while IFS= read -r f; do
  [ -z "$f" ] && continue
  desc=$(grep -m1 -E '^description:' "$f" 2>/dev/null | sed 's/^description: *//')
  echo "- $f"
  [ -n "$desc" ] && echo "    ↳ $desc"
done <<< "$matches")

jq -n --arg p "$matched_phrase" --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: ("Memory mentions \"" + $p + "\" — read before running if you haven'"'"'t consulted these recently:\n" + $ctx)
  }
}'
