# Install

On a fresh Mac, in order. Every step is idempotent except the links, which
never clobber but can refuse or land inside a directory — see "Traps".

1. The prerequisites, and the clone:

   ```sh
   brew install lefthook gitleaks proto jq bats-core
   git clone https://github.com/LRNZ09/consus.git ~/Developer/LRNZ09/consus
   cd ~/Developer/LRNZ09/consus
   ```

   `bats-core` is what `bin/doctor` runs on; `jq` is what it reads proto's
   manifests with, and what `bin/placeholders` rewrites `settings.json` with.
   Both are in the [brewfile][brewfile] too, so a machine built from that
   already has them.

2. The repo's own settings. `~/.config` is mode 700 and the links lead here,
   but a fresh clone under `~/Developer` is 755; `lefthook install` is needed
   once per clone, so gitleaks and the work-term guard see each commit as well
   as every push; and the placeholders filter is per-clone git config, which
   no clone carries. First restore the map, from wherever its off-machine
   backup lives, as `~/.claude/placeholders.tsv`, mode 600 (`mkdir -p
   ~/.claude` first on a machine where Claude Code never ran). Then:

   ```sh
   chmod 700 .
   lefthook install
   git config filter.placeholders.clean 'bin/placeholders clean'
   git config filter.placeholders.smudge 'bin/placeholders smudge'
   git config filter.placeholders.required true
   test -r ~/.claude/placeholders.tsv && test ! -L ~/.claude/settings.json && git show :configs/claude/settings.json | cmp -s - configs/claude/settings.json && rm configs/claude/settings.json && git restore configs/claude/settings.json
   ```

   The last line re-checks `settings.json` out through the filter: the clone
   wrote it before the filter existed, so it holds placeholders. It acts only
   once the map is in place and while the file is unlinked and still
   byte-identical to what git stores, so running it again never touches the
   live settings.

3. The eight links and the ghostty include. `git` goes last on purpose: from
   the moment anything displaces `~/.config/git` until the link lands there is
   no global git config at all, so that window is kept to one command.

   ```sh
   mkdir -p ~/.config ~/.config/ghostty ~/.proto ~/.agents ~/.claude
   ln -s "$PWD/configs/fish" ~/.config/fish
   ln -s "$PWD/configs/proto/.prototools" ~/.proto/.prototools
   ln -s "$PWD/configs/agents/agents.toml" ~/.agents/agents.toml
   ln -s "$PWD/configs/claude/settings.json" ~/.claude/settings.json
   ln -s "$PWD/configs/claude/AGENTS.md" ~/.claude/AGENTS.md
   ln -sn "$PWD/configs/claude/hooks" ~/.claude/hooks
   ln -sn "$PWD/configs/claude/scripts" ~/.claude/scripts
   printf 'config-file = %s\n' "$PWD/configs/ghostty/config.ghostty" \
   	> ~/.config/ghostty/config.ghostty
   ln -s "$PWD/configs/git" ~/.config/git
   ```

4. The toolchains:

   ```sh
   proto install --config-mode global
   ```

5. fisher. A fresh clone has `fish_plugins` and no fisher at all — fisher's own
   two files are among the ignored ones, so the command that reads the record
   does not exist yet:

   ```fish
   curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
   fisher install jorgebucaran/fisher   # makes fisher itself permanent
   fisher update                        # materialises the rest from fish_plugins
   ```

6. The skills. `npx` is only on `PATH` via step 5's fish, which proto's
   `conf.d/proto.fish` activates — zsh never gets it from `proto install`
   alone. Run this in that same fish shell, and after the link: run first,
   dotagents writes its own default `agents.toml` there.

   ```fish
   npx @sentry/dotagents --user install
   ```

7. Verify:

   ```sh
   ./bin/doctor
   ```

   It exits 0 when this machine matches the record, and names whatever does
   not — so a run of this list that stopped halfway is finished by reading its
   output. The one expected failure until the stable cask reaches 2.1.277 is
   `claude is 2.1.277 or later` — see "Traps". Each assertion, and the reason
   it exists, is one named test in `bin/doctor.bats`.

## Traps

- `--config-mode global` is not optional. A bare `proto install` defaults to
  `upwards` mode, never loads the global record at all, and reports "nothing to
  install" while exiting 0.
- fish creates `~/.config/fish` on its first run, so on a machine that has
  started fish once, there is a directory at the path, and `ln -s` quietly
  puts the link inside it rather than refusing. Move it aside rather than
  deleting it first:
  `mv ~/.config/fish ~/config-fish.bak`. The old directory may hold
  `fish_variables`, which is every `set -U` value this machine had.
- On a machine where dotagents already ran, `~/.agents/agents.toml` is a
  regular file and `ln -s` refuses too. Move it aside the same way:
  `mv ~/.agents/agents.toml ~/agents.toml.bak`.
- On a machine where Claude Code already ran, `~/.claude/settings.json` is a
  regular file and `ln -s` refuses. Over an existing `hooks/` or `scripts/`
  directory, though, it does not refuse: it quietly puts the link inside it.
  Move all four aside first, where they exist, and never `~/.claude` itself,
  which holds the sessions, the transcripts, the plugins and the memory:
  `mkdir -m 700 ~/claude.bak`, then `mv ~/.claude/settings.json ~/claude.bak/`,
  and the same for `AGENTS.md`, `hooks` and `scripts`. Anything worth keeping
  goes back in through the links, into the record.
- The terminal `claude` below 2.1.277 reads no `AGENTS.md` at all, and nothing
  here gives it a `CLAUDE.md`, so its sessions run without the global
  instructions. The stable cask was 2.1.273 on 2026-09-24; `bin/doctor`
  reports the version until it catches up.
- `~/.config/git` and `~/.config/fish` are links **into this repo**, so
  `rm -rf ~/.config/fish/` — with the trailing slash — follows the link and
  empties `configs/fish/` here. See "The hazard of a linked directory" in the
  [README](README.md).
- There used to be a 714-line `bin/install` doing all of the above. It was
  built for a provisioner that no longer exists; step 3, less its agents and
  `~/.claude` links, is what it did.

[brewfile]: https://github.com/LRNZ09/brewfile
