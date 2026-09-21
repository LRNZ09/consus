# proto into consus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move proto's global `.prototools` into `consus` as
`configs/proto/.prototools`, reached through a file symlink at proto's own
path, and archive `LRNZ09/dotproto` — without moving the 2.3 GB store, without
setting `PROTO_HOME`, and without a human at the keyboard.

**Architecture:** The store stays where proto puts it. `bin/install` gains a
third path whose record is a single *file* rather than a directory, because
`PROTO_HOME` relocates the whole store and cannot separate the record from the
2.3 GB of toolchains around it. proto rewrites `.prototools` in place, so the
symlink survives its writes and a `proto pin` lands in the repo as an ordinary
unstaged modification. `bin/doctor` gains the link assertion plus the check
that earns its place — declared-but-not-installed, read from each tool's
`manifest.json`.

**Tech Stack:** POSIX `sh` (both scripts must pass `sh -n`), proto 0.62.2 via
Homebrew, fish 4.8.0, `jq` 1.8.2 (declared in sancus's `Brewfile:68`), git
2.55.0, lefthook, gitleaks, `gh` for the archive.

**Spec:** `docs/superpowers/specs/2026-09-21-proto-into-consus-design.md` —
read it alongside this plan. Every "why" lives there; this plan argues from it
and does not restate its measurements.

## Running this unattended

Every task here is executable with nobody watching, on the same three
conditions the 2026-08-21 plan established:

1. **No command waits on a human.** `bin/install`'s prompt is replaced by
   `--resolve proto=overwrite` in Task 8. `gh repo archive` takes `--yes`.
   `GIT_EDITOR=false` makes an accidental editor invocation fail rather than
   hang.
2. **Every check is a command with an exit code.** No step asserts in prose.
3. **Nothing is hand-carried between tasks.** Values live in a state file every
   task sources.

**Before going AFK, Task 0 must pass.** It verifies a signed commit completes
without a passphrase prompt, that `gh` is authenticated, and that `jq` and
Homebrew's proto are both present.

This plan has no equivalent of the 2026-08-21 plan's Task 13 review queue. The
record it installs is a file this plan writes, so there is no second version of
it to reconcile.

## Global Constraints

Every task's requirements implicitly include this section.

- **Clone path:** `~/Developer/LRNZ09/consus`, already present, on `main`.
- **State file:** `~/Backups/proto-consus.env`. Tasks append `KEY=value` lines
  and later tasks open with `. ~/Backups/proto-consus.env`.
- **Nothing on this machine is ever deleted.** Every displaced path is *moved*
  into `~/Backups/proto-consus-<timestamp>/`, including Task 1's self-installed
  proto and Task 2's `~/.proto/.git`. Three narrow exceptions, none of them a
  machine path: Task 3 removes a `.protolock` it created one line earlier inside
  the repo, Task 7's fixture builder wipes and rebuilds its own scratch
  directory under `$SP` on every run, and the rollback removes a *symlink* this
  plan created, which never touches the link's target.
- **Backups never go to `~/Desktop` or `~/Documents`** — both are iCloud-synced.
  `~/Backups` only, mode `700`.
- **The store is never moved.** No task runs `mv` on `~/.proto` itself. Measured
  and recorded in the spec: 24 text files under `tools/ruby/4.0.5/` hard-code
  the absolute store path in shebangs and `rbconfig.rb`, and `proto regen` does
  not rewrite them.
- **`PROTO_HOME` is never set by anything this plan writes.** Not in
  `conf.d/proto.fish`, not in the record, not in either script. The scripts
  *read* it, mirroring proto's own precedence, so a machine that sets it for its
  own reasons still gets the right store.
- **Store resolution, in both scripts, is exactly proto's:** `PROTO_HOME`, then
  `$XDG_DATA_HOME/proto`, then `$HOME/.proto`. Any other spelling is a bug.
- **Environment for the whole run:**

  ```sh
  export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 GIT_EDITOR=false
  export PROTO_YES=1 PROTO_REPORTER=text
  ```

  `PROTO_YES` is proto's own `--yes`, and it belongs here for the same reason
  `GH_PROMPT_DISABLED` does: several steps run proto, and with
  `auto-install = true` a resolution can offer to install. `PROTO_REPORTER=text`
  keeps proto's agent-mode NDJSON out of every captured output in this plan, not
  only out of fish.
- **Every destructive step guards its variables.** A step that moves or removes
  anything opens with:

  ```sh
  set -eu
  . ~/Backups/proto-consus.env
  : "${STORE:?}" "${BK:?}" "${CLONE:?}"
  ```

  Without this, a state file that failed to source — renamed, truncated, a
  different `$HOME` under the runner — expands the variables empty and turns
  `mv "$STORE/bin/proto" "$BK/..."` into something aimed at `/`. The sandbox
  suite already does this; the plan's own steps must too.

- **Every commit passes `-m` or `-F -`.** No `git rebase -i`, no
  `git commit --amend`, no `git config --edit`.
- **Both scripts stay POSIX `sh`** with `#!/bin/sh` and `set -eu`, and must pass
  `sh -n`. Hard tabs for indentation, matching the existing files.
- **`.gitignore`: no pattern may carry a trailing comment.** gitignore honours
  `#` only at the start of a line.
- **Never commit a non-noreply email address.** `.gitleaks.toml` flags every
  email that is not `*@users.noreply.github.com`.
- **`bin/doctor` stays read-only and network-free.** It must not run
  `proto pin` (measured: downloads plugin WASM), `proto install`, or
  `proto status` (measured: exits 0 while failing). Reading
  `tools/<tool>/manifest.json` is the whole check.
- **Never assert a proto version in `bin/doctor`.** Which binary answers depends
  on which shell ran it; the divergence is reported, not gated.
- **`npm = "bundled"` is not a version.** The pin check skips any spec that does
  not start with a digit, which covers `bundled` and every alias.
- **`tools/<tool>/<version>/` is not a reliable installed-check.** Measured:
  `tools/rust/` contains only manifests — rust 1.97.0 is installed and
  `installed_versions` says so, but no version directory exists, because proto's
  rust support defers to `~/.rustup`. Always read `manifest.json`. The spec's
  "Verified facts" predates this measurement and says "directories"; Task 9
  corrects it.
- **A pin may be a version *prefix*.** `proto pin node 22 --to global` writes
  `node = "22"`, while the manifest records `22.23.1`. An exact-match lookup
  would report that as missing forever, so the check accepts an exact match or a
  match on `<pin>.` as a prefix.
- **Zero extracted pins is a failure, not a pass.** A check that finds nothing
  to check must say so rather than print the green line.
- **The record's settings key is `unstable-lockfile` until Task 1 lands.** It is
  the same field as `lockfile`; a file carrying both fails with
  `duplicate field`. Task 3 writes `lockfile`, which is only safe because Task 1
  has already removed proto 0.58.2.
- **`gh repo archive` is reversible**; `gh repo delete` is not. This plan never
  deletes a repository.

## Execution order, and the one gate

- **Task 0** changes nothing and must pass first.
- **Tasks 1–2** change this machine and are worth doing whether or not the rest
  proceeds: Task 1 fixes a live breakage (`proto status`), Task 2 removes a
  checkout that can silently restore an old record over the link.
- **Tasks 3–6** happen entirely inside the clone. `~/.proto` is untouched.
- **Task 7 is the gate.** The two scripts ship with a sandbox suite that runs
  them against a redirected `PROTO_HOME` and `XDG_CONFIG_HOME`. **No step in
  Task 8 or later may start until Task 7 passes.**
- **Task 8** is the only one that changes the shape of `~/.proto`.
- **Tasks 9–10** are documentation and the archive.

## File Structure

```text
~/Developer/LRNZ09/consus/
├── README.md                          Task 9  — four of the six contract items
├── .gitignore                         Task 3  — one defensive line
├── bin/install                        Task 5  — classify_file, the proto path
├── bin/doctor                         Task 6  — the link, the pin check
├── configs/
│   ├── fish/conf.d/proto.fish         Task 4  — PROTO_REPORTER, corrected prose
│   └── proto/                         Task 3  — NEW
│       ├── .prototools                the record: 9 pins, 6 settings
│       └── README.md                  the knowledge dotproto held
└── docs/superpowers/
    ├── specs/2026-09-21-proto-into-consus-design.md   committed as 2c6cea1
    ├── specs/2026-08-21-consus-migration-design.md    Task 9 — 5 edits
    └── plans/2026-09-21-proto-into-consus.md          this plan
```

Nothing under `configs/proto/` is generated, so it needs no allow-list block —
proto is on the ghostty side of that line, not the fish side. The single
`.gitignore` rule is defensive, for a `.protolock` a stray `proto` run inside
that directory would drop there.

One scratch file, `tests-proto.sh`, lives under `$SP` and is **deliberately not
committed**, matching how the 2026-08-21 plan treats its five harness scripts.
The spec fixes the repo layout and adding a `tests/` directory is not a decision
this plan gets to make.

---

### Task 0: The unattended-run preflight

**Files:**

- Create: `~/Backups/proto-consus.env` (state file; never committed)

**Interfaces:**

- Consumes: nothing.
- Produces: `~/Backups/proto-consus.env`, defining `CLONE`, `SP`, `STORE`,
  `BK`, exporting `GH_PROMPT_DISABLED`, `GH_NO_UPDATE_NOTIFIER` and
  `GIT_EDITOR`. Every later task opens with `. ~/Backups/proto-consus.env`.

- [ ] **Step 1: Harden the working directories**

```sh
mkdir -p ~/Backups
chmod 700 ~/Backups
test "$(stat -f '%Lp' ~/Backups)" = 700
mkdir -p ~/Backups/proto-consus-sandbox
chmod 700 ~/Backups/proto-consus-sandbox
```

- [ ] **Step 2: Write the state file**

```sh
# Refuse to clobber an existing run's state. Later tasks APPEND to this file
# (BASELINE_COMMITS, DOTPROTO_HEAD, PROTO_REVIEW_DIGEST), so rewriting it
# mid-migration both mints a new BK — orphaning every backup already made — and
# truncates the values the remaining tasks and the rollback depend on.
if [ -e ~/Backups/proto-consus.env ]; then
	echo "state file already exists — resuming, not re-initialising." >&2
	echo "To start over, move it aside first:" >&2
	echo "  mv ~/Backups/proto-consus.env ~/Backups/proto-consus.env.old" >&2
	exit 1
fi

# Resolve the store the way proto does — PROTO_HOME, then $XDG_DATA_HOME/proto,
# then $HOME/.proto — once, here, so every task acts on the same one.
proto_store=$(
	if [ -n "${PROTO_HOME:-}" ]; then echo "$PROTO_HOME"
	elif [ -n "${XDG_DATA_HOME:-}" ]; then echo "$XDG_DATA_HOME/proto"
	else echo "$HOME/.proto"; fi
)

# The heredoc is UNQUOTED on purpose: every value below is expanded now and
# written as a literal.
cat > ~/Backups/proto-consus.env <<EOF
# proto-into-consus migration state. Sourced by every task in
# docs/superpowers/plans/2026-09-21-proto-into-consus.md.
# Appended to as the migration progresses; never committed.
#
# Every value here is a literal, resolved once when this file was written.
# Never reintroduce a command substitution: it would re-evaluate on every
# source. Measured — a timestamp written as one produced two different
# directories when sourced one second apart, which scatters the backups and
# breaks every later assertion against BK.

export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 GIT_EDITOR=false

CLONE="$HOME/Developer/LRNZ09/consus"
SP="$HOME/Backups/proto-consus-sandbox"
BK="$HOME/Backups/proto-consus-$(date +%Y%m%dT%H%M%S)"
STORE="$proto_store"

export CLONE SP BK STORE
EOF
. ~/Backups/proto-consus.env
test -d "$CLONE"
test -d "$STORE"
```

- [ ] **Step 2a: Assert the state file is stable across sources**

```sh
. ~/Backups/proto-consus.env
grep -q '\$(' ~/Backups/proto-consus.env &&
	{ echo "FAIL: the state file contains a command substitution"; exit 1; }
b1="$BK"; s1="$STORE"
( . ~/Backups/proto-consus.env; test "$BK" = "$b1" && test "$STORE" = "$s1" ) ||
	{ echo "FAIL: the state file is not stable across sources"; exit 1; }
test "${BK#"$HOME"/Backups/}" != "$BK" || { echo "FAIL: BK is not under ~/Backups"; exit 1; }
```

This is not ceremony. `BK` is the single directory every displaced path is moved
into, and the rollback reads it — if it differed between tasks, Task 1 would
back up to one directory and Task 8 would assert against another, and both would
look fine until a rollback was needed.

- [ ] **Step 3: Assert the tools this plan cannot work around**

```sh
. ~/Backups/proto-consus.env
command -v jq >/dev/null || { echo "FAIL: jq missing — brew install jq"; exit 1; }
command -v gh >/dev/null || { echo "FAIL: gh missing"; exit 1; }
command -v lefthook >/dev/null || { echo "FAIL: lefthook missing"; exit 1; }
command -v gitleaks >/dev/null || { echo "FAIL: gitleaks missing"; exit 1; }
command -v markdownlint-cli2 >/dev/null ||
	{ echo "FAIL: markdownlint-cli2 missing — Tasks 3, 9 lint with it"; exit 1; }
command -v fish >/dev/null || { echo "FAIL: fish missing"; exit 1; }
test -x /opt/homebrew/bin/proto || { echo "FAIL: Homebrew proto missing — brew install proto"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authenticated"; exit 1; }

# A stray ~/.prototools would outrank the record for everything under $HOME —
# measured, the user scope is the upwards walk reaching $HOME, so it shadows the
# global file for every repo in the home tree. It does not exist today. If one
# appears, the migration's record would be silently overridden for most work.
test ! -e "$HOME/.prototools" ||
	{ echo "FAIL: $HOME/.prototools exists and would shadow the record"; exit 1; }
```

- [ ] **Step 4: Assert a signed commit completes without a prompt**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
test -z "$(git status --porcelain)" || { echo "FAIL: tree is dirty"; exit 1; }
test "$(git rev-parse --abbrev-ref HEAD)" = main
git log -1 --pretty='%G?' | grep -qx G || { echo "FAIL: HEAD is not a good signature"; exit 1; }

# The check above verifies an OLD signature, which exercises no key material and
# proves nothing about producing a NEW one. Every task here commits, so what
# actually has to work is signing without a passphrase prompt. Exercise the key
# directly rather than making a throwaway commit on main.
key=$(git config --get user.signingkey) ||
	{ echo "FAIL: no user.signingkey configured"; exit 1; }
test -n "$key" || { echo "FAIL: user.signingkey is empty"; exit 1; }
if [ "$(git config --get gpg.format || echo openpgp)" = ssh ]; then
	echo "NOTE: ssh signing — no passphrase path to probe"
else
	echo probe | gpg --batch --yes --local-user "$key" --armor --detach-sign \
		-o /dev/null 2>"$SP/sign.err" ||
		{ echo "FAIL: gpg cannot sign unattended — unlock the key first"; \
		  cat "$SP/sign.err"; exit 1; }
fi
```

`%G?` is quoted because `?` is a glob under zsh and the command fails with
`no matches found` unquoted. `--batch` is what makes the probe meaningful: it
forbids an interactive passphrase prompt, so a locked key fails here — loudly,
before anything has changed — instead of hanging at the first commit.

- [ ] **Step 5: Record the baseline**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
echo "BASELINE_COMMITS=$(git rev-list --count HEAD)" >> ~/Backups/proto-consus.env
echo "BASELINE_HEAD=$(git rev-parse HEAD)" >> ~/Backups/proto-consus.env
. ~/Backups/proto-consus.env
test -n "$BASELINE_COMMITS"
```

---

### Task 1: Phase 0 — make Homebrew's proto the only one

`~/.proto/bin/proto` is a byte-identical copy of
`~/.proto/tools/proto/0.58.2/proto` — proto manages itself as one of its own
tools — and activation prepends
`~/.proto/bin`, so it shadows Homebrew's 0.62.2 permanently. That shadow is a
live breakage, not a tidiness question: `proto status` exits 0 while failing,
because the record's plugins require ≥ 0.60.0.

This task is worth doing whether or not the rest of the plan proceeds.

**Files:**

- Modify: `$STORE/bin/proto` (moved to backups)
- Modify: `$STORE/tools/proto/` (moved to backups)

**Interfaces:**

- Consumes: Task 0's state file.
- Produces: a machine where `proto` resolves to `/opt/homebrew/bin/proto`.

- [ ] **Step 1: Record what is there now**

```sh
. ~/Backups/proto-consus.env
/opt/homebrew/bin/proto --version
"$STORE/bin/proto" --version
shasum -a 256 "$STORE/bin/proto" "$STORE/tools/proto/0.58.2/proto"
```

Expected: the two sha256 values are identical, and the versions differ.

- [ ] **Step 2: Move both aside — never delete**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${BK:?}"
test -f "$STORE/bin/proto" || { echo "FAIL: nothing to move — already done?"; exit 1; }
mkdir -p "$BK/proto-self-install"
mv "$STORE/bin/proto" "$BK/proto-self-install/proto"
mv "$STORE/tools/proto" "$BK/proto-self-install/tools-proto"
test ! -e "$STORE/bin/proto"
test ! -e "$STORE/tools/proto"
test -f "$BK/proto-self-install/proto"
```

- [ ] **Step 3: Assert Homebrew's proto now answers**

```sh
. ~/Backups/proto-consus.env
hash -r 2>/dev/null || true
v=$(PROTO_REPORTER=text /opt/homebrew/bin/proto --version)
echo "$v" | grep -q '0\.62' || { echo "FAIL: unexpected version: $v"; exit 1; }
```

The check runs the absolute path rather than a bare `proto`: this shell still
carries the old `_PROTO_ACTIVATED_PATH`, and a bare name would prove nothing
about a *new* shell. Task 8 asserts the new shell.

- [ ] **Step 4: Assert `proto status` recovers**

```sh
. ~/Backups/proto-consus.env
PROTO_REPORTER=text /opt/homebrew/bin/proto status 2>&1 | tee "$SP/status-after.txt"
grep -qi 'error' "$SP/status-after.txt" && { echo "FAIL: status still reports an error"; exit 1; }
true
```

If this still fails, stop: the record in Task 3 is written on the assumption
that a working 0.62.2 is what reads it.

---

### Task 2: Phase 1 — retire the dotproto checkout

While `$STORE/.git` exists it claims ownership of `$STORE/.prototools`, so any
`git checkout`, `git switch` or `git pull` run there restores the old record
over the link Task 8 installs, and `git status` reports the repo's version as
modified.

**Files:**

- Modify: `$STORE/.git` (moved to backups)
- Modify: `$STORE/.gitignore` (moved to backups)

**Interfaces:**

- Consumes: Task 1's state.
- Produces: a `$STORE` that no git command owns.

- [ ] **Step 1: Assert the checkout is clean and pushed before displacing it**

```sh
. ~/Backups/proto-consus.env
cd "$STORE"
test -z "$(git status --porcelain)" || { echo "FAIL: dotproto checkout is dirty"; exit 1; }
git fetch origin main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || { echo "FAIL: not pushed"; exit 1; }
echo "DOTPROTO_HEAD=$(git rev-parse HEAD)" >> ~/Backups/proto-consus.env
```

Anything uncommitted here would survive only as a backup nobody reads. Task 10
needs `DOTPROTO_HEAD` to confirm the archive matches what was displaced.

- [ ] **Step 2: Move `.git` and `.gitignore` aside**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${BK:?}"

# Assert BEFORE moving, not after. $STORE/.git currently masks any repo rooted
# at an ancestor of the store; the moment it moves, the store's 64,660 entries
# become an untracked subtree of whatever that ancestor is — and this step
# removes its .gitignore in the same breath. If an ancestor repo exists, stop.
( cd "$STORE/.." && git rev-parse --show-toplevel >/dev/null 2>&1 ) &&
	{ echo "FAIL: $STORE has an ancestor git repo — moving .git would expose the store to it"; exit 1; }

mkdir -p "$BK/dotproto"
mv "$STORE/.git" "$BK/dotproto/.git"
mv "$STORE/.gitignore" "$BK/dotproto/.gitignore"
test ! -e "$STORE/.git"
test -d "$BK/dotproto/.git"
```

`.gitignore` goes too: it is dotproto's deny-by-default allow-list and protects
nothing once no repo is rooted there. `README.md`, `.prototools` and
`.protolock` stay in place — Task 8 replaces `.prototools`, and the other two
are left for now so a rollback has something to read.

- [ ] **Step 3: Assert no repo is rooted at the store**

```sh
. ~/Backups/proto-consus.env
test ! -e "$STORE/.git" || { echo "FAIL: $STORE/.git survives"; exit 1; }
top=$( cd "$STORE" && git rev-parse --show-toplevel 2>/dev/null || true )
test -z "$top" || { echo "FAIL: $STORE is inside the repo at $top"; exit 1; }
```

`git rev-parse --show-toplevel` walks *upward*, so it answers "is the store
inside any repo", not "is there a repo here" — which is the question that
matters, and the reason Step 2 refuses when an ancestor repo exists. Its output
is captured rather than discarded: the old form suppressed stderr but let the
path print, so a failure announced itself as a bare directory name.

---

### Task 3: Phase 2 — the record and its README

**Files:**

- Create: `configs/proto/.prototools`
- Create: `configs/proto/README.md`
- Modify: `.gitignore` — one rule appended

**Interfaces:**

- Consumes: Task 1's working 0.62.2, which is what makes `lockfile` safe.
- Produces: `configs/proto/.prototools`, the link target every later task names.

- [ ] **Step 1: Write the record**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
mkdir -p configs/proto
cat > configs/proto/.prototools <<'EOF'
# proto's global record. Reached through a symlink at $PROTO_HOME/.prototools,
# so proto edits this file directly and a `proto pin` shows up in git status.
# The store itself — 2.3 GB of toolchains — stays outside this repo.

bun = "1.3.14"
deno = "2.9.2"
go = "1.26.5"
node = "26.5.0"
npm = "bundled"
python = "3.14.6"
ruby = "4.0.5"
rust = "1.97.0"
yarn = "4.17.1"

[settings]
auto-clean = true
auto-install = true
detect-strategy = "prefer-prototools"
lockfile = true
pin-latest = "global"
telemetry = false
EOF
```

Nine pins, down from eleven. `openjdk` and `zig` are gone with the
`[plugins.tools]` block that existed only for them — both have
`installed_versions: []`, and `openjdk` is a dormant conflict with the
`JAVA_HOME` that `configs/fish/conf.d/android.fish` sets for exactly that
reason.

- [ ] **Step 2: Assert proto parses it and the settings survive**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"

# Validate in a throwaway directory. `--config-mode local` reads ./.prototools
# from the CWD, so running it here — where there is no .prototools — parses
# nothing and passes vacuously. Copying the record somewhere it is genuinely the
# local config is what makes this a test. The scratch directory also absorbs any
# .protolock a local-mode run drops beside it.
d=$(mktemp -d)
cp configs/proto/.prototools "$d/.prototools"
( cd "$d" && /opt/homebrew/bin/proto debug config --config-mode local --json ) \
	>"$SP/parsed.json" 2>"$SP/parsed.err" ||
	{ echo "FAIL: proto rejected the record"; cat "$SP/parsed.err"; rm -rf "$d"; exit 1; }
rm -rf "$d"

grep -q 'duplicate field' "$SP/parsed.err" &&
	{ echo "FAIL: lockfile/unstable-lockfile collision"; exit 1; }

# Assert content, not exit status. proto exits 0 on an empty config, so these
# are what distinguish "parsed our record" from "parsed nothing".
jq -e '.config.settings.telemetry == false' "$SP/parsed.json" >/dev/null ||
	{ echo "FAIL: telemetry is not false"; exit 1; }
jq -e '.config.settings.lockfile == true' "$SP/parsed.json" >/dev/null ||
	{ echo "FAIL: lockfile is not true"; exit 1; }
n=$(jq -r '[.config | keys[]] - ["plugins", "settings", "shell"] | length' "$SP/parsed.json")
test "$n" -eq 9 || { echo "FAIL: expected 9 pins, parsed $n"; exit 1; }
jq -e '.config | has("openjdk") or has("zig") | not' "$SP/parsed.json" >/dev/null ||
	{ echo "FAIL: a dropped pin survives"; exit 1; }
```

The shape these assertions address was measured, not assumed: the top-level keys
of `proto debug config --json` are exactly `config`, `files` and `locks`, the
pinned tools are **direct keys of `.config`** alongside `plugins`, `settings`
and `shell` — there is no `.config.versions` — and `unstable-lockfile`
normalises to `lockfile` in the parsed output.

- [ ] **Step 3: Write `configs/proto/README.md`**

````sh
. ~/Backups/proto-consus.env
cd "$CLONE"
cat > configs/proto/README.md <<'EOF'
# proto

`.prototools` here is proto's **global** record. `$PROTO_HOME/.prototools` is a
symlink to it, placed by `bin/install`, so proto reads and writes this file
directly and a `proto pin` arrives as an unstaged modification.

Everything else in the store — `bin/`, `shims/`, `tools/`, `plugins/`, `cache/`,
`builders/`, `temp/`, `backends/`, the `id` file, and whatever proto adds next —
is not in this repo and never should be. The list is illustrative, not
exhaustive: proto creates directories at the store root over time, and the rule
is that the record is the only thing here, not that those are the only things
there. `PROTO_HOME` relocates all of it at once, so there is no way to keep the
record here and the payload elsewhere by moving the variable. consus does not
set `PROTO_HOME`; proto's own default is what runs.

## Three things that are not in the upstream docs

**`proto uninstall` strips the pin from every `.prototools` on the chain.** Not
just the global one — local, every ancestor directory, `user` and `global`
alike, and with no version argument the removal is unconditional. An uninstall
run inside one project can silently edit an unrelated project's `.prototools`
two directories up. With `pin-latest = "global"` set, the follow-up
`proto install` then resolves *latest* and writes that back as the new pin. That
is how a version sweep happens without anyone choosing one. To reinstall at the
pinned version: uninstall, re-pin, then install.

**Do not unify the plugin locator styles.** `github://owner/repo` resolves
release *assets*, so it cannot address a plugin published as a plain file on a
branch, which can only be named by raw URL. Tidying a raw URL into the
`github://` form silently stops it resolving. No locators are configured today —
proto 0.62 made them unnecessary for community tools — but the trap is waiting
for whoever adds the next one.

**`--to global` follows `$PROTO_HOME`, not a literal path.** proto's own
`pin --help` says `~/.proto/.prototools` and is wrong whenever the variable is
set.

## Upgrading

`brew upgrade proto`. Never `proto upgrade`: it self-replaces the running
executable, and since the Homebrew Cellar is user-writable it would overwrite
the Cellar behind Homebrew's back, leaving `brew` reporting a version it no
longer ships.

## Restoring toolchains

```sh
proto install --config-mode global
```

The mode is not optional. The default is `upwards`, not the documented
`upwards-global`, so a bare `proto install` from outside the store reports
"nothing to install" and exits 0.

## What is not tracked

`.protolock`. It is inert at global scope, is written only when the current
directory is inside the store, and carries no entry for ruby or rust. The last
snapshot of it is in `LRNZ09/dotproto`, archived.
EOF
````

- [ ] **Step 4: Append the `.gitignore` rule**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
cat >> .gitignore <<'EOF'

# proto writes .protolock next to any .prototools it treats as local, so a
# stray proto run inside this directory drops one here. The record is the
# pins; the lockfile is inert at global scope and is not tracked.
/configs/proto/.protolock
EOF
```

Every annotation sits on its own line. A trailing comment would become part of
the pattern and match nothing.

- [ ] **Step 5: Assert the ignore rule works and the right files stage**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
: > configs/proto/.protolock
git check-ignore -q configs/proto/.protolock || { echo "FAIL: .protolock not ignored"; exit 1; }
rm -f configs/proto/.protolock
git add configs/proto .gitignore
test "$(git diff --cached --name-only | grep -c '^configs/proto/')" -eq 2
git diff --cached --name-only | grep -qx 'configs/proto/.prototools'
git diff --cached --name-only | grep -qx 'configs/proto/README.md'
```

The `rm -f` here is on a file this step created one line earlier, inside the
repo. It is not a machine path and the never-delete rule does not reach it.

- [ ] **Step 6: Lint and commit**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
markdownlint-cli2 configs/proto/README.md
git commit -m "Track the proto record"
test -z "$(git status --porcelain)"
```

---

### Task 4: Phase 2 — correct `conf.d/proto.fish`

Two claims in this tracked file are wrong. The NDJSON wart it calls unfixable is
fixable, and "brew is the install source" became unambiguously true only in
Task 1.

**Files:**

- Modify: `configs/fish/conf.d/proto.fish` (whole file rewritten)

**Interfaces:**

- Consumes: Task 1's removal of the shadowing binary.
- Produces: a fish startup with zero stderr output in agent environments.

- [ ] **Step 1: Reproduce the wart, so the fix is measured and not assumed**

```sh
. ~/Backups/proto-consus.env

# env -u is essential: the state file exports PROTO_REPORTER=text for the whole
# run, so without removing it the "before" case cannot reproduce anything and
# the comparison below would pass no matter what.
env -u PROTO_REPORTER /opt/homebrew/bin/fish -c 'proto activate fish | source' \
	>"$SP/ndjson-before.txt" 2>&1 || true
env PROTO_REPORTER=text /opt/homebrew/bin/fish -c 'proto activate fish | source' \
	>"$SP/ndjson-after.txt" 2>&1 || true

test ! -s "$SP/ndjson-after.txt" ||
	{ echo "FAIL: PROTO_REPORTER=text did not silence it"; cat "$SP/ndjson-after.txt"; exit 1; }
if [ -s "$SP/ndjson-before.txt" ]; then
	echo "reproduced: $(wc -l < "$SP/ndjson-before.txt") lines without PROTO_REPORTER, 0 with it"
else
	echo "NOTE: no NDJSON here — proto only emits it in an agent environment."
	echo "      The fix is still correct; this shell just cannot demonstrate it."
fi
```

- [ ] **Step 2: Rewrite the file**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
cat > configs/fish/conf.d/proto.fish <<'EOF'
# proto version manager (https://moonrepo.dev/docs/proto)
# proto comes from Homebrew and is the only copy on this machine. A
# self-installed $PROTO_HOME/bin/proto would shadow it permanently, because
# activation prepends that directory to PATH — which is what happened before
# 2026-09-21, leaving an older proto answering every command.
#
# Activation prepends the shims and the real tool bin dirs from the nearest
# .prototools, applies immediately, and re-applies on every cd and prompt, in
# interactive and non-interactive shells alike. No manual PATH setup is needed,
# and PROTO_HOME is deliberately not set: proto's own default is the store, and
# setting it here would make it exist only inside fish.
#
# PROTO_REPORTER is load-bearing, not cosmetic. In agent environments proto
# emits NDJSON, which `source` cannot parse — roughly 20 lines of errors per
# shell start. It has to be `set -gx` rather than a one-shot prefix: activation
# re-runs through a fish hook whose body shells out to
# `proto activate fish --export`, and only an exported variable reaches that
# inner call. Measured — `proto activate fish -r text` does not work, because
# the flag never propagates.
if type -q proto
    set -gx PROTO_REPORTER text
    proto activate fish | source
end
EOF
```

- [ ] **Step 3: Assert a clean startup and that activation still works**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
/opt/homebrew/bin/fish -c 'true' 2>"$SP/startup.err"
test ! -s "$SP/startup.err" || { echo "FAIL: fish startup wrote to stderr"; cat "$SP/startup.err"; exit 1; }
/opt/homebrew/bin/fish -c 'echo $PROTO_REPORTER' 2>/dev/null | grep -qx text
/opt/homebrew/bin/fish -c 'type -q node; and echo ok' 2>/dev/null | grep -qx ok
```

The startup assertion is the one that matters: it is the whole point of the
change, and it fails loudly if `set -gx` is ever demoted to a prefix.

- [ ] **Step 4: Commit**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
git add configs/fish/conf.d/proto.fish
git commit -m "Silence proto's agent-mode NDJSON in fish"
test -z "$(git status --porcelain)"
```

---

### Task 5: Phase 3 — `bin/install` learns the proto file link

**Files:**

- Modify: `bin/install` — header comment (lines 30–34), `KNOWN_PATHS` (41),
  `usage()` (43–47), the merge guard message (98), the plan scalars (239–240),
  a new `show_file_diff()` and `classify_file()` after `classify_stub()` (376),
  the classify calls (406–409), `check_slot` calls (424–426), the slot sum
  (432), and a new `apply_file()` plus its call before `apply_path git` (521).

**Interfaces:**

- Consumes: `configs/proto/.prototools` from Task 3.
- Produces: `bin/install --resolve proto=<overwrite|refuse>`, and a link at
  `$STORE/.prototools`. Task 7's suite exercises it; Task 8 runs it for real.

- [ ] **Step 1: Widen the path vocabulary**

Replace `KNOWN_PATHS='fish git'` at line 41 with:

```sh
KNOWN_PATHS='fish git proto'
```

Replace every `<fish|git>` with `<fish|git|proto>` — lines 33, 34, 45 and 46.

The file's own header contract at lines 4–10 lists the paths it manages and must
gain proto, or the script documents the opposite of what it does:

```sh
#   $XDG_CONFIG_HOME/fish                    -> <repo>/configs/fish  (symlink)
#   $XDG_CONFIG_HOME/ghostty/config.ghostty                  (one-line include)
#   $PROTO_HOME/.prototools    -> <repo>/configs/proto/.prototools  (file link)
#   $XDG_CONFIG_HOME/git                     -> <repo>/configs/git   (symlink, last)
```

with a sentence below it noting that proto is the one path not under
`$XDG_CONFIG_HOME`, because proto never reads that variable, and the one whose
link is on a file rather than a directory, because the directory is a 2.3 GB
store.

Then line 98's message becomes:

```sh
		echo "install: --resolve $a_rel=merge: merge is only defined for fish" >&2
		echo "  the git and proto paths take overwrite or refuse" >&2
```

- [ ] **Step 2: Resolve the store the way proto does**

Immediately after the `record=` assignment (near line 160), add:

```sh
# proto's store, in proto's own precedence order. proto never reads
# XDG_CONFIG_HOME, so its record is the one path here that is not under
# $config_home — and it is a single file, because PROTO_HOME relocates the
# whole 2.3 GB store and cannot separate the record from it.
if [ -n "${PROTO_HOME:-}" ]; then
	proto_store="$PROTO_HOME"
elif [ -n "${XDG_DATA_HOME:-}" ]; then
	proto_store="$XDG_DATA_HOME/proto"
else
	proto_store="$HOME/.proto"
fi
proto_path="$proto_store/.prototools"
proto_target="$record/proto/.prototools"
```

The run's header block — the one that prints `repo:`, `record:`, `config home:`
and `backups:` — gains a line, so an unattended log records which of the three
candidate stores was chosen rather than leaving it to be inferred:

```sh
echo "  proto store: $proto_store"
```

- [ ] **Step 3: Add the file diff, next to `show_diff`**

```sh
# show_file_diff <rel> <machine-file> — the file analogue of show_diff. Sets
# diff_digest to a digest of the listing printed below, so the digest commits to
# what a reader actually reviewed. The two header lines of `diff -u` are dropped
# because they carry absolute paths, which would make the digest differ between
# clones of the same content.
show_file_diff() {
	f_rel="$1"
	f_m="$2"

	: > "$d_listing"
	if cmp -s -- "$f_m" "$proto_target"; then
		echo "  identical" >> "$d_listing"
	else
		# Machine first, repo second, so a `-` line is what goes away and a `+`
		# line is what arrives when the repo wins. Reversed, a reviewer reads
		# the consequence of overwrite exactly backwards.
		diff -u -- "$f_m" "$proto_target" | tail -n +3 >> "$d_listing" || true
	fi
	# A diff that produced nothing printable — a binary difference, whose whole
	# report is the single line `tail -n +3` just discarded — would otherwise
	# leave an empty listing and hand back the digest of an empty file, making
	# every such difference look identical to every other. Fall back to content
	# hashes, which the digest then commits to.
	if [ ! -s "$d_listing" ] && ! cmp -s -- "$f_m" "$proto_target"; then
		printf '  differ, not as text\n    machine %s  repo %s\n' \
			"$(shasum -a 256 -- "$f_m" | cut -c1-12)" \
			"$(shasum -a 256 -- "$proto_target" | cut -c1-12)" >> "$d_listing"
	fi

	diff_digest=$(shasum -a 256 < "$d_listing" | cut -c1-12)

	echo "  --- $f_m  vs  $proto_target   (- machine, + repo) ---"
	cat -- "$d_listing"
	echo "  --- end of diff, digest $f_rel=$diff_digest ---"
}
```

- [ ] **Step 4: Add `classify_file`, after `classify_stub`**

```sh
# classify_file <rel> <machine-file> — the file analogue of classify. Merge is
# undefined here: for a single TOML file the only honest actions are overwrite,
# which moves the machine's file to the backup and lets the repo win, and
# refuse. That is the same pair the git path takes, for the same reason.
classify_file() {
	c_rel="$1"
	c_path="$2"
	plan_result=''
	slot_result=0

	if [ ! -f "$proto_target" ]; then
		echo "✖ $c_rel: the record is missing — $proto_target is not in this clone" >&2
		unresolved=$((unresolved + 1))
		plan_result=refuse
		return 0
	fi
	# A directory here is not a record. Without this, cmp and diff both exit 2
	# writing to unredirected stderr, the listing comes out empty, the digest
	# becomes the sha of an empty file, and --resolve proto=overwrite moves the
	# whole directory into the backup slot on the strength of a diff that showed
	# nothing.
	if [ -e "$c_path" ] && [ ! -L "$c_path" ] && [ ! -f "$c_path" ]; then
		echo "✖ $c_path is not a regular file — refusing rather than treating it as a record" >&2
		unresolved=$((unresolved + 1))
		plan_result=refuse
		return 0
	fi
	if [ -e "$c_path" ] && [ ! -L "$c_path" ] && [ ! -r "$c_path" ]; then
		echo "✖ $c_path is not readable — refusing rather than diffing it partially" >&2
		unresolved=$((unresolved + 1))
		plan_result=refuse
		return 0
	fi
	c_declared=$(already_keyed "$resolutions" "$c_rel")

	if [ -L "$c_path" ]; then
		if [ "$(readlink -- "$c_path")" = "$proto_target" ]; then
			echo "✓ ok         $c_path -> $proto_target (already linked)"
			[ -z "$c_declared" ] || echo "· note      --resolve $c_rel=$c_declared was not needed here"
			plan_result=ok
			return 0
		fi
		echo "→ relink     $c_path is a link to $(readlink -- "$c_path")"
		[ -z "$c_declared" ] || echo "· note      --resolve $c_rel=$c_declared was not needed here"
		plan_result=relink
		slot_result=1
		return 0
	fi

	if [ ! -e "$c_path" ]; then
		echo "→ link       $c_path (nothing there)"
		[ -z "$c_declared" ] || echo "· note      --resolve $c_rel=$c_declared was not needed here"
		plan_result=link
		return 0
	fi

	echo "‼ $c_path is a real file, and the record lives at $proto_target"
	show_file_diff "$c_rel" "$c_path"

	if [ -n "$c_declared" ]; then
		echo "→ declared   $c_path: $c_declared (--resolve $c_rel=$c_declared)"
		c_answer="$c_declared"
	elif [ "$non_interactive" -eq 1 ] || [ ! -t 0 ]; then
		echo "✖ $c_path: a real file is in the way, nothing was declared for it and there is no TTY to ask — refusing" >&2
		echo "  re-run from a terminal, or declare the decision:" >&2
		echo "    --resolve $c_rel=overwrite" >&2
		unresolved=$((unresolved + 1))
		plan_result=refuse
		return 0
	else
		printf 'Resolve %s — [o]verwrite (repo wins) / [r]efuse: ' "$c_path"
		read -r c_answer || c_answer=refuse
	fi

	case "$c_answer" in
	o | O | overwrite)
		plan_result=overwrite
		slot_result=1
		;;
	*)
		if [ -n "$c_declared" ]; then
			echo "✖ $c_path: refused as declared, nothing will change" >&2
		else
			echo "✖ $c_path: refused, nothing will change" >&2
		fi
		unresolved=$((unresolved + 1))
		plan_result=refuse
		;;
	esac
}
```

- [ ] **Step 5: Wire it into plan, validate and apply**

Line 239–240 gain a third scalar:

```sh
plan_fish=''; plan_git=''; plan_stub=''; plan_proto=''
slot_fish=0; slot_git=0; slot_stub=0; slot_proto=0
```

The classify calls gain one, after the stub and before git:

```sh
classify_file proto "$proto_path"; plan_proto="$plan_result"; slot_proto="$slot_result"
```

The slot checks and the sum:

```sh
check_slot "$slot_proto" proto/.prototools
```

```sh
if [ "$unresolved" -eq 0 ] && [ $((slot_fish + slot_stub + slot_proto + slot_git)) -ne 0 ]; then
```

Then a new apply function beside `apply_path`:

```sh
apply_file() {
	p_rel="$1"
	p_plan="$2"
	p_path="$3"

	case "$p_plan" in
	ok) ;;
	link | relink | overwrite)
		[ "$p_plan" = link ] || move_aside "$p_rel/.prototools" "$p_path"
		mkdir -p -- "$(dirname -- "$p_path")"
		ln -s -- "$proto_target" "$p_path"
		if [ "$p_plan" = overwrite ]; then
			echo "✓ linked     $p_path -> $proto_target (the repo's content wins)"
		else
			echo "✓ linked     $p_path -> $proto_target"
		fi
		;;
	*)
		echo "✖ apply_file: unreachable plan '$p_plan' for $p_rel" >&2
		exit 1
		;;
	esac
}
```

and its call, placed immediately before `apply_path git "$plan_git"`:

```sh
apply_file proto "$plan_proto" "$proto_path"
```

proto goes before git for the same reason everything does: git's backup-move and
link creation must stay adjacent, because in that window there is no global git
config at all.

- [ ] **Step 6: Assert the script still parses**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
sh -n bin/install
grep -c '<fish|git>' bin/install | grep -qx 0 ||
	{ echo "FAIL: a <fish|git> literal survives"; exit 1; }
bin/install --resolve proto=merge 2>&1 | grep -q 'merge is only defined for fish' ||
	{ echo "FAIL: proto=merge is not rejected"; exit 1; }
bin/install --resolve proto=bogus 2>&1 | grep -q "unknown action 'bogus'" ||
	{ echo "FAIL: a bogus action is accepted"; exit 1; }
bin/install --resolve nope=overwrite 2>&1 | grep -q "unknown path 'nope'" ||
	{ echo "FAIL: an unknown path is accepted"; exit 1; }
```

All three invocations exit 2, but each line is a *pipeline* whose status is
grep's, so `set -e` is safe here and needs no accommodation. **Never append
`|| true` to an assertion** — it makes the assertion pass unconditionally, which
is worse than not having written it.

These three are safe to run against the real machine: `usage()` exits inside the
argument loop, before the script resolves `$repo`, before it probes for lefthook
and before it creates its temporaries, so nothing is read and nothing is
written. Note that `sh -n` is a syntax check only — the first execution of
`classify_file`, `show_file_diff` and `apply_file` is Task 7, which is why that
task is the gate.

- [ ] **Step 7: Commit**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
git add bin/install
git commit -m "Teach bin/install the proto file link"
test -z "$(git status --porcelain)"
```

---

### Task 6: Phase 3 — `bin/doctor` learns the link and the pins

**Files:**

- Modify: `bin/doctor` — the temp files and trap (19–20), a
  `check_file_link()` beside `check_link()` (30–44), the store resolution and
  the proto call after line 46, and a new proto block before the review queue
  (160).

**Interfaces:**

- Consumes: `configs/proto/.prototools`, and `bin/install`'s link.
- Produces: a doctor that exits non-zero on a severed proto link or an
  uninstalled pin.

- [ ] **Step 1: Add a fourth temp file**

```sh
present=$(mktemp); classified=$(mktemp); unclassified=$(mktemp); pins=$(mktemp)
trap 'rm -f "$present" "$classified" "$unclassified" "$pins"' EXIT
```

- [ ] **Step 2: Add `check_file_link`, beside `check_link`**

```sh
# check_file_link <label> <machine-file> <repo-file> — the file analogue of
# check_link. proto's record is a single file at proto's own path, which is not
# under $config_home: proto never reads XDG_CONFIG_HOME.
check_file_link() {
	f_label="$1"
	f_path="$2"
	f_target="$3"
	if [ ! -L "$f_path" ]; then
		echo "✖ $f_path is not a symlink (expected -> $f_target)" >&2
		return 1
	fi
	f_current=$(readlink -- "$f_path")
	if [ "$f_current" != "$f_target" ]; then
		echo "✖ $f_path -> $f_current (expected -> $f_target)" >&2
		return 1
	fi
	# A link whose target is gone still reads back correctly, so readlink alone
	# would report a DANGLING link as healthy — and a dangling record is exactly
	# the state this check exists to catch: proto reads nothing and silently
	# reverts to its built-in defaults, telemetry included.
	if [ ! -e "$f_path" ]; then
		echo "✖ $f_path -> $f_target, but the target does not exist" >&2
		return 1
	fi
	echo "✓ link       $f_path -> $f_target"
}
```

- [ ] **Step 3: Resolve the store and assert the link**

After the existing `check_link fish` line, add:

```sh
if [ -n "${PROTO_HOME:-}" ]; then
	proto_store="$PROTO_HOME"
elif [ -n "${XDG_DATA_HOME:-}" ]; then
	proto_store="$XDG_DATA_HOME/proto"
else
	proto_store="$HOME/.proto"
fi
proto_link_ok=0
if check_file_link proto "$proto_store/.prototools" "$record/proto/.prototools"; then
	proto_link_ok=1
else
	failed=1
fi
```

and declare `proto_link_ok=0` beside `fish_link_ok=0` at line 17.

- [ ] **Step 4: Add the pin check, before the review queue**

```sh
# --- proto: declared, then installed -----------------------------------------
# The analogue of the fish plugin check: .prototools is to tools/ what
# fish_plugins is to the 82 fisher files. Gated on the link, because a record
# read through a severed link is proto's built-in defaults rather than this
# repo's, and asserting against those would mean nothing.
#
# manifest.json rather than tools/<tool>/<version>/: measured, tools/rust holds
# only manifests, because proto's rust support defers to ~/.rustup. A directory
# test would report the installed rust as missing, forever.
#
# Never `proto status`: it exits 0 while failing. Never `proto pin`: it reaches
# the network. This check reads two files and runs no proto at all.
if [ "$proto_link_ok" -eq 0 ]; then
	echo "· proto      skipped — $proto_store/.prototools is not the expected link"
elif ! command -v jq >/dev/null 2>&1; then
	echo "· proto      jq not installed — skipped the pin check (brew install jq)"
elif [ ! -f "$record/proto/.prototools" ]; then
	# Belt and braces. check_file_link already rejects a dangling link, so this
	# normally cannot fire — it covers the residue, such as a target that exists
	# but is a directory. It earns its place anyway: without it the awk below is
	# a simple command under `set -e`, so an unreadable record would abort doctor
	# at exit 2 with a raw "can't open file", skipping the review queue and the
	# closing summary, which is not the contract the file header states.
	echo "✖ $record/proto/.prototools is not a readable file" >&2
	failed=1
else
	# Top-level keys only: in TOML everything before the first table belongs to
	# the root, and everything after belongs to that table. `exit` is therefore
	# correct — but it also means a record whose first line is a table yields
	# nothing, so the count below is what stops "checked nothing" reading as
	# "everything is fine".
	# sub(/#.*/) first: TOML allows a trailing comment, and without stripping it
	# `node = "26.5.0"  # keep` yields the version `26.5.0#keep`, which starts
	# with a digit, gets looked up, and reports a false "not installed". No
	# version string contains a #, so removing everything from the first one is
	# safe here.
	awk '/^\[/ { exit }
	     /^[A-Za-z]/ && /=/ { sub(/#.*/, ""); gsub(/["[:space:]]/, "")
	                          n = index($0, "=")
	                          if (n > 1 && length($0) > n)
	                              print substr($0, 1, n - 1), substr($0, n + 1) }' \
		"$record/proto/.prototools" > "$pins"
	missing=0
	checked=0
	while read -r p_tool p_ver; do
		[ -n "$p_tool" ] || continue
		# bundled, latest and every alias resolve at call time; only a concrete
		# version can be looked for in a manifest.
		case "$p_ver" in
		[0-9]*) ;;
		*) continue ;;
		esac
		checked=$((checked + 1))
		p_manifest="$proto_store/tools/$p_tool/manifest.json"
		# A pin may be a prefix: `proto pin node 22` writes "22" while the
		# manifest records "22.23.1". An exact match would call that missing
		# forever. Matching on "$p_ver." rather than a bare prefix keeps 2 from
		# matching 22.23.1.
		if [ ! -f "$p_manifest" ] ||
			! jq -e --arg v "$p_ver" \
				'.installed_versions // [] | any(. == $v or startswith($v + "."))' \
				"$p_manifest" >/dev/null 2>&1; then
			echo "✖ declared but not installed: $p_tool $p_ver" >&2
			missing=$((missing + 1))
		fi
	done < "$pins"
	if [ "$checked" -eq 0 ]; then
		echo "✖ no pins found in configs/proto/.prototools — the record is empty or malformed" >&2
		failed=1
	elif [ "$missing" -ne 0 ]; then
		echo "✖ declared but not installed: $missing — run: proto install --config-mode global (needs network)" >&2
		failed=1
	else
		echo "✓ proto      all $checked pinned versions are installed"
	fi
