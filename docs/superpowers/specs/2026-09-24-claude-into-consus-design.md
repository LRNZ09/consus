# claude — bringing the ~/.claude record into consus

**Date:** 2026-09-24
**Status:** executed 2026-09-24
**Amends:** `docs/superpowers/specs/2026-08-21-consus-migration-design.md`,
whose "Deliberately out of scope" opens with "`~/.claude` keeps its own repo at
its real path". That premise is what this change ends, so the line is edited
rather than supplemented, the way the proto change edited it.
**Retires:** `LRNZ09/dotclaude`, a private repo whose clone is the directory
`~/.claude` itself.

## What this does

consus takes over the hand-written part of Claude Code's user configuration —
the settings, the global agent instructions, two hooks and the status-line
script — and `LRNZ09/dotclaude` is archived. Everything else in `~/.claude`
stays where Claude Code puts it. `CLAUDE_CONFIG_DIR` is never set. Four links go
in instead:

```text
~/.claude/settings.json  →  <repo>/configs/claude/settings.json
~/.claude/AGENTS.md      →  <repo>/configs/claude/AGENTS.md
~/.claude/hooks          →  <repo>/configs/claude/hooks
~/.claude/scripts        →  <repo>/configs/claude/scripts
```

The principle is unchanged: each tool finds its configuration at its own
default path, and that path is a symlink into this clone. Two things are new.
consus is public and dotclaude was private, so the placeholder filter that
kept work terms out of dotclaude moves here and its guards start covering the
whole repo. And `~/.claude/CLAUDE.md`, the one-line `@AGENTS.md` import, is
dropped: Claude Code now reads `AGENTS.md` itself.

## Why ~/.claude never becomes a linked directory

A single link, `~/.claude → <repo>/configs/claude`, with dotclaude's
deny-by-default `.gitignore`, was priced and rejected. It is `PROTO_HOME` again,
at twice the size and with far worse contents. Measured:

- **4.0 GB and 162,999 entries** would sit inside the working tree of a public
  repo: 2.7 GB of plugins, 1.3 GB of session transcripts under `projects/`,
  `history.jsonl`, `file-history/`, and `memory/`.
- **The transcripts are work content.** `history.jsonl` alone has 1,666 lines
  the work-term guard flags, and the `projects/` directory names are built from
  working-directory paths. One slip in the allow-list — a `git add -f`, a bad
  negation — stages them for a public remote. The guard catches mapped terms; it
  cannot catch a pasted token or a term nobody has mapped yet. The 2026-08-21
  guarantee, that a gitignore mistake can only cause a missing file and never a
  leak, would invert for the most sensitive directory on the machine.
- **`git clean -fdx` and `git stash --all` in consus would delete every
  session, all history and `memory/`**, which no repo and no backup holds.

What the directory link buys is real: tracking something new is one negation
instead of a link, an INSTALL line and a doctor test. It is not worth the
above, and the one place where files do get added — hooks — is already a
directory link.

`CLAUDE_CONFIG_DIR` is rejected for the reason `PROTO_HOME` was: it relocates
everything, credentials and transcripts included, and it is env-var activation,
which reaches neither the VS Code extension nor anything launched from a GUI.

## Options considered

| Option | Verdict |
| --- | --- |
| **File links, plus directory links for `hooks/` and `scripts/`** | **Chosen.** Only hand-written files enter the tree. |
| `~/.claude` as one directory link | Rejected — the three counts above. |
| `CLAUDE_CONFIG_DIR` | Rejected — relocates all state, and is env-var activation. |
| `CLAUDE.md` as a one-line include stub (the ghostty pattern) | Unnecessary once `CLAUDE.md` is dropped; it was the fallback against a double load. |
| `autoMode` in a work repo's `.claude/settings.json` | Impossible: the classifier ignores `autoMode` in project settings, so a checked-in repo cannot grant itself allow rules. |
| `autoMode` in a `managed-settings.d/` drop-in | Viable, declined — see "Why the private values stay in settings.json". |
| `autoMode` through `--settings` | Rejected: a fish wrapper is env-var activation again, and the VS Code extension never sees it. |

## The mechanism

Claude Code does **not** write `settings.json` in place, unlike proto and
dotagents. It follows the link and replaces the *target* by temp file and
rename. Measured on 2.1.273 against a scratch `CLAUDE_CONFIG_DIR`, with a
hardlink witness:

```text
home/settings.json -> rec/settings.json      (inode 77105083)
ln rec/settings.json rec/witness             (links = 2)

claude plugin disable … --scope user

home/settings.json   still a symlink, same target
rec/settings.json    inode 77105104 — a new file, with the change
rec/witness          inode 77105083, stale
```

So the link survives every save and the change lands here as an ordinary
unstaged modification, which is what the design wants. The temp file is
`settings.json.tmp.<pid>.<hex>`, written next to the **target** — inside
this repo. The file mode survives the rename (600 stayed 600). Claude Code's
own `backups/` directory is created next to the **link**, in `~/.claude`, and
never reaches the tree.

