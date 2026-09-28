# Install

On a fresh Mac, in order. Every step is idempotent except the links, which
never clobber but can refuse or land inside a directory — see "Traps".

1. The prerequisites, and the clone:

   ```sh
   brew install lefthook gitleaks proto jq bats-core
   git clone https://github.com/LRNZ09/dotconfigs.git ~/Developer/LRNZ09/dotconfigs
   cd ~/Developer/LRNZ09/dotconfigs
   ```

   `bats-core` is what `bin/doctor` runs on; `jq` is what it reads proto's
   manifests with. Both are in the [brewfile][brewfile] too, so a machine built
   from that already has them.

2. The repo's own settings. `~/.config` is mode 700 and the links lead here,
   but a fresh clone under `~/Developer` is 755; `lefthook install` is needed
   once per clone, so gitleaks and the work-term guard see each commit as well
   as every push; and the guard's term list lives in `.git/info/terms.tsv`,
   which no clone carries. Restore it from wherever its backup lives, mode 600:

   ```sh
   chmod 700 .
   lefthook install
   install -m 600 <backup>/terms.tsv .git/info/terms.tsv
   ```

   Until it is there, every commit is refused.

3. The four links and the ghostty include. `git` goes last on purpose: from
   the moment anything displaces `~/.config/git` until the link lands there is
   no global git config at all, so that window is kept to one command.

   ```sh
   mkdir -p ~/.config ~/.config/ghostty ~/.proto ~/.agents
   ln -s "$PWD/configs/fish" ~/.config/fish
   ln -s "$PWD/configs/proto/.prototools" ~/.proto/.prototools
   ln -s "$PWD/configs/agents/agents.toml" ~/.agents/agents.toml
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
   output. Each assertion, and the reason it exists, is one named test in
   `bin/doctor.bats`.

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
- `~/.config/git` and `~/.config/fish` are links **into this repo**, so
  `rm -rf ~/.config/fish/` — with the trailing slash — follows the link and
  empties `configs/fish/` here. See "The hazard of a linked directory" in the
  [README](README.md).
- There used to be a 714-line `bin/install` doing all of the above. It was
  built for a provisioner that no longer exists; step 3, less its agents link,
  is what it did.

[brewfile]: https://github.com/LRNZ09/brewfile
