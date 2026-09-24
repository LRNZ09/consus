# agents

`agents.toml` here is the `@sentry/dotagents` user-scope record.
`~/.agents/agents.toml` is a link to it, made by hand (INSTALL.md step 3).
dotagents writes it with a plain in-place write, so `dotagents add`, `remove`,
`trust` and `mcp` land here as unstaged modifications, comments intact.

Everything else in `~/.agents` stays there and is not in this repo:

- **`agents.lock`** — dotagents' own machine state. In 3.1.0 `install` never
  reads it to resolve anything: it re-resolves every source from `agents.toml`
  on each run, so the lock records what was installed without being able to
  reproduce it. It only drives pruning, `sync` and `list`. Tracking it would
  turn every upstream push into a diff here.
- **`skills/`** — the installed copies. Two other tools write into it too: the
  `twg` CLI's `twg*` directories and Claude Code's `synced/` bucket. Neither is
  declared here, and neither should be.

## Traps

- **Never run `dotagents sync` here.** It adopts every undeclared directory
  under `skills/` — the `twg*` ones and `synced/` — as `path:skills/<name>`
  entries, which then break `install` on any machine without them. `install`
  and `doctor` cover everything else `sync` does.
- **A missing target is loud in the worst way.** If `agents.toml` disappears
  from this directory while the directory stays — a rename or `git rm` of the
  file — every dotagents command but `doctor`, `trust list` included, writes a
  default config through the link into this repo, and the next `install`
  prunes every skill. `git restore configs/agents/agents.toml`, then
  `npx @sentry/dotagents --user install`. `bin/doctor` reports the dangling
  link.
- **`remove <skill>` does nothing against a multi-line `exclude`.** It prints
  "Added … to exclude list" and leaves the file unchanged, so the next install
  restores the skill. Both `getsentry/skills` and `anthropics/skills` use that
  form here: edit the list by hand.
- **`trust add` and `trust remove` rebuild the `github_orgs` line**, dropping
  any comment on the same line. Removing a block leaves the comment above it
  behind.
- **`add getsentry/skills <skill>` fails**, because that source is a plugin
  marketplace. Use the wildcard entry and its `exclude` list.
- **Two wildcard sources that provide the same name stop `install`.** Add the
  name to one source's `exclude`.

## Guard rails

`[trust]` limits sources to four GitHub orgs. `minimum_release_age` holds every
source's commits back seven days, except `LRNZ09/*`. The `dotagents` skill is
pinned at 3.1.0, the same version as the CLI, which runs unpinned through
`npx`.

The in-place write was measured on 3.1.0. dotagents already writes other files
by temp-file-and-rename, so a later release could replace the link with a
regular file; `bin/doctor`'s link test is what would notice.
