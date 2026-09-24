# Install

On a fresh Mac, in order. Every step is idempotent except the links, which
refuse rather than clobber — see "Traps".

1. The prerequisites, and the clone:

   ```sh
   brew install lefthook gitleaks proto jq bats-core
   git clone https://github.com/LRNZ09/consus.git ~/Developer/LRNZ09/consus
   cd ~/Developer/LRNZ09/consus
   ```

   `bats-core` is what `bin/doctor` runs on; `jq` is what it reads proto's
   manifests with. Both are in the [brewfile][brewfile] too, so a machine built
   from that already has them.

[brewfile]: https://github.com/LRNZ09/brewfile

2. The repo's own two settings. `~/.config` is mode 700 and the links lead
   here, but a fresh clone under `~/Developer` is 755; `lefthook install` is
   needed once per clone, so gitleaks scans each commit as well as every push:

   ```sh
   chmod 700 .
   lefthook install
   ```

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

6. The skills. `npx` comes from step 4's node, and this must come after the
   link: run first, dotagents writes its own default `agents.toml` there.

   ```sh
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
- `ln -s` refuses when something is already at the path, and fish creates
  `~/.config/fish` on its first run — so on a machine that has started fish
  once, there will be. Move it aside rather than deleting it:
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
  built for a provisioner that no longer exists; step 3 is what it did.