fi

# Advisory, and deliberately OUTSIDE the block above. A self-installed proto in
# the store shadows Homebrew's, because activation prepends the store's bin. If
# this report were gated on the link check and on jq, it would go quiet in
# exactly the situations where drift is most likely. Never assert a version
# here: which binary answers depends on which shell ran this script.
if [ -e "$proto_store/bin/proto" ]; then
	echo "· proto      $proto_store/bin/proto exists and shadows Homebrew's on PATH."
	echo "·            brew upgrade proto cannot reach it. Advisory — this never fails."
fi
```

Note there is deliberately **no unclassified-entries report**. The fish version
of that arithmetic closes only because fisher keeps a file-level manifest; proto
keeps none, so the same mechanism would print one advisory line per store entry
— over 55,000 of them.

- [ ] **Step 5: Assert the script parses and the check is right**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
sh -n bin/doctor
```

The behavioural assertions live in Task 7, which can build the fixtures this
needs.

- [ ] **Step 6: Commit**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
git add bin/doctor
git commit -m "Teach bin/doctor the proto link and pins"
test -z "$(git status --porcelain)"
```

---

### Task 7: The gate — a sandbox suite for both scripts

**No step in Task 8 or later may start until this task exits 0.**

**Files:**

- Create: `$SP/tests-proto.sh` (scratch; never committed)

**Interfaces:**

- Consumes: `bin/install` and `bin/doctor` from Tasks 5 and 6.
- Produces: an exit code. Nothing else.

- [ ] **Step 1: Write the suite**

```sh
. ~/Backups/proto-consus.env
cat > "$SP/tests-proto.sh" <<'SUITE'
#!/bin/sh
# tests-proto.sh — exercises the proto path in bin/install and bin/doctor
# against a throwaway fixture. No real path is touched: every run redirects
# both XDG_CONFIG_HOME and PROTO_HOME into $SB.
set -eu
REPO=${REPO:?set REPO to the consus clone under test}
SB=${SB:?set SB to a scratch directory}

