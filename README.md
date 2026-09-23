# consus

The configuration this machine's tools actually read. It lives under `configs/`,
one directory per tool, and each tool finds it at its own default path, which is
a symlink into this repo:

```text
~/.config/git          →  <this clone>/configs/git
~/.config/fish         →  <this clone>/configs/fish
~/.proto/.prototools   →  <this clone>/configs/proto/.prototools
```

proto is the one tool whose path is not under `~/.config`, because proto never
reads `XDG_CONFIG_HOME`, and the one whose link is on a file rather than a
directory, because the 2.3 GB store is the directory.

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

Deliberately not managed: **zed**, whose settings-sync extensions are in flight
and would compete with anything versioned here; **opencode**, which has no
binary installed anywhere on this machine; **gh**, whose entire payload is
`git_protocol: https` plus one alias; and **micro**, whose payload is literally
`{}`.

## A fresh machine

The commands are in [INSTALL.md](INSTALL.md): the prerequisites, `chmod 700`
and `lefthook install`, the three links and the ghostty include, the
toolchains, fisher, and `bin/doctor` to verify. Six steps, run once per
machine.

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
  not name. `bin/doctor` reports such a file, which is the only way it becomes
  visible.
- **ghostty** — `~/.config/ghostty/local.ghostty`. The repo's config ends with
  an optional include of it, so a machine without one loads nothing and says
  nothing.
- **proto** — per-project pins belong in that project's own `.prototools`;
  the record here, `configs/proto/.prototools`, is only the global fallback
  proto uses when no project pin applies.

## The hazard of a linked directory

`~/.config/git` and `~/.config/fish` are symlinks **into this repo**, so
anything that writes through them writes here. In particular,
`rm -rf ~/.config/fish/` — with the trailing slash — follows the link and
empties this repo's `configs/fish/` directory. `git restore` brings back the six
tracked files; the other 91 need `fisher update` (which needs network), a tool
regenerating its own completions, or OrbStack running again.

`bin/doctor` exists because link integrity is the one invariant git cannot
express: this repo can be pristine while `~/.config` points somewhere else, and
for git and fish a severed link is completely silent.

proto's link is on a file, not a directory, so no `rm -rf` can empty a
directory through it — the 2.3 GB store it points into is unaffected. But a
severed link is silent in its own way: proto reports zero config files and
reverts to built-in defaults, including turning telemetry back on, with
nothing to warn you. That is what `bin/doctor` catches.

## Secret scanning

`lefthook` runs `gitleaks` over staged changes before every commit, once
`lefthook install` has been run in this clone — which `bin/doctor` asserts,
because a clone without it is silently unprotected until the next push.
`.github/workflows/gitleaks.yml` re-scans the full history on every push, as
the backstop `--no-verify` cannot bypass. Rules live in `.gitleaks.toml`, which
flags any committed email address that is not a GitHub noreply.

## Why any of this

The [design document][design] carries the eight mechanisms that were priced,
the five silent failure modes that killed the runner-up, the destruction
accounting, and the record of the migration itself.

[design]: docs/superpowers/specs/2026-08-21-consus-migration-design.md