The failure modes are the worst of proto's and dotagents' together:

- **A dangling link is silent on read.** With the target gone, Claude Code
  reads empty settings: every permission rule, hook and `autoMode` entry is
  simply absent, and nothing warns.
- **The next save then writes a near-empty file into this repo.** With the
  target missing but `configs/claude/` present, a write creates
  `configs/claude/settings.json` holding only the one changed key. `git
  restore` brings the record back, but anything saved in between is lost.
- **With `configs/claude/` itself gone, a write fails loudly** (ENOENT on the
  temp file) and leaves the link in place.

The other three links are only ever read. `hooks/` and `scripts/` are
directories, so they carry the fish hazard: `rm -rf ~/.claude/hooks/`, with the
trailing slash, empties `configs/claude/hooks/` here.

## What the record contains

```text
configs/claude/AGENTS.md
configs/claude/settings.json          placeholders in git, real values on disk
configs/claude/hooks/pre-bash-memory-grep.sh
configs/claude/hooks/pre-bash-prefer-mcp.sh
configs/claude/hooks/cli-mcp-map.tsv
configs/claude/scripts/statusline.sh  was statusline-command.sh
configs/claude/README.md
```

Three changes from what dotclaude tracks:

- **`CLAUDE.md` is dropped** — see the next section.
- **The status-line script moves into `scripts/` as `statusline.sh`**, and
  `statusLine.command` becomes `bash ~/.claude/scripts/statusline.sh`.
  `commands/` was considered and rejected: `~/.claude/commands/` is Claude
  Code's slash-command directory.
- **`settings.json` gains `pluginConfigs."agents-md@builtin".options.instructionFiles
  = "claude-md-and-agents-md"`.**

`AGENTS.md` dropped its work-specific sections on 2026-09-25, after the final
review; the record keeps only what applies to every project.

The hook commands keep their `~/.claude/hooks/…` paths, which resolve through
the directory link.

`configs/claude/README.md` carries what exists nowhere else, as
`configs/proto/README.md` does: what each hook does, the placeholder workflow
(add a map row before staging a new private value; why `git status` lists
`settings.json` after a save while `git diff` is empty), and the traps — the
dangling-link wipe above and the trailing-slash `rm`. dotclaude's "Setup on a
new machine" is not carried: INSTALL.md replaces it.

### The .gitignore

One defensive line:

```gitignore
# Claude Code saves settings.json by temp file and rename, next to the link
# target, so a save interrupted mid-write leaves the temp file here. It holds
# the real, unfiltered values, and the filter only applies to settings.json:
# it must never be stageable.
/configs/claude/*.tmp.*
```

## Global instructions without CLAUDE.md

`~/.claude/CLAUDE.md` exists today only to hold `@AGENTS.md`, because Claude
Code read nothing else at user scope. From the memory documentation, checked
2026-09-24:

- Reading `AGENTS.md` directly requires v2.1.277.
- It is **project** scope only: Claude Code reads "every `AGENTS.md` and
  `.claude/AGENTS.md` in your working directory and the directories above it".
  The only user-scope file is `~/.claude/CLAUDE.md`.
- In the default mode, `claude-md-or-agents-md`, any `CLAUDE.md` in the
  working directory or above it suppresses every `AGENTS.md`.