f=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1" >&2; f=$((f + 1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --- fixture --------------------------------------------------------------
# A standalone copy of the clone, re-inited so git status means something
# without touching the real clone's history.
fixture() {
	rm -rf "$SB/fx"
	mkdir -p "$SB/fx"
	# git archive, not a working-tree copy: it takes TRACKED files only, which
	# is what a fresh clone has. A tar of the working tree would drag in the
	# ignored per-machine files — configs/git/config-local carries the signing
	# key — plus the .remember/ tree, and nothing here would ever remove them.
	git -C "$REPO" archive HEAD | tar -C "$SB/fx" -xf -
	# Neutralise proto activation inside the fixture. bin/doctor runs `fish -c`,
	# fish sources conf.d/proto.fish, and that would run `proto activate`
	# against the empty sandbox store with auto-install on — which reaches the
	# network and can stall the gate. No proto assertion below goes through
	# fish, so emptying this file costs the suite nothing.
	: > "$SB/fx/configs/fish/conf.d/proto.fish"
	( cd "$SB/fx" && git init -q && git config core.hooksPath /dev/null &&
	  git config user.email "t@users.noreply.github.com" &&
	  git config user.name t && git config commit.gpgsign false &&
	  git add -A && git commit -qm base )
	rm -rf "$SB/store" "$SB/xdg" "$SB/bk"
	mkdir -p "$SB/store" "$SB/xdg"
}

