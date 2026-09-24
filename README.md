# consus

The configuration this machine's tools actually read. It lives under `configs/`,
one directory per tool, and each tool finds it at its own default path, which is
a symlink into this repo:

```text
~/.config/git            →  <this clone>/configs/git
~/.config/fish           →  <this clone>/configs/fish
~/.proto/.prototools     →  <this clone>/configs/proto/.prototools
~/.agents/agents.toml    →  <this clone>/configs/agents/agents.toml
~/.claude/settings.json  →  <this clone>/configs/claude/settings.json
~/.claude/AGENTS.md      →  <this clone>/configs/claude/AGENTS.md
~/.claude/hooks          →  <this clone>/configs/claude/hooks
~/.claude/scripts        →  <this clone>/configs/claude/scripts
```

proto, agents and claude are the tools whose paths are not under `~/.config`,
because none of proto, dotagents and Claude Code reads `XDG_CONFIG_HOME`. None
of them links the tool's own directory, because each holds far more than the
record: proto's 2.3 GB store, dotagents' installed skills, and Claude Code's
4 GB of sessions, transcripts and plugins. So proto and agents link a single
file, and claude links two files and two subdirectories, `hooks` and
`scripts`, which hold only tracked files.

Ghostty is the exception. Its winning config path on macOS is
`~/Library/Application Support/com.mitchellh.ghostty/config`, which no symlink
under `~/.config` can outrank, so it gets a one-line `config-file` include at
`~/.config/ghostty/config.ghostty`, naming `configs/ghostty/config.ghostty`
here.

## What is here

- **configs/git** — the global config, its two per-machine examples, and
  `ignore`, which is git's own default global excludes path.
- **configs/fish** — the hand-written configuration only: `config.fish`,
  `fish_plugins`, three files under `conf.d/` and one function. Everything
  fisher or a tool generated is ignored on purpose — `fish_plugins` is the
  record, and those 82 plugin files are its build output.
- **configs/ghostty** — four settings, plus an optional per-machine include.
- **configs/proto** — the global record, `.prototools`, nine pins — every
  toolchain this record owns. The 2.3 GB store itself stays outside the repo,
  at `~/.proto`.
- **configs/agents** — `agents.toml`, the `@sentry/dotagents` user-scope
  record. The lock and the installed skills stay in `~/.agents`; the
  directory's README says why, and what not to run there.
- **configs/claude** — `settings.json`, the global `AGENTS.md`, two hooks and
  the status-line script. Everything else in `~/.claude` stays there. Git
  stores placeholders for the private values in `settings.json`; the
  directory's README says how, and what not to do there.

Deliberately not managed: **zed**, whose settings-sync extensions are in flight
and would compete with anything versioned here; **opencode**, which has no
binary installed anywhere on this machine — dotagents still writes its MCP
config under `~/.config/opencode`, because the agents record keeps it as a
target, but nothing there is managed here; **gh**, whose entire payload is
`git_protocol: https` plus one alias; and **micro**, whose payload is literally
`{}`.

## A fresh machine

The commands are in [INSTALL.md](INSTALL.md): the prerequisites, `chmod 700`,
`lefthook install` and the placeholders filter, the eight links and the
ghostty include, the toolchains, fisher, the skills, and `bin/doctor` to
verify. Seven steps, run once per machine.

`bin/doctor` is the part that runs again — see "The hazard of a linked
directory" below for why it exists.

## Per-machine settings

- **git** — `configs/git/config-local`, untracked and included last, so it wins.
  Copy it from `configs/git/config-local.example`. Work identity goes in
  `configs/git/config-work`, which loads only inside `~/Developer/work/`; for
  that to match, that directory must be real all the way down and work repos
  must physically live inside it.
- **fish** — any new `conf.d/*.fish` file is machine-local by default: the
  allow-list in `.gitignore` ignores everything under `configs/fish/` it does
  not name. Such a file is invisible to a bare `git status` — not even as
  untracked — so `git status --ignored configs/fish` is how to find one, and a
  `.gitignore` negation is how to promote it into the record.