So without the stub, `~/.claude/AGENTS.md` loads because the upward walk from
any directory under `$HOME` reaches `$HOME/.claude/AGENTS.md` — as a project
file. That is what the stub's own comment observed on 2.1.280 as "loads
AGENTS.md a second time as a project file". `instructionFiles =
"claude-md-and-agents-md"` keeps it loading in repos that carry their own
`CLAUDE.md`; without it, those repos would lose the global instructions.

Accepted gaps, named so nobody rediscovers them:

- **Sessions started outside `$HOME`** — `/private/tmp` scratch sessions, for
  instance — get no global instructions.
- **Subagents that skip project instructions skip `AGENTS.md` too**, now that
  it counts as one.
- **The terminal CLI is too old.** The `claude-code` cask is at 2.1.273, the
  stable channel, and stays there: no cask swap, no Brewfile change,
  `autoUpdatesChannel` stays `"stable"`. Until stable reaches 2.1.277,
  terminal sessions load no global instructions at all, and doctor's version
  test fails on purpose. The VS Code extension bundles its own 2.1.281 and is
  unaffected.
- **Native loading sits behind a server-side flag.** In 2.1.281 it is the
  built-in `agents-md` plugin, which loads only while the feature flag
  `tengu_agents_md_mod` is on, as read at session start from the flag cache in
  `~/.claude.json` (on when absent). The cache held `false` at least once on
  2026-09-24, and a session that starts then loads no `AGENTS.md` anywhere —
  no global instructions at all, in any directory. Restoring the `CLAUDE.md`
  import would close the gap, and was considered and declined on 2026-09-24:
  it lasts until the rollout settles.

## Private values: the filter and the guards

All 16 private strings in `settings.json` are under `autoMode`. Placeholders
for the names alone would still publish the prose around them, which says as
much, so every `autoMode` string but `$defaults` is mapped whole: git stores
one `<placeholder>` token per string, the file on disk keeps the real text,
and `clean` refuses any other `autoMode` string, naming none. A new entry that
`/permissions` or `/auto-mode-setup` writes is refused until its row exists.
This is dotclaude's mechanism, moved:

- **`bin/placeholders`**, tracked. The code of `.git/placeholders-filter.sh`,
  which holds no private data: it reads the map. It dispatched on its own name
  because it was symlinked as each hook; lefthook owns `.git/hooks/` here, so
  that becomes explicit subcommands — `clean` and `smudge` (the filter,
  unchanged), `check` (stdin), and `check-msg <file>`, `check-staged` and
  `check-push <remote>` (stdin), which are the old hook bodies. Two fixes come
  with the move. `check` refuses when a guard row does not compile: `grep`
  exits 2 on a bad regex, matches nothing, and the old code passed everything.
  And `clean` no longer leaves a copy of the raw settings in `$TMPDIR` when it
  refuses: a `local tmp` in `check` shadowed the trap's `tmp`. The final
  review hardened it further on 2026-09-25. The guards pass `--no-color
  --no-ext-diff --no-textconv` to the `git diff --cached` and `git log -p`
  they parse: colour, an external diff or a textconv driver in user config
  each let a staged term through. `check` refuses a map with more than one
  `guard` or `guard_cs` row: only the last one counted, so a second row
  silently disabled the first. `check-push` also scans each ref line's local
  and remote names and an annotated tag's message. And `check`'s buffer is
  removed on an interrupt too. Three more gaps closed later that day.
  `check-push` follows a tag that points at another tag, up to 20 deep, and
  scans every tag's message, not only the outer one's. Its `git log -p` passes
  `--root`, since `log.showRoot=false` hides a root commit's diff. And a
  malformed map row is named by its line number in the map,
  `bad map row at line N`, never by its text, which may be a private value.
- **`.gitattributes`**, tracked: `configs/claude/settings.json filter=placeholders`.
- **Per clone**, an INSTALL step: `filter.placeholders.clean` and `.smudge`
  set to `bin/placeholders clean|smudge` — git runs filters from the worktree
  root — and `filter.placeholders.required true`.
- **`lefthook.yml`** gains the guard in three hooks: `pre-commit` beside
  gitleaks, `commit-msg` (`{1}`) and `pre-push` (the remote as `$1`, the ref
  lines on stdin). `pre-commit` and `pre-push` run it as lefthook *scripts*,
  `.lefthook/<hook>/placeholders.sh`, not commands: lefthook 2.1.14 skips a
  command when its own file list is empty — a typechange-only commit, a
  commit that changes no file, a push of a branch other than `HEAD` — and a
  skipped guard passes everything. Scripts always run. Cherry-pick, rebase, am
  and merge run no `pre-commit`; `pre-push` is what sees their commits. Since
  2026-09-25 `pre-push` runs gitleaks too, as a second script,
  `.lefthook/pre-push/gitleaks.sh`, over every pushed commit the remote lacks.
  Its `--log-opts` carry the flags `check-push` gives its own `git log`, so
  user config cannot hide a line from it either. It refuses a ref that is not
  a commit or a tag of one, because gitleaks passes whatever its `git log`
  cannot read. For the same reason it leaves out the commits the
  remote-tracking refs hold only when `$1` names one of the clone's remotes: on
  a push to a URL or path, `$1` is that URL or path, and one with a space in
  it split gitleaks' `--log-opts`. Such a push scans each commit's whole
  history.
- **The map** stays untracked at `~/.claude/placeholders.tsv`.

The guards now cover all of consus, not only `settings.json`. Measured before
the change, the existing tree fails them: 9 tracked files and one commit
message. Every hit comes from two over-broad guard rows that match strings
consus already publishes legitimately — the `includeIf` path in
`configs/git/config` and proto's file name. Those rows are narrowed in the map,
by hand, before the guards are switched on; the gate is `bin/placeholders check`
passing over every tracked file and every commit message.

Two properties are kept on purpose:

- **No map, no commits.** Without the map every guard refuses everything, as
  dotclaude's did. On a machine without the map, consus cannot be committed to.
- **An undefined filter passes `settings.json` through raw.** `required` only
  applies once the filter is defined, so a clone missing the per-clone config
  stores whatever is on disk. Two things stand between that and a public push:
  the guards also scan for mapped *values*, and doctor asserts the filter
  config.

CI runs gitleaks only, over the full history on every push. The map is
private, so the work-term guard can only ever run locally, and `pre-push` is
its backstop. gitleaks runs locally too, at `pre-commit` and `pre-push`; CI
is the one scan that `--no-verify` cannot skip, but it reports a leak only
once it is public.

`--no-verify` skips `pre-push` too, so `settings.json` denies Claude Code the
ways around the hooks. Until 2026-09-25 that was eight rules in the
`Bash(<prefix>*)` style of its others, and they cut both ways. They refused
`git commit -m 'sort -n output'` and `git commit -m "mentions --no-verify"`,
through `Bash(git commit * -n*)` and `Bash(git commit * --no-verify*)`, while
`git -C dir commit --no-verify`, `env LEFTHOOK=0 git push`,
`git -c core.hooksPath=/dev/null commit` and `git merge --no-verify topic` all
got past them. Now 90 rules refuse a `commit`, `push`, `merge` or `pull` run
with the hooks off, and each way of turning them off that a rule can see:

- `--no-verify`, and for `commit` and `push` the abbreviations `--no-veri`
  and `--no-verif`;
- `commit`'s `-n`, alone or clustered: `-an`, `-nm`, `-anm`, `-qn`, `-sn`,
  `-vn`, and `-a -nm`;
- `LEFTHOOK=0` or `LEFTHOOK=false`, quoted or not, before git, through `env`
  or by `export`; `LEFTHOOK_EXCLUDE` and `LEFTHOOK_CONFIG` the same ways, and
  `SKIP` before git;
- `core.hooksPath` set by `git -c`, with the argument quoted or not,
  `--config-env`, `git config`, `git clone -c`, `GIT_CONFIG_KEY_<n>` or
  `GIT_CONFIG_PARAMETERS`;
- `lefthook uninstall`, bare, by path, or through `npx`, `yarn`, `pnpm`,
  `bunx` or `npm exec`.

A rule cannot parse, so each one is written for a position. Claude Code
matches it against the whole text of each subcommand, its `*` is any text,
spaces and quotes included, and a quote means nothing to it ("Measured
2026-09-25" below). A rule that looks for `-n` anywhere after `git commit`
finds it in the message too. So each rule puts the flag where git reads one:
right after the subcommand (`git commit -n*`), last (`git commit * -n`), or
before another option (`git commit * -n -*`). git's own options come before
the subcommand and each starts with `-`, so `git -* commit …` reaches past
`-C dir` and `-c key=value`, while a command that starts `git commit -m` never
matches it: a message that only mentions `git push --no-verify` runs. The
same forms are repeated under `git config *` for an alias, `git rebase *` for
`-x`, `git submodule *` for `foreach` and `git clone *` for a cloned
`core.hooksPath`: the commands that run git for you. `merge` and `pull` need
the whole `--no-verify`, the only form `merge` takes, so
`git merge --no-verify-signatures` runs.

Where no rule gets it right, each case errs in the direction chosen for it:

- **Let through**, because a rule that caught it would refuse message text.
  A `commit` flag or abbreviation before a pathspec, or an abbreviation that
  is not first, takes a rule like `git commit * --no-veri* *`, which matches
  any message that mentions the flag; the eight old rules caught the whole
  flag there, at that price. `-an` after another option takes
  `git commit * -an*`, which matches a message saying "-and". A `LEFTHOOK=0`
  between other assignments takes `*LEFTHOOK=0 *`, which matches a message
  naming it. The matcher itself drops a flag after a redirection, and
  `CORE.HOOKSPATH` in capitals gets past its case-sensitive match. Out of
  reach altogether: `bash -c`, `eval`, a variable, a one-off `-c alias.…`, a
  late `-n` in a `rebase -x` command, a quoted subcommand or flag, git by
  absolute path, and a moved `.git/hooks` file, since `rm`, `mv` and `chmod`
  rules would refuse real work on hooks.
- **Refused**, because the text is the flag, byte for byte. A value in a
  flag's position: `git commit -m -n`, `git commit --message --no-verify`, a
  pathspec named `--no-verify`, `git merge -m --no-verify`,
  `git push -o --no-verify`, and a message holding `-n` or `--no-verify`
  right before another option-like word. Any text naming `GIT_CONFIG_KEY_*`
  or `GIT_CONFIG_PARAMETERS` with a hooks path, in `echo`, `grep` or a
  message: those rules start with `*`, so that they also reach a `bash -c` or
  `eval` string. And a bypass setting on a command that runs no hook,
  `git -c core.hooksPath=… status` or `LEFTHOOK=0 git status`, since a rule
  cannot tell which subcommands run hooks.

A message that has to name a bypass is committed with `-F <file>`.

A `PreToolUse` hook that read each command as zsh and git do — split by zsh's
own lexer, git's options walked, option values skipped — was built on
2026-09-25 and rejected the same day. It got the positions right, but it is
some 160 lines of code on every Bash call, and a bug in it would block
ordinary commands, where a deny rule is enforced by Claude Code itself; and it
reached no further: `bash -c`, `eval`, a script and an alias were out of its
reach too.

### Why the private values stay in settings.json

The classifier reads `autoMode` from `~/.claude/settings.json`, managed
settings and `--settings` only. A `managed-settings.d/` drop-in under
`/Library/Application Support/ClaudeCode/` would have taken every private
value out of consus, and with it the clean/smudge half of the filter. It was
declined. Its costs, for the record: a root-owned file outside any repo that
needs `sudo` to edit; silent loss under the default `first-wins` if server-managed
policy ever arrives (today `remote-settings.json` is `{}`); sessions that exit
at startup when a managed file is unreadable; and `/permissions` and
`/auto-mode-setup` still writing new entries into user settings — here —
regardless.

## bin/doctor

The base follows Claude Code's own lookup, as `PROTO_STORE` and `AGENTS_ROOT`
do: `CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`.

| Test | Why |
| --- | --- |
| `~/.claude/settings.json links into this clone` | The dangling case reads empty settings in silence, then the next save writes a near-empty record here. |
| `~/.claude/AGENTS.md links into this clone` | Severed, the global instructions vanish without a word. |
| `~/.claude/hooks links into this clone` | Severed, the two hooks stop injecting their context, and neither ever blocked a call to begin with. |
| `~/.claude/scripts links into this clone` | Severed, the status line disappears. |
| `claude is 2.1.277 or later` | Below it, `AGENTS.md` is not read at all. Fails today, by design, until the stable cask catches up. |
| `the placeholders filter is configured in this clone` | Undefined, git stores `settings.json` raw. |
| `the placeholder map is readable` | Missing, or with more than one `guard` row, every commit fails; this names the reason in one line. |
| `the live settings.json holds real values, not placeholders` | smudge never fails, so a checkout that cannot resolve a token leaves it in the live file in silence. Added 2026-09-25; names the tokens only. |

The lefthook test also checks `commit-msg` and `pre-push`: `lefthook install`
writes only the hooks `lefthook.yml` lists, so a clone installed before this
change has neither.

`teardown_file` gains an advisory for `~/.claude/.git`: a checkout there
restores regular files over the links. Since 2026-09-25 it also says when
`git status` itself fails, which is how the filter refusing `settings.json`
shows, rather than swallowing it.

Deliberately not tested: the `instructionFiles` key (it is in the tracked
record, so git sees it — doctor tests the machine), the VS Code extension's
bundled version (it updates itself), and a stray `~/.claude/CLAUDE.md` (under
`claude-md-and-agents-md` it loads beside `AGENTS.md`, not instead of it).

## Destruction accounting

**This migration deletes nothing.** The four regular files, `~/.claude/.git`
(with the filter script and its three hook links), `.gitignore`, `README.md`
and `CLAUDE.md` all move into `~/Backups/dotclaude-<timestamp>/`, and reverse by
moving back.

What a mistake can still do here is sever the `settings.json` link while
`configs/claude/` stays, and the cost is the one above: settings read as empty,
then a near-empty record written into the tree. Nothing else in `~/.claude`
enters the repo, so no `git clean` or `rm` inside consus can reach a session,
a transcript or memory.

One more way to sever all four links at once: checking out, bisecting or
rebasing onto a commit from before `configs/claude/` existed removes the
directory, and every running session loses its permission rules, hooks and
`autoMode` entries until the checkout returns. Old commits are for `git show`
or a worktree elsewhere.

## Retiring dotclaude

Archive, with a pointer commit first — an archived repo is read-only. The final
commit goes through dotclaude's own guards and reduces its `README.md` to a
notice pointing at consus, keeping the tracked files as a dated snapshot. The
repo stays private and is not deleted: its 29 commit messages carry the
reasoning behind the filter and the hooks.

Then, locally, `~/.claude/.git` moves into the backup directory. Deprecation is
not finished while it exists: it still claims the four paths, so any checkout
there restores regular files over the links.

Nothing outside consus references dotclaude: no other repo under
`~/Developer/LRNZ09` does, and `LRNZ09/sancus` no longer exists. The private
memory files that describe the filter are updated to name consus.

## Phases

0. **The map.** Narrow the two guard rows. Gate: dotclaude's current
   `.git/placeholders-filter.sh check` — `bin/placeholders` does not exist yet
   — passes over every tracked file and every commit message.
1. **Guards and filter.** `bin/placeholders`, `lefthook.yml`, `.gitattributes`,
   the per-clone config. Tested in a throwaway clone: a staged mapped value is
   refused, a work term in a commit message is refused, `pre-push` refuses an
   unguarded commit, and a clean `settings.json` round-trips.
2. **The record.** Copy the live files into `configs/claude/`, make the three
   changes above, add the `.gitignore` line and the README. Gate:
   `git show :configs/claude/settings.json` holds placeholders only, and `git
   diff` is empty.
3. **Doctor.** The tests above, each exercised against a throwaway
   `CLAUDE_CONFIG_DIR`: healthy, dangling, not a link, filter missing, map
   missing.
4. **Activate.** dotclaude's pointer commit and push, while `~/.claude/.git`
   still exists. Copy the four regular files into the backup directory, move
   `.git`, `.gitignore`, `README.md` and `CLAUDE.md` after them. Then the
   links: each file link goes in as `ln -s` to a temporary name followed by
   `mv -f` over the original — one `rename(2)`, because running sessions watch
   `settings.json` and a plain move-then-link leaves a window in which they read
   empty settings and may write a near-empty record here. The two directories
   cannot be renamed over atomically, so they take a brief gap, which is
   harmless: hooks never block, and the status line redraws.
5. **Verify.** `bin/doctor` passes everything but the version test.
   `claude auto-mode config` still lists the private entries. The status line
   draws, and a Bash call gets the memory-grep hook's context. A fresh VS Code
   session in a repo with its own `CLAUDE.md`, and one in `$HOME`, both report
   `AGENTS.md` loaded.
6. **Docs.** `README.md`, `INSTALL.md`, the 2026-08-21 design, and the private
   memory files.
7. **Archive `LRNZ09/dotclaude`.**

Outside this repo there are only the map (phase 0), dotclaude's pointer commit
and archive (phases 4 and 7), and the private memory files (phase 6). Only
phase 4 touches `~/.claude`'s configuration.

## What this edits in the 2026-08-21 design

- **"Deliberately out of scope"** — the bullet "`~/.claude` keeps its own repo
  at its real path" becomes a pointer to this document.
- **"Per-tool activation"** — a `claude` row: default path
  `$CLAUDE_CONFIG_DIR`, default `~/.claude`; mechanism, two file links and two
  directory links; liveness, the `bin/doctor` link tests. The measured-against
  list gains Claude Code 2.1.273 and 2.1.281.
- **"Destruction accounting"** — one line for the dangling `settings.json`.

And in this repo's other documents:

- **`README.md`** — the link table, "What is here", "Per-machine settings"
  (the map), "The hazard of a linked directory" (`hooks/` and `scripts/`),
  and "Secret scanning" (the work-term guard).
- **`INSTALL.md`** — the four links, before `git` so `git` stays last; the
  three `git config filter.placeholders.*` lines; restoring the map from
  backup; and a trap for regular files already at the link paths — move them
  aside, never delete them.

## Rollback

`rm` the four links — the links, never a trailing slash. Move the backed-up
files and `.git` back into `~/.claude`, never over a file that exists there
now. Never `git restore settings.json` there: it still carries the one
uncommitted change it had before the migration. Unarchive dotclaude if it was
archived, and revert its pointer commit. Claude Code reads regular files exactly
as it reads the links, so the machine is whole the moment they are back.
consus's commits can stay: nothing reads them without the links.

## Verified facts

### Measured 2026-09-24

Against Claude Code 2.1.273 (Homebrew cask, terminal) and 2.1.281 (bundled in
the VS Code extension), on macOS arm64. Write experiments ran against a
scratch `CLAUDE_CONFIG_DIR`; no real path was modified.

- A settings write through a symlink replaces the **target** by temp file and
  rename: new inode, hardlink witness stale, symlink intact, content updated.
- The temp file is `settings.json.tmp.<pid>.<hex>`, next to the target.
- The target's mode survives the rename (600 → 600).
- `backups/` is created next to the link, not the target.
- With the target missing and its directory present, Claude Code reads empty
  settings without complaint (`plugin disable` reported the plugin "already
  disabled"), and the next write creates a target holding only that change.
- With the target's directory missing, the write fails with ENOENT on the temp
  file, and the link is left in place.
- `~/.claude` is 4.0 GB and 162,999 entries: `plugins/` 2.7 GB, `projects/`
  1.3 GB, `file-history/` 12 MB, `memory/` 336 KB. There is no
  `.credentials.json`; credentials are in the keychain.
- `history.jsonl` has 1,666 lines the work-term guard flags.
- The guard flags 9 tracked consus files and one commit message, all through
  two guard rows matching the `includeIf` path and proto's file name.
- All 16 private strings in the committed `settings.json` are under `autoMode`.
- `remote-settings.json` is `{}`; `/Library/Application Support/ClaudeCode/`
  does not exist.
- The Claude Code binary's own `AGENTS.md` handling that `strings` can see is
  the Codex importer, which copies Codex's user `AGENTS.md` **into**
  `~/.claude/CLAUDE.md` — consistent with the documentation: no user-scope
  `AGENTS.md`.
- Brew's `claude-code` cask is 2.1.273; `claude-code@latest` is 2.1.281.
- Nothing else on this machine reads `~/.claude/AGENTS.md`: there is no
  `~/.codex/AGENTS.md` or `~/.config/opencode/AGENTS.md`.
- 2.1.281's `agents-md` plugin is gated by `isAvailable`, the server flag
  `tengu_agents_md_mod` with a default of on. With the cached value `false`,
  a debug log shows 15 plugins found instead of 16 and no `agents-md` line;
  the next session, after the cache had refreshed, loaded `AGENTS.md` from a
  directory with its own `CLAUDE.md`, so `instructionFiles` is honoured
  whenever the plugin loads. Which process wrote `false` was not found: a
  terminal 2.1.273 run and a bundled 2.1.281 run each left the cache as it was.
- lefthook 2.1.14 passes `.git/COMMIT_EDITMSG` as `commit-msg`'s `{1}` and the
  remote's name as `pre-push`'s, with the ref lines on stdin under
  `use_stdin`; a failing command or script blocks the commit or push. It skips
  a *command* with "no matching staged files" or "no matching push files"
  when its own list is empty. The push list is `HEAD` against `@{push}`, not
  the refs being pushed, so a guard written as a command let an empty commit
  and a push of another branch through. Scripts are never skipped, and
  lefthook chmods each one to 0751 when it runs it, so they are committed
  executable.
- git runs a filter from the worktree root, even for a `git add` run in a
  subdirectory.
- BSD `mv -f link file` replaces the file by one `rename(2)`; `mv -f link dir`
  and `ln -s target dir` put the link *inside* an existing directory.

### Measured 2026-09-25

For the push guard's gaps and the deny rules, against lefthook 2.1.14,
gitleaks 8.30.1, git 2.55.0, jq 1.8.2 and Claude Code 2.1.273 in auto mode.
Every experiment ran in a throwaway repository. The rules were measured by
real Bash calls, each run in a scratch repository whose hooks leave marker
files and whose remote is a local bare repository, so a call that got through
changed nothing outside it.

- lefthook gives every `pre-push` script with `use_stdin: true` all of git's
  ref lines, not a share of them: three scripts in sequence, three under
  `parallel: true`, and one that read only the first line all left the others
  the full input. Each gets the remote as `$1` and its URL as `$2`, split at
  spaces first: on a push to a path holding a space, a script's `$1` is the
  path's first word.
- gitleaks runs `git -C . log -p -U0 <log-opts>`, so user config reaches it.
  With `--log-opts` holding only the range, a real finding passed with exit 0
  under `color.ui=always` or `color.diff=always`, a textconv driver,
  `log.showRoot=false` on a root commit, and a merge's own changes. Adding
  `--no-color --no-ext-diff --no-textconv --root --diff-merges=first-parent`
  closes all five. `diff.external` and `GIT_EXTERNAL_DIFF` never blinded it.
- gitleaks exits 0, "0 commits scanned", for an unknown sha and for a blob.
  It splits `--log-opts` at spaces and takes a quote as a plain character. So
  `gitleaks.sh`, run on its own with a path holding a space as `$1`, passed a
  real finding the same way; with a remote named `it's` or `q"x` it found it.
  git refuses a remote name with a space in it.