run() {
	env XDG_CONFIG_HOME="$SB/xdg" PROTO_HOME="$SB/store" \
		"$SB/fx/bin/install" --non-interactive --backup-dir "$SB/bk" "$@"
}
doctor() {
	env XDG_CONFIG_HOME="$SB/xdg" PROTO_HOME="$SB/store" "$SB/fx/bin/doctor" "$@"
}
target() { echo "$SB/fx/configs/proto/.prototools"; }

echo "== install: nothing there -> link =="
fixture
run >/dev/null 2>&1 || true
check "link created" '[ -L "$SB/store/.prototools" ]'
check "link points at the record" '[ "$(readlink "$SB/store/.prototools")" = "$(target)" ]'

echo "== install: re-run is a no-op =="
run 2>/dev/null | grep -q "already linked" && ok "reports already linked" || bad "no already-linked line"

echo "== install: a real file, nothing declared, no TTY -> refuse =="
fixture
printf 'node = "1.0.0"\n' > "$SB/store/.prototools"
before=$(shasum -a 256 < "$SB/store/.prototools")
out=$(run 2>&1 || true)
check "refused" 'echo "$out" | grep -q "refusing"'
check "printed a digest" 'echo "$out" | grep -q "digest proto="'
check "machine file untouched" '[ "$(shasum -a 256 < "$SB/store/.prototools")" = "$before" ]'
check "still not a link" '[ ! -L "$SB/store/.prototools" ]'

