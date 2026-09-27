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

## Hook-bypass deny rules

`permissions.deny` refuses a Bash call that runs `git commit`, `push`, `merge`
or `pull` with the git hooks off, or that turns them off:

- `--no-verify`, and for `commit` and `push` the abbreviations git takes for
  it; `commit`'s `-n`, alone or in a cluster such as `-an`;
- `LEFTHOOK=0` or `LEFTHOOK=false`, `LEFTHOOK_EXCLUDE`, `LEFTHOOK_CONFIG`,
  and `LEFTHOOK_BIN`, which names the binary lefthook's hook runs: each set
  before git, through `env`, or by `export NAME=value`, `declare -x` or
  `typeset -x`. `LEFTHOOK_EXCLUDE`, `LEFTHOOK_CONFIG` and `LEFTHOOK_BIN` are
  refused exported by name too (`export LEFTHOOK_BIN`), and a bare
  assignment, one that is a command of its own and so can be exported later
  or under `set -a`, is refused for `LEFTHOOK=0`, `LEFTHOOK=false`,
  `LEFTHOOK_BIN` and `HUSKY=0` only;
- `HUSKY=0` before git or through `env`, and `HUSKY` by `export`,
  `declare -x` or `typeset -x`, with a value or by name; `SKIP` before git;
- `core.hooksPath` set by `git -c`, `--config-env`, `git config`,
  `git clone -c` or `--config`, `GIT_CONFIG_KEY_<n>` or
  `GIT_CONFIG_PARAMETERS`;
- `lefthook uninstall`, bare, by path, or through `npx`, `yarn`, `pnpm`,
  `bunx` or `npm exec`;
- the same flags inside the commands git runs for you: a `git config` value
  (an alias), `git rebase -x` and `git submodule foreach`.

Each form is refused after git's own options too — `git -C dir`,
`-c key=value`, `--git-dir=…` — except two, refused only right after `git`: a
`--no-verify` inside `rebase -x` or `submodule foreach` that is not the first
flag after `commit`, and an alias whose value starts with `-c` or
`--config-env`.

The rules are position-aware. Claude Code matches each subcommand's text
against a glob whose `*` is any text, quotes included, so no rule can tell a
flag from message text. Each rule puts the flag where git reads one: right
after the subcommand (`git commit -n*`), last (`git commit * -n`), or before
another option (`git commit * -n -*`). git's own options are reached as
`git -* commit …`, which a command that starts `git commit -m` never matches.
So `git commit -m 'sort -n output'` and `git push -n` run.

Known gaps. Getting through: a flag before a pathspec; a `commit`
abbreviation or cluster that is not right after the subcommand; a late `-n`
inside `rebase -x`, `submodule foreach` or an alias; `CORE.HOOKSPATH` in
capitals; a flag after a redirection; a quoted subcommand or flag; a bypass
variable among other assignments, or exported by `typeset -gx`, by any
cluster other than a lone `-x`, or by `readonly -x`; `LEFTHOOK_EXCLUDE` or
`LEFTHOOK_CONFIG` set as a plain shell variable under `set -a`; `LEFTHOOK`
set by `typeset`, `declare` or `local` without `-x`, then exported by name;
`HUSKY` quoted through `env`; `SKIP` through `env` or `export`;
`core.hooksPath` set in a config file that git reads, through
`GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM` or `-c include.path=<file>`;
`lefthook uninstall` through any other launcher, such as `mise exec` or
`go tool`; the two forms after git's options above; and anything inside
`bash -c`, `eval`, a variable or an alias.

Refused though harmless: a message or value that is character for character
a flag in one of those positions (`git commit -m -n`); after git's own
options, a message or argument that holds a bypass anywhere, since the `*`
after `git -` reaches into it (`git -C dir commit -m 'fix commit -n handling'`,
`git -C dir log --grep commit -n 5`,
`git -c core.pager=cat config --get core.hooksPath`) — no glob can stop at
the subcommand; any `git config` text holding `commit` followed by `-n`,
`-an`, `-qn`, `-sn` or `-vn`, or `--no-veri`, since the alias rules look
anywhere after `git config`: a value pattern in
`git config --get-regexp '^alias[.]' 'commit -n'` or
`git config --unset-all alias.ci 'commit -n'`; any text naming
`GIT_CONFIG_KEY_*` or `GIT_CONFIG_PARAMETERS` with a hooks path; an
`export`, `declare -x` or `typeset -x` that names `HUSKY`, `LEFTHOOK_BIN`,
`LEFTHOOK_CONFIG` or `LEFTHOOK_EXCLUDE`, whatever the value
(`export HUSKY=1`), and `LEFTHOOK_BIN=…` before any command
(`LEFTHOOK_BIN=… lefthook run pre-commit`); and a command git runs no hook
for under a bypass setting (`LEFTHOOK=0 git status`, `HUSKY=0 git status`).
When a message has to name a bypass, commit it with `-F <file>`; search for
one without `git -C` or `-c`; find an alias with
`git config --get-regexp '^alias[.]' | grep 'commit -n'`, and remove it by
name with `git config --unset alias.ci`. The design document has the full
list and the reasons.