- Under `log.showRoot=false`, `git log -p` shows no diff for a root commit;
  `--root` brings it back.
- jq prints a map-row `error()` as
  `jq: error (at <stdin>:0): bad map row at line N`.
- git's parse-options takes any unique prefix of a long option. Measured
  through `git rev-parse --parseopt`, the same parser, with each command's
  long options from `--git-completion-helper-all`: `commit` and `push` take
  `--no-veri`, `--no-verif` and `--no-verify`, while `--no-v` to `--no-ver`
  are ambiguous with `--no-verbose`. `merge` takes only the full
  `--no-verify`: `--no-verify-signatures` makes every shorter prefix
  ambiguous. `--verify` and `--no-no-verify` are its negation, and run the
  hooks.
- Short flags cluster: `-anm msg` is `-a -n -m msg`. A flag that takes a
  value takes the rest of the cluster, or else the next word, so `-mn` and
  `-m -n` are messages; `-u` and `-S` take only a glued value, so `-uno` is
  `-u no`. An option after a pathspec still counts; nothing after `--` does.
- git's own options are not parse-options and never abbreviate. `-c` takes
  only a separate word (`-cfoo.bar=1` is an unknown option); `--config-env`,
  `--git-dir`, `--work-tree`, `--namespace` and `--attr-source` take either
  `=value` or the next word. A config name matches in any case:
  `-c FOO.BAR=2` reads back as `foo.bar`.