echo "== install: --resolve proto=overwrite =="
out=$(run --resolve proto=overwrite 2>&1 || true)
check "linked" '[ -L "$SB/store/.prototools" ]'
check "machine file moved to the backup" '[ -f "$SB/bk/proto/.prototools" ]'
check "backup holds the machine content" 'grep -q "1.0.0" "$SB/bk/proto/.prototools"'

echo "== install: the digest commits to content, not to names =="
fixture
printf 'node = "1.0.0"\n' > "$SB/store/.prototools"
d1=$(run 2>&1 | sed -n 's/.*digest proto=\([0-9a-f]*\).*/\1/p' | head -1)
printf 'node = "2.0.0"\n' > "$SB/store/.prototools"
d2=$(run 2>&1 | sed -n 's/.*digest proto=\([0-9a-f]*\).*/\1/p' | head -1)
check "digest is 12 hex characters" '[ ${#d1} -eq 12 ]'
check "editing the machine file changes the digest" '[ "$d1" != "$d2" ]'

echo "== install: a directory at the store path is refused, not diffed =="
fixture
mkdir -p "$SB/store/.prototools"
out=$(run --resolve proto=overwrite 2>&1 || true)
check "refused as not a regular file" 'echo "$out" | grep -q "not a regular file"'
check "the directory is still there" '[ -d "$SB/store/.prototools" ]'
check "nothing was moved to the backup" '[ ! -e "$SB/bk/proto/.prototools" ]'
rm -rf "$SB/store/.prototools"