- **ghostty** — `~/.config/ghostty/local.ghostty`. The repo's config ends with
  an optional include of it, so a machine without one loads nothing and says
  nothing.
- **proto** — per-project pins belong in that project's own `.prototools`;
  the record here, `configs/proto/.prototools`, is only the global fallback
  proto uses when no project pin applies.
- **claude** — `~/.claude/placeholders.tsv`, the map from each private value
  to the placeholder git stores instead. It is untracked and nothing in this
  repo restores it, so it needs an off-machine backup: without it
  `settings.json` cannot be staged and the guards refuse every commit.
  `~/.claude/settings.local.json` and everything else in `~/.claude` stay
  machine-local.

## The hazard of a linked directory

`~/.config/git` and `~/.config/fish` are symlinks **into this repo**, so
anything that writes through them writes here. In particular,
`rm -rf ~/.config/fish/` — with the trailing slash — follows the link and
empties this repo's `configs/fish/` directory. `git restore` brings back the six
tracked files; the other 91 need `fisher update` (which needs network), a tool
regenerating its own completions, or OrbStack running again.

`bin/doctor` exists because link integrity is the one invariant git cannot
express: this repo can be pristine while `~/.config` points somewhere else, and
for git and fish a severed link is completely silent. It is a `bats` suite —
`bin/doctor.bats`, one named test per assertion, each carrying the measurement
that put it there — behind a wrapper that fixes the flags.

proto's link is on a file, not a directory, so no `rm -rf` can empty a
directory through it — the 2.3 GB store it points into is unaffected. But a
severed link is silent in its own way: proto reports zero config files and
reverts to built-in defaults, including turning telemetry back on, with
nothing to warn you. That is what `bin/doctor` catches.

claude has both kinds. `~/.claude/hooks` and `~/.claude/scripts` are directory
links, so `rm -rf ~/.claude/hooks/` empties `configs/claude/hooks/` — though
`git restore` recovers all of it, since nothing untracked lives there. The
`settings.json` link is the one that hurts to lose: with its target gone,
Claude Code reads empty settings without a word, and its next save writes a
`settings.json` holding only that one change into `configs/claude/`.
`bin/doctor` catches the dangling link; `git restore` undoes the rest.

## Secret scanning

`lefthook` runs `gitleaks` over staged changes before every commit, once
`lefthook install` has been run in this clone — which `bin/doctor` asserts,
because a clone without it is silently unprotected until the next push.
`.github/workflows/gitleaks.yml` re-scans the full history on every push, as
the backstop `--no-verify` cannot bypass. Rules live in `.gitleaks.toml`, which
flags any committed email address that is not a GitHub noreply.

A second guard keeps work terms out, and it covers every file and every commit
message, not only `settings.json`. `bin/placeholders` runs in lefthook's
`pre-commit`, `commit-msg` and `pre-push` hooks against the untracked map, and
fails closed: without the map nothing can be committed. Cherry-pick, rebase,
am and merge run no `pre-commit`, so `pre-push` is what sees their commits.
`bin/placeholders` is also the git filter that swaps each private value in
`configs/claude/settings.json` for its placeholder on the way into git and back
on checkout; `.gitattributes` names the file, and the filter itself is
per-clone git config (INSTALL.md step 2). Unlike gitleaks it cannot run in CI —
the map is private — so `pre-push` is its backstop. `settings.json`'s deny rules
keep Claude Code from retrying a refused commit or push with the hooks off:
`--no-verify`, `git commit -n`, or a `LEFTHOOK=0` or `LEFTHOOK=false` prefix.

## Why any of this

The [design document][design] carries the eight mechanisms that were priced,
the five silent failure modes that killed the runner-up, the destruction
accounting, and the record of the migration itself.

[design]: docs/superpowers/specs/2026-08-21-consus-migration-design.md