- The script lefthook installs in `.git/hooks` exits at once when `LEFTHOOK`
  is `0`.
- A refusal by a deny rule reads "Permission to use Bash with command … has
  been denied."; the auto-mode classifier refused none of the probes.
- A rule is matched against the text of each subcommand on its own. A
  compound is split at `&&`, `||`, `;`, `|`, `&` and newlines, and a command
  inside `( )`, `{ }`, an `if` or `for` body, `$( )`, backticks or `<( )` is
  one of its own: a bypass was refused in each of them. The line as a whole
  is not matched: `git push -n && echo --no-verify` and
  `echo GIT_CONFIG_KEY_0 && echo hooksPath` both ran.
- Except when a compound holds a `cd`: then its whole text is matched too.
  `cd <repo> && echo GIT_CONFIG_KEY_0 && echo hooksPath` was refused, by
  `Bash(*GIT_CONFIG_KEY_*ooks*ath*)`. That text starts with `cd`, so only a
  rule that starts with `*` can match it.
- Quotes are kept as typed, and `*` matches them like any other character:
  `git "commit" --no-verify -m x`, `git commit -m x "--no-verify"` and
  `"git" 'commit' -"n"` ran. Only a quoted program name is unquoted:
  `'LEFTHOOK=0' git push` was refused, and so was `g\it commit --no-verify`.