echo "== install: --resolve proto=refuse =="
fixture
printf 'node = "1.0.0"\n' > "$SB/store/.prototools"
out=$(run --resolve proto=refuse 2>&1 || true)
check "refused as declared" 'echo "$out" | grep -q "refused as declared"'
check "unchanged" '[ ! -L "$SB/store/.prototools" ]'

echo "== install: merge is rejected for proto =="
out=$(run --resolve proto=merge 2>&1 || true)
check "merge rejected" 'echo "$out" | grep -q "merge is only defined for fish"'

echo "== install: a wrong link self-heals without a TTY =="
fixture
ln -s /nowhere/else "$SB/store/.prototools"
run >/dev/null 2>&1 || true
check "relinked" '[ "$(readlink "$SB/store/.prototools")" = "$(target)" ]'
check "old link moved aside" '[ -L "$SB/bk/proto/.prototools" ]'

echo "== install: an occupied backup slot refuses before anything moves =="
fixture
printf 'node = "1.0.0"\n' > "$SB/store/.prototools"
mkdir -p "$SB/bk/proto"; : > "$SB/bk/proto/.prototools"
out=$(run --resolve proto=overwrite 2>&1 || true)
check "slot refused" 'echo "$out" | grep -q "slot"'
check "nothing moved" '[ ! -L "$SB/store/.prototools" ]'

echo "== install: a missing record refuses rather than linking to nothing =="
fixture
mv "$SB/fx/configs/proto/.prototools" "$SB/fx/configs/proto/.prototools.away"
out=$(run 2>&1 || true)
check "missing record refused" 'echo "$out" | grep -q "the record is missing"'
check "no dangling link" '[ ! -e "$SB/store/.prototools" ]'
mv "$SB/fx/configs/proto/.prototools.away" "$SB/fx/configs/proto/.prototools"

echo "== doctor: a severed link fails =="
fixture
run >/dev/null 2>&1 || true
rm -f "$SB/store/.prototools"
if doctor >/dev/null 2>&1; then bad "doctor passed with no link"; else ok "doctor failed on a severed link"; fi

echo "== doctor: a wrong link is named =="
ln -s /nowhere/else "$SB/store/.prototools"
out=$(doctor 2>&1 || true)
check "names the wrong target" 'echo "$out" | grep -q "/nowhere/else"'

echo "== doctor: a DANGLING link fails and still reaches the summary =="
# The link reads back correctly here; only its target is gone. readlink alone
# calls that healthy, which is the state proto answers by silently reverting to
# built-in defaults with telemetry back on.
fixture
run >/dev/null 2>&1 || true
mv "$SB/fx/configs/proto/.prototools" "$SB/fx/configs/proto/.away"
check "link still reads back correctly" '[ "$(readlink "$SB/store/.prototools")" = "$(target)" ]'
check "but the target is gone" '[ ! -e "$SB/store/.prototools" ]'
out=$(doctor 2>&1 || true)
if doctor >/dev/null 2>&1; then bad "doctor passed with a dangling link"; else ok "doctor failed on a dangling link"; fi
check "the dangling target is named" 'echo "$out" | grep -q "the target does not exist"'
check "doctor reached its summary, not a raw tool error" 'echo "$out" | grep -q "doctor: findings above"'
check "no raw awk error" '! echo "$out" | grep -qi "can.t open file"'
mv "$SB/fx/configs/proto/.away" "$SB/fx/configs/proto/.prototools"

echo "== doctor: declared but not installed =="
fixture
run >/dev/null 2>&1 || true
out=$(doctor 2>&1 || true)
check "reports the uninstalled pins" 'echo "$out" | grep -q "declared but not installed"'

echo "== doctor: every pin installed passes the pin check =="
# Build a manifest for each concrete pin in the record.
awk '/^\[/ { exit }
     /^[A-Za-z]/ && /=/ { gsub(/["[:space:]]/, ""); n = index($0, "=")
                          print substr($0, 1, n - 1), substr($0, n + 1) }' \
	"$(target)" | while read -r t v; do
	case "$v" in [0-9]*) ;; *) continue ;; esac
	mkdir -p "$SB/store/tools/$t"
	printf '{"installed_versions":["%s"]}\n' "$v" > "$SB/store/tools/$t/manifest.json"
done
out=$(doctor 2>&1 || true)
check "pin check passes" 'echo "$out" | grep -q "pinned versions are installed"'
check "doctor exits 0" 'doctor >/dev/null 2>&1'

echo "== doctor: rust passes with no version directory =="
check "no tools/rust/<version> dir exists" '[ ! -d "$SB/store/tools/rust/1.97.0" ]'
check "rust not reported missing" '! echo "$out" | grep -q "declared but not installed: rust"'

echo "== doctor: a prefix pin matches a fuller installed version =="
# `proto pin node 22` writes "22" while the manifest records "22.23.1". An
# exact-match lookup would call that missing forever.
printf 'node = "22"\n' > "$SB/fx/configs/proto/.prototools"
mkdir -p "$SB/store/tools/node"
printf '{"installed_versions":["22.23.1"]}\n' > "$SB/store/tools/node/manifest.json"
out=$(doctor 2>&1 || true)
check "prefix pin accepted" '! echo "$out" | grep -q "declared but not installed: node"'
# ...but a prefix must not match a different major.
printf 'node = "2"\n' > "$SB/fx/configs/proto/.prototools"
out=$(doctor 2>&1 || true)
check "2 does not match 22.23.1" 'echo "$out" | grep -q "declared but not installed: node 2"'

