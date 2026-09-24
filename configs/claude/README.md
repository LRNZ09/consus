# claude

The hand-written part of Claude Code's user configuration. Four links at Claude
Code's own paths lead here (INSTALL.md step 3):

```text
~/.claude/settings.json  →  settings.json
~/.claude/AGENTS.md      →  AGENTS.md
~/.claude/hooks          →  hooks/
~/.claude/scripts        →  scripts/
```

Everything else in `~/.claude` — sessions, transcripts, plugins, memory,
`settings.local.json` — stays there and is not in this repo. Linking the whole
directory would put 4 GB of it inside a public working tree;
`docs/superpowers/specs/2026-09-24-claude-into-consus-design.md` has the
measurements.

## Hooks

Both run on `PreToolUse` with matcher `Bash` and only inject context — they
never block a call. Both search `~/.claude/memory` plus the current project's
memory directory, derived from the payload's `cwd`.

- **`pre-bash-memory-grep.sh`** — surfaces memory files that mention the
  command's leading phrase: the longest matching 4-, 3- or 2-word prefix, at
  least 6 characters.
- **`pre-bash-prefer-mcp.sh`** — when a CLI listed in `cli-mcp-map.tsv` is
  about to run, reminds you to prefer its MCP equivalent. A new
  `<cli><TAB><label>` row covers a new tool; no script change needed.

## Global instructions

Nothing imports `AGENTS.md`: there is no `~/.claude/CLAUDE.md`. Claude Code
reads `AGENTS.md` itself from 2.1.277, and only as a project file — the upward
walk from any directory under `$HOME` reaches `$HOME/.claude/AGENTS.md`.
`settings.json` sets `pluginConfigs."agents-md@builtin".options.instructionFiles`
to `claude-md-and-agents-md` so that repos with their own `CLAUDE.md` still load
it. Sessions started outside `$HOME` do not, and neither do subagents that skip
project instructions.

## Private values

Some values in `settings.json`, all of them under `autoMode`, are private. Git
stores `<placeholder>` tokens instead; the file on disk keeps the real values.
`bin/placeholders` swaps them as a git filter using the untracked map
`~/.claude/placeholders.tsv`, and stores the file in one canonical layout:
sorted keys, tabs.

- **Add a map row before staging a new private value** — including one that
  `/permissions` or `/auto-mode-setup` wrote. Until the row exists, `git add`
  and even `git diff` on `settings.json` fail with "private term(s) found".
  Map it rather than `git restore` the file: the restore would silently throw
  the new entry away.
- **After Claude Code saves `settings.json`, `git status` may list it while
  `git diff` is empty.** Claude Code re-serializes the file on every save, and
  the canonical layout makes what git stores identical. `git add` clears it.
- **The map is the only copy of the real values.** Keep an off-machine backup
  of it. Without it, nothing in this repo can be committed — every guard fails
  closed.
- **Commit with the git CLI**, or a client that runs it, as VS Code's does.
  libgit2-based clients skip external filters and hooks.

## Traps

- **A dangling `settings.json` link wipes the record on the next save.**
  Measured on 2.1.273: with the target gone but this directory present, Claude
  Code reads empty settings in silence — no permission rule, hook or `autoMode`
  entry — and its next save writes a `settings.json` here holding only that one
  change. `git restore settings.json`, then look for anything saved in between.
  `bin/doctor` reports the link.
- **Never check out, bisect or rebase onto a commit from before this directory
  existed.** All four links dangle until you return, and every running session
  loses its permission rules, hooks and `autoMode` entries. Read old commits
  with `git show`, or in a worktree elsewhere.
- **Stage `settings.json` whole, right before committing.** When it is
  partially staged, lefthook checks the staged copy out over the live file
  while the hooks run, and a save in that window can leave the change only in
  a `lefthook auto backup` stash.
- **`rm -rf ~/.claude/hooks/`**, with the trailing slash, follows the link and
  empties `hooks/` here; the same goes for `scripts/`. `git restore` recovers
  both, since nothing untracked lives in either.
- **An interrupted save leaves `settings.json.tmp.*` here**, next to the link
  target, holding the real values unfiltered. `.gitignore` keeps it
  unstageable.
- **Never set `CLAUDE_CONFIG_DIR`.** It relocates sessions, transcripts and
  credentials along with the settings, and only shells that export it see it.