- Matching is case-sensitive: `git -c CORE.HOOKSPATH=/x push` ran.
- Besides the documented `timeout`, `time`, `nice`, `nohup`, `stdbuf`,
  `command` and `noglob`, 2.1.273 strips `env`, `sudo` and `exec`, which the
  documentation says it does not: `env git commit --no-verify -m x`,
  `sudo git commit -n -m x` and `exec git commit -n -m x` were refused.
  `echo x | xargs git commit -n -m` was refused too, and the refusal named
  only `xargs git commit -n -m`. `/usr/bin/git commit -n` ran.
- A rule is matched against the text with its leading assignments and with
  all of them stripped at once, never with some: `Bash(LEFTHOOK=0 *)` refused
  `LEFTHOOK=0 git push origin main`, and
  `FOO=1 LEFTHOOK=0 BAR=2 git merge topic` ran.
- A heredoc's operator, delimiter and body are dropped before matching, so
  `git commit -F - --no-verify <<'EOF'` was refused by a rule that wants
  `--no-verify` last, and no heredoc body is ever matched, not even inside
  `$( )`: an `echo "$(cat <<'EOF'` whose body holds `git push --no-verify`
  ran. A here-string keeps its text:
  `cat <<< "GIT_CONFIG_KEY_0=core.hooksPath is refused"` was refused.