echo "== doctor: a record with no top-level pins fails rather than passing =="
printf '[settings]\ntelemetry = false\n' > "$SB/fx/configs/proto/.prototools"
out=$(doctor 2>&1 || true)
check "empty record reported" 'echo "$out" | grep -q "no pins found"'
if doctor >/dev/null 2>&1; then bad "doctor passed on a record with no pins"; else ok "doctor failed on a record with no pins"; fi
git -C "$SB/fx" checkout -q -- configs/proto/.prototools

echo "== doctor: the shadowing binary is advisory, not a failure =="
mkdir -p "$SB/store/bin"; : > "$SB/store/bin/proto"
out=$(doctor 2>&1 || true)
check "shadow reported" 'echo "$out" | grep -q "shadows Homebrew"'
rm -f "$SB/store/bin/proto"

echo
if [ "$f" -ne 0 ]; then echo "FAILED: $f"; exit 1; fi
echo "all proto assertions passed"
SUITE
chmod +x "$SP/tests-proto.sh"
```

- [ ] **Step 2: Run it — this is the gate**

```sh
. ~/Backups/proto-consus.env
REPO="$CLONE" SB="$SP/sandbox" sh "$SP/tests-proto.sh"
```

Expected: `all proto assertions passed`, exit 0. Every failure names the
assertion. **Do not proceed past a non-zero exit.**

- [ ] **Step 3: Confirm the suite touched nothing real**

```sh
. ~/Backups/proto-consus.env
test ! -L "$STORE/.prototools" || { echo "FAIL: the suite linked the real store"; exit 1; }
cd "$CLONE"
test -z "$(git status --porcelain)"
```

---

### Task 8: Phase 4 — activate

**Files:**

- Modify: `$STORE/.prototools` — becomes a symlink; the real file goes to `$BK`

**Interfaces:**

- Consumes: Task 7's passing gate.
- Produces: the live link.

- [ ] **Step 1: Review pass — print the diff, change nothing**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${BK:?}" "${CLONE:?}"
cd "$CLONE"
./bin/install --non-interactive --backup-dir "$BK" 2>&1 | tee "$SP/review.txt" || true
test ! -L "$STORE/.prototools" || { echo "FAIL: the review pass changed something"; exit 1; }

d=$(sed -n 's/.*digest proto=\([0-9a-f]\{12\}\).*/\1/p' "$SP/review.txt" | head -1)
test -n "$d" || { echo "FAIL: no proto diff printed"; exit 1; }

# Assert the SHAPE of the diff, not just that one was printed. The record was
# written from a literal in Task 3, so the only differences from the machine's
# own file should be the two dropped pins, the dropped plugin block and the
# lockfile rename. A line mentioning anything else means the machine's pins
# moved since Task 3 — a `proto pin` from any project, or the pin-latest path —
# and overwriting would silently discard them.
grep -E '^[-+]' "$SP/review.txt" | grep -vE 'openjdk|zig|plugins|lockfile|^[-+]{3}|^[-+][[:space:]]*$' \
	> "$SP/unexpected.txt" || true
test ! -s "$SP/unexpected.txt" || {
	echo "FAIL: the diff carries changes this plan did not write:"; cat "$SP/unexpected.txt"; exit 1; }

echo "PROTO_REVIEW_DIGEST=$d" >> ~/Backups/proto-consus.env
```

- [ ] **Step 2: Apply, refusing if anything moved since the review**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${BK:?}" "${CLONE:?}" "${PROTO_REVIEW_DIGEST:?}"
cd "$CLONE"

# Re-print the diff and require the same digest. Between the review and the
# apply the machine can drift — any shell running `proto pin`, or an auto-install
# resolving a version with pin-latest set. A stale digest refuses, which is the
# same contract --expect-diff enforces for a declared merge.
./bin/install --non-interactive --backup-dir "$BK" 2>&1 | tee "$SP/review2.txt" || true
grep -q "digest proto=$PROTO_REVIEW_DIGEST" "$SP/review2.txt" ||
	{ echo "FAIL: the machine drifted between the review and the apply"; exit 1; }

./bin/install --non-interactive --backup-dir "$BK" --resolve proto=overwrite
```

- [ ] **Step 3: Assert the link, the backup, and that nothing else moved**

```sh
. ~/Backups/proto-consus.env
test -L "$STORE/.prototools"
test "$(readlink "$STORE/.prototools")" = "$CLONE/configs/proto/.prototools"
test -f "$BK/proto/.prototools"
grep -q openjdk "$BK/proto/.prototools" || { echo "FAIL: the backup is not the old record"; exit 1; }

# The other two links are untouched by this plan; assert they still are. Resolve
# the config home the way everything else does rather than hardcoding ~/.config.
ch="${XDG_CONFIG_HOME:-$HOME/.config}"
test -L "$ch/git" || { echo "FAIL: $ch/git is no longer a link"; exit 1; }
test -L "$ch/fish" || { echo "FAIL: $ch/fish is no longer a link"; exit 1; }
```

- [ ] **Step 4: Assert proto reads the repo's record, in a fresh shell**

```sh
. ~/Backups/proto-consus.env
cd "$HOME"
/opt/homebrew/bin/proto debug config --json 2>/dev/null > "$SP/live.json"

# These are the assertions that distinguish "reading our record" from "reading
# nothing". Do NOT assert against .files: measured, it is an array of CANDIDATE
# paths that proto lists whether or not they exist — every ancestor directory
# appears in it — so grepping it for the store path matches unconditionally and
# proves nothing.
jq -e '.config.settings.telemetry == false' "$SP/live.json" >/dev/null ||
	{ echo "FAIL: telemetry is not false — the record is not being read"; exit 1; }
jq -e '.config.settings.lockfile == true' "$SP/live.json" >/dev/null ||
	{ echo "FAIL: lockfile is not true — the record is not being read"; exit 1; }
n=$(jq -r '[.config | keys[]] - ["plugins", "settings", "shell"] | length' "$SP/live.json")
test "$n" -eq 9 || { echo "FAIL: proto sees $n pins, expected 9"; exit 1; }
jq -e '.config | has("openjdk") or has("zig") | not' "$SP/live.json" >/dev/null ||
	{ echo "FAIL: proto still sees a dropped pin — the old record is being read"; exit 1; }
```

The telemetry assertion is the sharp one. A severed link is silent on read and
reverts proto to built-in defaults, in which telemetry is **true** — so it alone
distinguishes "reading our record" from "reading nothing". The `openjdk`/`zig`
assertion is its complement: it distinguishes "reading our record" from "reading
the *old* record", which the telemetry check alone would pass, since the old one
disabled telemetry too.

Run from `$HOME` rather than `$CLONE`, and without `--config-mode`: the global
record loads from any directory, and this asserts the everyday path rather than
a special one. The shape addressed here was measured — the top-level keys are
`config`, `files` and `locks`, and the pins are direct keys of `.config`.

- [ ] **Step 5: `bin/doctor` exits 0**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
./bin/doctor
```

Expected: a `✓ link` line for `$STORE/.prototools`, and
`✓ proto      all 8 pinned versions are installed`. Eight, not nine — the
record carries nine pins and `npm = "bundled"` is not a concrete version, so it
is skipped rather than looked up.

- [ ] **Step 6: Assert a `proto pin` lands in the repo**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${CLONE:?}"
cd "$CLONE"
head_before=$(git rev-parse HEAD)
inode_before=$(stat -f %i configs/proto/.prototools)
hash_before=$(shasum -a 256 < configs/proto/.prototools)

# Pin a DIFFERENT version on purpose. Re-pinning the version already pinned
# would leave the content identical, so the assertion could not tell "the link
# survived a write" from "proto short-circuited and wrote nothing" — and the
# whole mechanism rests on the former.
/opt/homebrew/bin/proto pin go 1.26.4 --to global

hash_after=$(shasum -a 256 < configs/proto/.prototools)
test "$hash_before" != "$hash_after" ||
	{ echo "FAIL: no write reached the repo — this proves nothing"; exit 1; }
test -L "$STORE/.prototools" ||
	{ echo "FAIL: the write replaced the link with a regular file"; exit 1; }
test "$(readlink "$STORE/.prototools")" = "$CLONE/configs/proto/.prototools"
test "$(stat -f %i configs/proto/.prototools)" = "$inode_before" ||
	{ echo "FAIL: the write replaced the file rather than editing it in place"; exit 1; }
grep -q '1\.26\.4' configs/proto/.prototools ||
	{ echo "FAIL: the new pin is not in the repo's file"; exit 1; }

# Put the record back.
git restore configs/proto/.prototools
test "$(shasum -a 256 < configs/proto/.prototools)" = "$hash_before"
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$head_before"
```

This is the design's load-bearing claim, asserted end to end on the real
machine: a proto write lands **in the repo**, **through the link**, **in place**
— same inode — and leaves the link intact. The inode check is what distinguishes
an in-place rewrite from a temp-file-plus-rename, which would have replaced the
symlink with a regular file and quietly forked the record.

`proto pin` reaches the network for plugin metadata, so this step needs
connectivity. It pins a version it does not install; `git restore` undoes it.

---

### Task 9: Phase 5 — the README and the 2026-08-21 design

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-21-consus-migration-design.md`

**Interfaces:**

- Consumes: a working installation.
- Produces: documentation that matches the machine.

- [ ] **Step 1: `README.md` — four of the six contract items**

Make these edits:

1. The opening path table gains a third line:

   ```text
   ~/.proto/.prototools  →  <this clone>/configs/proto/.prototools
   ```

   with a sentence saying proto is the one tool whose path is not under
   `~/.config`, because proto never reads `XDG_CONFIG_HOME`, and the one whose
   link is on a file rather than a directory, because the 2.3 GB store is
   the directory.

2. "What is here" gains a **configs/proto** bullet: the global record, nine
   pins, and that the store stays outside the repo.

3. "A fresh machine" gains `proto` to the `brew install` line, and after
   `./bin/install`, the restore step:

   ```sh
   proto install --config-mode global
   ```

   with a note that the mode is not optional.

4. "Per-machine settings" gains a **proto** bullet: per-project pins go in that
   project's own `./.prototools`; the record here is the global fallback.