To test a change, run `bin/test-deny-rules` in the clone root; it needs zsh
and jq. It replays `deny-corpus.tsv`, next to this file, through an offline
replica of Claude Code 2.1.273's matcher, against the rules in
`settings.json`, and runs none of the commands. Each row holds a command, its
right answer, and the answer the real matcher gave when the command was last
probed live. The test passes when the replica predicts the measured answer
for every row, and it counts, without failing, the rows whose measured answer
is not the right one: the known gaps, each of which says so. It also fails
unless each rule is the only one that refuses some row, so that deleting any
rule moves a verdict. `deny-exempt.tsv` lists the exceptions, the older
rules against destructive commands, and a rule it lists must still be in
`settings.json`. So a new rule needs a row, probed live, that it alone
refuses; `bin/test-deny-rules --rules` shows what each rule refuses.

Live probes stay the ground truth. After a rule change the test fails on each
row whose verdict moved: probe each of those, and each row added for the
change, as a real Bash call into a scratch repository whose hooks leave
marker files and whose remote is local, prefixed `cd <that repository> &&` —
`<P>` in a row stands for it. The `cd` also puts the whole line through the
rules that start with `*`. Write the answer into the row's `measured` column,
and `known gap` into its why when that answer is not the right one. A rule's
refusal reads "Permission to use Bash with command … has been denied."; the
auto-mode classifier's reads otherwise, and measures nothing.

## Global instructions

Nothing imports `AGENTS.md`: there is no `~/.claude/CLAUDE.md`. Claude Code
reads `AGENTS.md` itself from 2.1.277, and only as a project file — the upward
walk from any directory under `$HOME` reaches `$HOME/.claude/AGENTS.md`.
`settings.json` sets `pluginConfigs."agents-md@builtin".options.instructionFiles`
to `claude-md-and-agents-md` so that repos with their own `CLAUDE.md` still load
it. Sessions started outside `$HOME` do not, and neither do subagents that skip
project instructions.

Native loading also sits behind a server-side flag while Anthropic rolls it
out: a session that starts while the flag is off loads no `AGENTS.md` at all.
A `~/.claude/CLAUDE.md` holding `@AGENTS.md` would close that gap; it was
declined on 2026-09-24.

## Private values

The private values in `settings.json` are all under `autoMode`, and so is the
prose around them, which can say as much as the values do. So every `autoMode`
string but `$defaults` is mapped whole: git stores one `<placeholder>` token
per string, and the file on disk keeps the real text. `bin/placeholders` swaps
them as a git filter using the untracked map `~/.claude/placeholders.tsv`, and
stores the file in one canonical layout: sorted keys, tabs. It refuses any
`autoMode` string that is not one whole token.

- **Add a map row for every new `autoMode` string before staging it** —
  including one that `/permissions` or `/auto-mode-setup` wrote: the whole
  string, a tab, and a token of its own, such as `<automode-soft-deny-3>`.
  Until the row exists, `git add`, `git diff` and at times even `git status`
  fail on `settings.json` with "an autoMode string is not a single
  placeholder" — or "private term(s) found", for an unmapped value elsewhere
  in the file; `bin/doctor` notes a failing `git status`. Map it rather than
  `git restore` the file: the restore would silently throw the new entry away.
- **After Claude Code saves `settings.json`, `git status` may list it while
  `git diff` is empty.** Claude Code re-serializes the file on every save, and
  the canonical layout makes what git stores identical. `git add` clears it.
- **The map is the only copy of the real values.** Keep an off-machine backup
  of it. Without it, nothing in this repo can be committed — every guard fails
  closed.
- **Commit with the git CLI**, or a client that runs it, as VS Code's does.
  libgit2-based clients skip external filters and hooks.
- **If the live `settings.json` holds placeholders, `autoMode` describes
  tokens, not hosts.** smudge never fails, so a checkout that cannot resolve a
  token — the map missing or short of a row another machine added, a
  conflicted merge — leaves it there in silence, and once the map is back git
  refuses the file with "placeholders don't swap back". `bin/doctor` names the
  tokens. With the map restored, run in the clone root:

  ```sh
  bin/placeholders smudge < configs/claude/settings.json > configs/claude/settings.json.tmp.fix && mv configs/claude/settings.json.tmp.fix configs/claude/settings.json
  ```

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