- A file redirection drops itself and every word after it:
  `git commit -m x 2>&1 -n` ran. A comment is dropped:
  `git commit -m x --no-verify # hooks are slow` was refused, and
  `git status # ; git commit -n` ran. A line continuation does not split a
  command: `git commit \`, then `--no-verify -m x` on the next line, was
  refused.
- The corpus, `configs/claude/deny-corpus.tsv`, holds 359 commands, each
  with its right answer, not the rules', and the answer the live matcher
  gave. `bin/test-deny-rules` replays it through an offline replica of the
  matcher, which agrees with the live answer on all 359; each probe run after
  a change to the rules, 59 after the first and 76 after the second, came out
  as it predicted. The 146 deny rules, the 127 in "Private values" and 19
  older ones against destructive commands, get 297 right. The 62 they get
  wrong are the gaps listed there: 28 bypasses let through and 34 harmless
  commands refused, 2 of those by the older rules (`git clean -fdxn`,
  `git restore --staged .`). With the eight rules the first change replaced,
  the replica gets 168 wrong, all six commands named there among them.
- Replayed through the replica, 8,911 real Bash commands from Claude Code
  transcripts, none over 600 characters, meet 181 refusals, and each is a
  bypass, a probe written for these rules, or a destructive command the older
  rules refuse on purpose.

### From the documentation, checked 2026-09-24

- Memory: `AGENTS.md` direct reading from v2.1.277; project scope only; the
  default `claude-md-or-agents-md` suppresses it under any `CLAUDE.md`;
  `claude-md-and-agents-md` loads both and skips an `AGENTS.md` already
  loaded; `~/.claude/CLAUDE.md` does not count toward suppression. Before
  v2.1.281, sessions with telemetry disabled or on Bedrock read `CLAUDE.md`
  only — neither applies here.
- Auto mode: `autoMode` is read from `~/.claude/settings.json`, managed
  settings and `--settings`; never from `.claude/settings.json` or
  `.claude/settings.local.json` (the latter since v2.1.207). Entries from each
  scope combine.
- Managed settings: `managed-settings.json` and `managed-settings.d/*.json`
  under `/Library/Application Support/ClaudeCode/` merge together; across
  sources the default is `first-wins`, with server-managed settings ranked
  first.

## Deliberately out of scope

- **The Brewfile and the cask.** The terminal CLI stays on stable; the gap it
  leaves is named above and doctor reports it.
- **The rest of `~/.claude`**, including `memory/`, which no repo backs up.
  That is worth its own decision.
- **The leftovers of this morning's history rewrite**: the `*.pre-swap` files
  and the `dotclaude-backup-*.bundle` in `~/.claude`, and GitHub's garbage
  collection of dotclaude's pre-rewrite commits.
- **`.gitleaks.toml`'s title**, which still says `dotgit`.

## Open items

- **When stable reaches 2.1.277**, the version test passes with no change here.
  Nothing needs doing but running doctor.
- **The first session after an upgrade from 2.1.276 or earlier** may not read
  `AGENTS.md`, per the documentation; it does from the next session on.
- **The double-load question is moot.** It belonged to the import; with no
  `CLAUDE.md` there is nothing to load twice, and `claude-md-and-agents-md`
  skips an `AGENTS.md` already loaded in any case.