5. "The hazard of a linked directory" gains a paragraph: proto's link is on a
   file, so no `rm -rf` can empty a directory through it — but a *severed* link
   is silent, and proto falls back to built-in defaults with telemetry back on.
   That is what `bin/doctor` catches.

6. The `--resolve <fish|git>` literal becomes `--resolve <fish|git|proto>`.

7. The path-naming paragraph — "Each path is named by the tool that owns it —
   `fish`, `git` — on the command line, under `~/.config` and in the backup
   directory alike" — becomes false for proto and must say so: `proto` names the
   path on the command line and in the backup directory, but the path it stands
   for is `$PROTO_HOME/.prototools`, not something under `~/.config`.

- [ ] **Step 2: Assert the README no longer contradicts the scripts**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
grep -q 'fish|git|proto' README.md || { echo "FAIL: README still says <fish|git>"; exit 1; }
grep -q 'configs/proto' README.md
grep -q 'config-mode global' README.md
markdownlint-cli2 README.md
```

- [ ] **Step 3: The five edits to the 2026-08-21 design**

1. **"Deliberately out of scope"** — the bullet reading "`~/.claude` and
   `~/.proto` keep their own repos at their real paths" becomes "`~/.claude`
   keeps its own repo at its real path", with a following sentence naming the
   2026-09-21 spec as where proto went and why.
2. **"Per-tool activation"** — add the proto row:

   ```text
   | `proto` | `$PROTO_HOME/.prototools`, default `~/.proto` | file link | `bin/doctor` `readlink` only |
   ```

   and extend the preamble's measured-against list with proto 0.62.2.
3. **"Destruction accounting"** — one line: a severed proto link is silent and
   reverts proto to built-in defaults; the store is not under the repo, so no
   recursive removal inside it can reach the toolchains.
4. **"Dropped: opencode, gh and micro"** — one sentence in the **gh** paragraph
   noting the file link it measured viable is the mechanism proto now uses, so
   gh's disqualification rests on payload size alone.
5. **The `Status` line** stays `executed 2026-08-23`; add an
   **Amended-by** line naming the 2026-09-21 spec.

- [ ] **Step 4: Assert the reversal is recorded, not just contradicted**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
D=docs/superpowers/specs/2026-08-21-consus-migration-design.md
grep -q '`~/.claude` and `~/.proto` keep their own repos' "$D" &&
	{ echo "FAIL: the out-of-scope bullet still excludes ~/.proto"; exit 1; }
grep -q '2026-09-21-proto-into-consus-design' "$D" ||
	{ echo "FAIL: the design does not name its amendment"; exit 1; }
grep -q '| `proto` |' "$D" || { echo "FAIL: no proto row in the activation table"; exit 1; }
markdownlint-cli2 "$D"
```

- [ ] **Step 5: Commit both**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
git add README.md docs/superpowers/specs/2026-08-21-consus-migration-design.md
git commit -m "Record proto in the README and the 2026-08-21 design"
test -z "$(git status --porcelain)"
```

- [ ] **Step 6: Push, and wait for CI**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
git push origin main
sha=$(git rev-parse HEAD)
for _ in $(seq 1 40); do
	c=$(gh run list --repo LRNZ09/consus --commit "$sha" \
		--json conclusion --jq '.[0].conclusion' 2>/dev/null || echo '')
	case "$c" in
	success) echo "CI green"; break ;;
	failure | cancelled | timed_out) echo "FAIL: CI $c"; exit 1 ;;
	*) sleep 15 ;;
	esac
done
test "$c" = success
```

The full 40-character SHA is required: `--commit` with a short SHA silently
returns an empty list.

---

### Task 10: Phase 6 — deprecate dotproto

**Files:**

- Modify: `LRNZ09/dotproto` `README.md` (via a temporary clone under `$SP`)

**Interfaces:**

- Consumes: `DOTPROTO_HEAD` from Task 2.
- Produces: an archived repository whose landing page points at consus.

- [ ] **Step 1: Clone it somewhere harmless**

```sh
set -eu
. ~/Backups/proto-consus.env
: "${SP:?}" "${DOTPROTO_HEAD:?}"
rm -rf "$SP/dotproto"
git clone https://github.com/LRNZ09/dotproto.git "$SP/dotproto"
cd "$SP/dotproto"
test "$(git rev-parse HEAD)" = "$DOTPROTO_HEAD" ||
	{ echo "FAIL: remote moved since Task 2"; exit 1; }
```

Not into `~/.proto`: that is the instruction this task exists to retire.

- [ ] **Step 2: Replace the README with a pointer**

```sh
. ~/Backups/proto-consus.env
cd "$SP/dotproto"
# Derive the snapshot date from the commit rather than hardcoding it, so the
# notice cannot drift from what is actually in the repo.
snap=$(git log -1 --format=%cs "$DOTPROTO_HEAD")
test -n "$snap" || { echo "FAIL: could not date $DOTPROTO_HEAD"; exit 1; }
cat > README.md <<'EOF'
# dotproto — deprecated

proto's configuration now lives in **[LRNZ09/consus](https://github.com/LRNZ09/consus)**,
at `configs/proto/.prototools`, reached through a symlink at
`$PROTO_HOME/.prototools` placed by that repo's `bin/install`.

This repository is archived and read-only. Nothing here should be cloned: the
bootstrap it used to document — `git clone … ~/.proto` — no longer has a correct
target, because the proto store and the record it holds are now owned by
different things. The store stays wherever proto puts it, and only the record is
versioned.

`.prototools` and `.protolock` are kept below as a dated snapshot of this
machine's toolchain on @SNAPSHOT_DATE@. The lockfile in particular is not
carried into consus: it is inert at global scope, is written only when the
current directory is inside the store, and has no entry for ruby or rust.

The 15 commits here are the reason anything is worth keeping — they record why
each version is pinned to what it is, including that the July sweep was fallout
from `proto uninstall` stripping pins rather than a deliberate upgrade.
EOF
sed -i '' "s/@SNAPSHOT_DATE@/$snap/" README.md
grep -q '@SNAPSHOT_DATE@' README.md &&
	{ echo "FAIL: the placeholder survived"; exit 1; }
grep -q "$snap" README.md || { echo "FAIL: the date was not substituted"; exit 1; }
git add README.md
git commit -m "Point this repo at consus and deprecate it"
git push origin main
```

- [ ] **Step 3: Archive it**

```sh
. ~/Backups/proto-consus.env
gh repo archive LRNZ09/dotproto --yes
gh repo view LRNZ09/dotproto --json isArchived --jq '.isArchived' | grep -qx true
```

Archiving is reversible and keeps both the URL and the history. Deletion is
neither, and this plan never deletes a repository.

- [ ] **Step 4: Final state assertions**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
./bin/doctor
test -z "$(git status --porcelain)"
test "$(git rev-list --count HEAD)" -gt "$BASELINE_COMMITS"
test -L "$STORE/.prototools"
test ! -e "$STORE/.git"
test ! -e "$STORE/bin/proto"
/opt/homebrew/bin/fish -c 'true' 2>"$SP/final.err"
test ! -s "$SP/final.err"
echo "proto-into-consus complete"
```

- [ ] **Step 5: Confirm the sancus follow-up is recorded where it survives**

```sh
. ~/Backups/proto-consus.env
cd "$CLONE"
S=docs/superpowers/specs/2026-09-21-proto-into-consus-design.md
grep -q '^## What breaks in sancus' "$S" ||
	{ echo "FAIL: the sancus follow-up is not in the committed spec"; exit 1; }
sed -n '/^## What breaks in sancus/,/^## /p' "$S" | sed '$d'
```

The follow-up belongs in the **committed spec**, not in the state file. The
state file is machine-local, uncommitted, described by this plan as "never
committed", and sits beside timestamped backup directories a reader is likely to
delete — so a note written only there is a note that disappears. This step's job
is to prove the durable record still carries it and to put it in front of
whoever ran the migration.

---

## If it goes wrong: rollback

Every step is reversible by moving something back. Each block below guards its
own variables: an empty `$BK` or `$STORE` would turn these into commands aimed
at `/`.

```sh
set -eu
. ~/Backups/proto-consus.env
: "${STORE:?}" "${BK:?}"

# The record: drop the link, restore the machine's own file. Assert the backup
# is there FIRST — removing the link before knowing there is something to put
# back would leave proto with no record at all.
test -f "$BK/proto/.prototools" || { echo "no backup to restore"; exit 1; }
test -L "$STORE/.prototools" || { echo "$STORE/.prototools is not a link — stop and look"; exit 1; }
rm -f "$STORE/.prototools"
mv "$BK/proto/.prototools" "$STORE/.prototools"

# The dotproto checkout.
test -d "$BK/dotproto/.git" && mv "$BK/dotproto/.git" "$STORE/.git"
test -f "$BK/dotproto/.gitignore" && mv "$BK/dotproto/.gitignore" "$STORE/.gitignore"

# The self-installed proto.
test -f "$BK/proto-self-install/proto" && mv "$BK/proto-self-install/proto" "$STORE/bin/proto"
test -d "$BK/proto-self-install/tools-proto" && mv "$BK/proto-self-install/tools-proto" "$STORE/tools/proto"
```

proto reads a regular file exactly as it reads the link, so the machine is whole
the moment the file is back. The `rm -f` is on a symlink this plan created, and
is guarded by the `-L` test above; removing a link never touches its target.

`gh repo unarchive LRNZ09/dotproto` restores the repository to writable. The
pointer commit stays in history and can be reverted.

The consus commits are ordinary commits on `main`, so `git revert` each.

**Do not `git reset --hard` after Task 8.** Once the link is live,
`configs/proto/.prototools` is not merely a repo file — it is the file proto
writes through, so a hard reset silently discards every pin recorded since the
last commit, on the machine as well as in the tree. If a reset is unavoidable,
copy the file out first. And never run it with an unset variable:
`git reset --hard $BASELINE_HEAD` with `BASELINE_HEAD` empty resets to `HEAD`
and throws away the working tree and index instead of doing nothing.

## What this plan does not do

- **It does not move the store.** No task runs `mv` on `~/.proto`.
- **It does not clean the store.** Roughly 400 MB of `tools/` is versions
  nothing pins. `proto clean` is a separate decision.
- **It does not touch sancus.** Eight prose lines there go stale; Task 10 Step 5
  records them.
- **It does not track `.protolock`.**
- **It does not resolve whether proto should own `rust`** while `rustup` is also
  installed and `conf.d/rustup.fish` sources its environment.
