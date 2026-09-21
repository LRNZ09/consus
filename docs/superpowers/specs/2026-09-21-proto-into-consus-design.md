# proto — bringing the toolchain record into consus

**Date:** 2026-09-21
**Status:** designed
**Amends:** `docs/superpowers/specs/2026-08-21-consus-migration-design.md`,
whose "Deliberately out of scope" excludes `~/.proto` on the grounds that it
"keeps its own repo at its real path". That premise is what this change ends,
so the line is edited rather than supplemented.
**Retires:** `LRNZ09/dotproto`, whose clone is the directory `~/.proto` itself.

## What this does

consus takes over proto's global configuration — the `.prototools` that pins
every toolchain on this machine — and `LRNZ09/dotproto` is archived.
The proto *store* does not move. `PROTO_HOME` is never set. `~/.proto` stays
exactly where proto puts it, and `bin/install` places a single file symlink
inside it:

```text
~/.proto/.prototools  →  <repo>/configs/proto/.prototools
```

That is the whole mechanism. The repo's principle is unchanged — each tool
finds its configuration at its own default path, and that path is a symlink
into this clone — but proto is the first tool where the default path is not
under `$XDG_CONFIG_HOME` and the link is to a file rather than a directory.
Both departures are forced, and both are measured rather than assumed.

## Why the store never enters the repo

`PROTO_HOME` is not a config-directory setting. It relocates the entire store:
measured, every directory in `proto debug env --json` is a child of it —
`bin`, `shims`, `tools`, `plugins`, `cache`, `builders`, `temp`, `backends` —
with nothing left behind at `$HOME/.proto`. There is no way to keep the record
in one place and the payload in another through `PROTO_HOME` alone, and no
per-directory override exists for the large ones: `PROTO_TEMP_DIR` moves 4 KB
of `temp/`, and `tools/` (1.2 GB), `cache/` (953 MB), `bin/` and `shims/` are
not env-overridable at all.

So `PROTO_HOME=$XDG_CONFIG_HOME/proto`, with `~/.config/proto` linked into this
repo the way `~/.config/git` and `~/.config/fish` are, would put 2.3 GB and
64,660 entries into the working tree. It was priced properly rather than
dismissed, and it fails on four counts:

- **proto does not read `$XDG_CONFIG_HOME`.** Measured on both installed
  binaries: with only `XDG_CONFIG_HOME` set, the store resolves to
  `$HOME/.proto`. The precedence is `PROTO_HOME` > `$XDG_DATA_HOME/proto` >
  `$HOME/.proto`. Upstream added `$XDG_DATA_HOME` support in v0.46.0 and has
  never added the config equivalent, which is upstream classifying the store as
  **data**. `~/.config/proto` is not a path proto would ever choose; it is one
  it would have to be forced to, so there is no default path for a link to
  occupy and the mechanism has nothing to bind to.
- **It is env-var activation, which this repo retired by name.** The
  2026-08-21 revision lists "env-var activation is dead for any GUI-launched
  program" among the five silent failure modes that killed the include design.
  `PROTO_HOME` would be set in `configs/fish/conf.d/proto.fish` and therefore
  exist only inside fish. Measured: a clean login zsh, a clean login bash and
  launchd all see it unset. Every one of those contexts would fall back to
  `$HOME/.proto` — and proto *creates* a missing store rather than failing, so
  the result is a second, empty, unconfigured store appearing in silence, with
  `auto-install = true` then downloading toolchains into it.
- **It revives three of the four objections to a repo at `~/.config`.** Under
  a 2.3 GB linked store, `git clean -fdx` and `git stash --all` delete a store
  no backup covers; one corrupted character in the allow-list stages gigabytes
  into a public repo; and ripgrep and every gitignore-respecting tool go blind
  inside it. The design's own central guarantee — that a gitignore mistake can
  only ever cause a *missing* file, never a leak — inverts.
- **The credential invariant stops being structural.** No credential is in the
  store today, but `cache/` is a 953 MB HTTP response cache. The record
  declares `github://` plugin locators, and the moment a token is in the
  environment for a private plugin, an authenticated response body lands in a
  cache inside the working tree of a public repo. Keeping the store out
  preserves "no credential store is under any path this repo contains" as a
  property of the layout rather than of the allow-list.

Speed is **not** among the objections, and the design should not pretend it is:
measured, `git status` over a 55,186-file ignored store costs 8.95 ms against
an 8.75 ms baseline. The shape of the ignore rule matters far more than its
size — a `**`-style negation that re-includes every directory costs 333 ms,
38× slower — but that is a fact about writing allow-lists, not an argument
against this one.

## Options considered

| Option | Verdict |
| --- | --- |
| **File link at `$PROTO_HOME/.prototools`** | **Chosen.** Zero configuration in proto's language, store untouched, correct in every shell. |
| `PROTO_HOME=$XDG_CONFIG_HOME/proto`, directory link | Rejected — the four counts above. |
| `PROTO_HOME=$XDG_CONFIG_HOME/proto` as a real directory, file links inside | Dominated: buys nothing the file link does not, keeps the env-var dependency, and adds a 2.3 GB move. |
| `XDG_DATA_HOME` so the store lands at `~/.local/share/proto` | Upstream-idiomatic and the runner-up, but still env-var-dependent in exactly the same way, and setting `XDG_DATA_HOME` globally also moves where fisher — part of the tracked record — keeps its data. |
| Track `~/.prototools` (the `user` scope) instead | Rejected: measured, it is not a separate lookup at all but the upwards walk happening to reach `$HOME`, so it is inert outside `$HOME` and is shadowed by any intermediate `.prototools`. It violates "the record must not be shadowable" twice. |
| Copy, with `bin/doctor` asserting the copies match | Rejected on the same ground as chezmoi, and harder: with `pin-latest = "global"` and `auto-install = true`, an ordinary shim invocation can rewrite the record, so the copy would go stale on the most common proto action. |
| Tool-native include | Does not exist — see below. |

The ghostty pattern has no analogue here. Measured four ways: `proto --help`
and `proto pin --help` expose only `--config-mode`; a top-level `extends` key
is parsed as a *tool* named `extends` and fails version validation; a
`[settings] extends` key returns `unknown field`, and that error enumerates the
complete settings surface, which contains no path key at all. proto is
link-or-copy only, which is why the table above has no include row.

## The mechanism

proto rewrites `.prototools` **in place**, so a file symlink survives its
writes. This is the load-bearing fact of the whole design and was measured with
a hardlink witness rather than inferred from behaviour:

```text
store/.prototools -> repo/prototools.toml      (inode 72880608)
ln repo/prototools.toml repo/witness.hardlink  (links = 2)

proto pin node 20.11.0 --to global
proto pin deno 2.1.0   --to global

store/.prototools   still "Symbolic Link"
repo/prototools.toml inode 72880608, unchanged
repo/witness.hardlink shows BOTH new pins
```

A temp-file-plus-rename would have replaced the symlink or broken the hardlink.
Neither happened. Comments, key order and the `[settings]` table all survive, so
the record stays a hand-written, commented file after proto edits it — the same
property that makes `configs/git/config` work through a link. A `proto pin`
becomes an ordinary unstaged modification, which is the review queue the
2026-08-21 design asks for. Verified on both installed binaries, 0.58.2 and
0.62.2, and for the `user` scope as well as `global`.

The failure modes are asymmetric, and only one of them needs `bin/doctor`:

- **A severed link is silent on read.** proto reports zero config files and
  reverts to built-in defaults — including `telemetry = true`, which the record
  deliberately disables. Nothing warns. This is the direct analogue of "for git
  and fish a severed link is completely silent", and it is why `bin/doctor` is
  load-bearing here too.
- **A write through a dangling link fails loudly** and never replaces the link
  with a regular file. So the record cannot silently fork into a machine-local
  copy that drifts forever; only the read side needs a probe.

## Per-tool activation — the new row

| Tool | Default path | Mechanism | Liveness signal |
| --- | --- | --- | --- |
| `proto` | `$PROTO_HOME/.prototools`, default `~/.proto` | file link | `bin/doctor` `readlink` only |

The `Default path` cell names `$PROTO_HOME` rather than a literal, because
`--to global` follows the variable. proto's own `pin --help` hardcodes
"~/.proto/.prototools" and is wrong whenever the variable is set; the record
should not repeat that mistake.

The `Liveness signal` cell reads the same as git's and fish's, and for a
stronger reason than theirs. proto ships a health check and it is useless here:
measured, `proto diagnose` exits 0 against a completely absent store, and
`proto status` exits 0 while emitting an error and listing nothing. Neither can
be used as a gate.

## What the record contains

`configs/proto/.prototools`, which is the current file minus two pins and the
plugin block:

```toml
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
```

Three deliberate changes from what `dotproto` tracked:

- **`openjdk` and `zig` are dropped**, with their `[plugins.tools]` locators.
  Both are pinned and lock-recorded but have `installed_versions: []` — they
  have not existed on this machine since some point after 2026-07-11, and
  nothing detected it, because `dotproto` has no doctor. `openjdk` is also a
  dormant hazard rather than merely dead weight:
  `configs/fish/conf.d/android.fish` sets `JAVA_HOME` to Android Studio's
  bundled JBR 21 *specifically because* the proto `java` shim would be OpenJDK
  26, and `~/.proto/shims` precedes `/usr/bin` on `PATH`. The conflict is latent
  only because the install failed. With `auto-install = true`, the first command
  that resolves openjdk would create a `java` shim ahead of `/usr/bin` and leave
  `java` and `JAVA_HOME` disagreeing — worse than either alone. Dropping both
  pins also removes both third-party plugin dependencies; zig went natively
  supported in proto 0.62.0 in any case.
- **`unstable-lockfile` becomes `lockfile`.** They are the same field under two
  names — a config carrying both fails with `duplicate field`. The rename is
  only safe once 0.58.2 is gone, which this change also does.
- **`.protolock` is not tracked.** See below.

### Why the lockfile is not in the record

Tracking it would record a guarantee it does not give. Three measurements, any
one of which would be enough:

- **It is inert at global scope.** On 0.62.2 a global `$PROTO_HOME/.prototools`
  with the lockfile setting registers no lockfile at all, while an identical
  *local* one does.
- **It would stop being written.** The store-level `.protolock` is only written
  when the current directory is inside the store. The file exists today only
  because `~/.proto` is a git checkout that gets `cd`'d into. Once that stops,
  the record freezes and nothing says so.
- **It is already incomplete.** No entry for `ruby` or `rust`, and every entry
  it does have records `spec = "latest"` rather than the version `.prototools`
  pins. A machine restoring from it would not get a checksummed ruby.

On 0.58.2 it is worse still — a lockfile record applies only on the os/arch
that created it, so a shared `.protolock` silently verifies nothing on a second
machine. The file survives as a dated snapshot in dotproto's final commit,
which is the right home for a frozen artifact.

`configs/proto/README.md` carries the per-tool knowledge, the way
`configs/git/README.md` does. Only what exists nowhere else goes in it — the
upstream docs are better at everything else — which is essentially three
things: the uninstall gotcha below, a compressed form of the plugin-locator
warning, and the `$PROTO_HOME`-not-a-literal note.

The uninstall gotcha is the single most valuable line dotproto ever recorded,
and it should be stated harder than dotproto stated it. `proto uninstall`
strips the tool's pin from **every** `.prototools` on the resolution chain —
local, every ancestor, `user` and `global` — not just the global one. With no
version argument the removal is unconditional. Identical code at 0.58.2 and
0.62.2. So an uninstall run inside a project can silently edit an unrelated
project's `.prototools` two directories up. With `pin-latest = "global"` set,
the follow-up `proto install` then resolves *latest* and writes that back as
the new pin, which is how the July version sweep happened.

## bin/install

`KNOWN_PATHS='fish git proto'`, and the four literal `<fish|git>` spellings in
`usage()` and the resolution errors move with it, along with the one in
`README.md`. If they do not move in the same commit, `--resolve`'s own error
text lies about what it accepts.

The plan/validate/apply plumbing is per-path scalars rather than a loop, so
proto adds `plan_proto`/`slot_proto`, one classify call, one `check_slot`, one
term in the slot sum, and one apply. Ordering is free except that git stays
last, as now; proto goes after the ghostty stub.

The one genuinely new piece is `classify_file()`. The existing `classify()`
refuses any record that is not a directory and its diff machinery is
directory-shaped, so proto needs a sibling that takes an explicit machine path,
compares two files, and digests the listing exactly as `show_diff` does — so
the `--expect-diff` contract carries over unchanged, with the digest still
committing to content rather than only to names.

proto takes **overwrite or refuse**, never merge. The reason the design gives
for restricting merge to fish applies here verbatim and more strongly: merge
copies the machine tree over the repo's, and `~/.proto` is itself a git
checkout. For a single TOML file the two honest actions are "the repo wins, the
machine's file goes to backups" and "change nothing". The interactive prompt
already keys on `[ "$c_rel" = fish ]`, so proto falls into the two-option branch
with no edit — but the guard below it must be re-read as an allow-list of one
rather than a deny-list of git.

`~/.proto` always exists in practice, because any proto invocation creates it.
`classify_file` still does `mkdir -p` on the parent before linking, so a machine
where it does not exist yet is handled rather than assumed.

## bin/doctor

Two checks. The first is the link assertion, which is `check_link` generalised
to take a base directory so it can name `$HOME/.proto/.prototools` instead of a
path under `$XDG_CONFIG_HOME`.

The second is the one that earns its place: **declared but not installed**,
comparing each pin in the record against `tools/<tool>/<version>/` on disk. It
is the exact analogue of the existing `fish_plugins` check — `.prototools` is to
`tools/` what `fish_plugins` is to the 82 fisher files — and it is the check
that would have caught openjdk and zig drifting to uninstalled. It compares
directories rather than shelling out to proto, which keeps doctor read-only and
network-free and avoids depending on `proto status`, which exits 0 while
failing.

A third check is advisory: report when `~/.proto/bin/proto` exists, because that
copy shadows Homebrew's on `PATH` and its reappearance is drift the record does
not describe.

There is deliberately **no unclassified-entries report** for proto. The fish
report's arithmetic closes only because fisher keeps a file-level manifest;
proto keeps none, so the same mechanism applied to the store would print one
advisory line per entry — over 55,000 of them, measured at 3.85 MB per run —
hiding the two lines that matter. The exemption is recorded here so a later
reader does not "fix" the omission.

Doctor runs `fish -c`, fish sources `conf.d/proto.fish`, and that runs `proto
activate` — so doctor materialises the store. That is harmless under this
design, because the store is at proto's own default and already exists. It would
not have been harmless under any design that needs a store path to
not-yet-exist, and that is worth stating, because it is the hazard `sancus`
already documents from the other direction.

## The .gitignore

One line, not a block:

```gitignore
# proto writes .protolock next to any .prototools it treats as local, so a
# stray proto run inside this directory drops one here. The record is the
# pins; the lockfile is inert at global scope and is not tracked.
/configs/proto/.protolock
```

Because the store stays outside the repo, `configs/proto/` has no generated
siblings, which puts proto on the ghostty side of the line the design draws
rather than the fish side: a tool needs an allow-list block only when tools
write into its directory. The single rule above is defensive, not structural.

The annotation sits on its own lines, as every annotation in that file must —
gitignore honours `#` only at the start of a line, so a trailing comment becomes
part of the pattern and silently matches nothing.

## configs/fish/conf.d/proto.fish

The file is tracked already and two of its claims are wrong. Both are fixed
here rather than carried forward.

**The NDJSON wart is fixable.** The comment states that proto's agent-mode
NDJSON "cannot be fixed from here — `proto activate` rejects `--format`, and
neither `env -u AI_AGENT` nor `PROTO_JSON=false` suppresses it". The working
spelling is `--reporter` / `PROTO_REPORTER`, which the earlier investigation did
not try. Measured: `fish -c 'proto activate fish | source'` emits the NDJSON
parse errors; the same command under `PROTO_REPORTER=text` emits nothing at all
and exits 0.

It must be `set -gx` and not a one-shot prefix. Activation re-runs on every `cd`
through a fish hook, and the hook's body shells out to
`proto activate fish --export | source`; only an exported variable reaches that
inner call. Measured: `proto activate fish -r text | source` does not work,
because the flag never propagates.

**"brew is the install source" is misleading.** It is true of the bootstrap and
false of everything after it: `proto activate` prepends `~/.proto/bin`, so the
self-installed copy shadows Homebrew's for every subsequent invocation. Removing
that copy makes the sentence unambiguously true, which is the better fix.

## The double install

`/opt/homebrew/bin/proto` is a symlink to a 124-byte bash wrapper that execs the
real 33.7 MB binary in the Cellar — currently 0.62.2. `~/.proto/bin/proto` is a
31,933,936-byte Mach-O executable, byte-identical to
`~/.proto/tools/proto/0.58.2/proto`: proto manages itself as one of its own
tools. Two independent update channels for the same program, neither aware of
the other.

The store copy wins. `~/.proto/shims` and `~/.proto/bin` sit at `PATH` positions
3 and 4 against Homebrew's 18, so every `proto` typed on this machine is 0.58.2,
and `brew upgrade proto` changes nothing about it. Three live consequences:

- `proto status` is **broken today** — the two plugins the old record pins
  require proto ≥ 0.60.0 — and it exits 0 while saying so.
- 0.58.2 emits a malformed `_PROTO_ACTIVATED_PATH` containing a stray single
  quote, which 0.62.2 does not.
- 0.58.2 applies lockfile records only on the os/arch that wrote them.

Homebrew becomes the only source, which is what `sancus`'s `Brewfile` already
declares and what `conf.d/proto.fish` already claims. Removing the
self-installed copy also removes `tools/proto/`, whose manifest lists nine
installed versions of which one exists on disk.

`proto upgrade` self-replaces the running executable, so it must not be run once
Homebrew owns the binary: the Cellar is user-writable, so it would mutate the
Cellar behind Homebrew's back and leave `brew` reporting a version it no longer
ships. `brew upgrade proto` is the only upgrade path afterwards. This belongs in
`configs/proto/README.md`.

## Destruction accounting

**This migration deletes nothing.** The displaced `.prototools` is moved into
the timestamped backup directory like every other displaced path, and reverses
by moving back. `~/.proto/.git` is moved, not removed. Removing the
self-installed proto is the one deletion, and it is a reinstall away from being
undone.

The store is not under the repo, so the linked-directory hazard class does not
extend to proto: no `rm -rf` inside this repo and no `git clean -fdx` can reach
2.3 GB of toolchains. That is the main thing the file link buys, and the
accounting section in the 2026-08-21 design needs only one new line rather than
a rewrite.

What a mistake *can* still do is sever the link, and the cost of that is the
silent revert described above — defaults restored, telemetry back on, pins gone
— which `bin/doctor` exists to catch.

Unrecoverable by any git operation, and named here because dotproto's README got
its own inventory wrong: `~/.proto/id`, a 36-byte stable install identifier, and
`~/.proto/.remember/`, a 76 KB journal tree that has nothing to do with proto.
The README claimed everything but three files regenerates. Neither of these
does, and `.remember/` in particular must not be swept up by anything that
treats `~/.proto` as disposable. `id` is a stable per-machine identifier and
must never be committed to a public repo; nothing in this design puts it near
one.

## Verified facts

### Measured 2026-09-21

Against proto 0.58.2 (`~/.proto/bin/proto`) and 0.62.2 (Homebrew), fish 4.8.0,
on macOS arm64. Experiments ran against scratch stores under a redirected
`PROTO_HOME`; no real path was modified.

- `PROTO_HOME` relocates every store directory, with nothing left at
  `$HOME/.proto`. `proto debug env --json` returns `store.dir`, `bin_dir`,
  `shims_dir`, `inventory_dir`, `plugins_dir`, `cache_dir`, `builders_dir`,
  `temp_dir` and `backends_dir` all as children of it.
- Store resolution is `PROTO_HOME` > `$XDG_DATA_HOME/proto` > `$HOME/.proto`,
  identical on both binaries. `XDG_CONFIG_HOME` is ignored entirely. A
  nonexistent `XDG_DATA_HOME` is still honoured and created.
- `.prototools` is rewritten in place through a symlink: inode preserved across
  two `--to global` pins, symlink intact, hardlink witness showing both writes.
  Holds on both binaries and for the `user` scope.
- `.protolock` is written in place through a symlink too, but the store-level
  one is written **only** when the cwd is inside the store. Four negative runs
  across both binaries with `--config-mode global` and `upwards-global` left it
  at 0 bytes; one positive run from inside the store wrote it.
- On 0.62.2, a global `.prototools` with the lockfile setting registers no
  lockfile; an identical local one does.
- A severed `.prototools` link is silent on read — zero config files reported,
  built-in defaults restored including `telemetry = true`. A write through a
  dangling link fails loudly and leaves the link in place.
- No relocation or include mechanism exists for `.prototools`. Top-level
  `extends` parses as a tool and fails version validation; `[settings] extends`
  returns `unknown field`, and that error lists the complete settings surface,
  which contains no path key.
- `proto activate fish` hard-codes nothing — it emits a function that shells out
  to `proto activate fish --export | source`, and only that inner call resolves
  the store. So `conf.d/proto.fish` needs no change for any store location.
- `PROTO_REPORTER=text` silences the agent-mode NDJSON completely:
  `PROTO_REPORTER=text fish -c 'proto activate fish | source'` produces no
  output and exits 0, where the bare command emits parse errors. The `-r text`
  flag does not propagate to the inner call; only the environment variable does.
- Shims are byte-identical copies of `proto-shim` with no embedded store path,
  so `shims/` is relocatable. `bin/` is not: its ~40 entries are absolute
  symlinks, 26 of which have no shim to fall back on, so a moved store breaks
  `node-22` and its siblings while bare `node` keeps working. `proto regen
  --bin` is the repair.
- 24 text files under `tools/ruby/4.0.5/` hard-code the absolute store path in
  shebangs and `rbconfig.rb`, and `proto regen` does not rewrite them. Any plan
  that relocates the store must reinstall ruby rather than move it. The 72
  python hits are `__pycache__` `co_filename` entries, which degrade tracebacks
  only.
- A shim pointed at a missing store fails silently — no stderr, one
  uninformative stdout line — and then, with `auto-install = true`, begins
  re-downloading.
- `git status` over a 55,186-file ignored store costs 8.95 ms against an 8.75 ms
  baseline. The same tree with a `**` negation re-including every directory
  costs 333 ms.
- `~/.proto/bin/proto` is byte-identical to `~/.proto/tools/proto/0.58.2/proto`
  (sha256 `3e98c76c…`). `/opt/homebrew/bin/proto` is a 124-byte bash wrapper,
  not a binary, so any check comparing the two by hash compares a script to a
  Mach-O.
- `proto status` exits 0 while failing on 0.58.2, because the record's two
  plugins require ≥ 0.60.0. `proto diagnose` exits 0 against a completely absent
  store.
- `proto uninstall` strips the tool's pin from every `.prototools` on the
  resolution chain, unconditionally when no version is given. Identical at
  0.58.2 and 0.62.2.
- `proto install` with no `--config-mode` runs in `upwards` mode, not the
  documented `upwards-global`, and installs nothing from the global record. A
  bootstrap that restores toolchains must pass `--config-mode global` or run
  from inside the store.
- `proto pin` is not offline: it downloads the tool's plugin WASM before
  writing. `bin/doctor` must therefore never shell out to proto for anything
  that resolves a tool.
- The store is 2.3 GB and 64,660 entries excluding `.git` — 55,186 files and
  symlinks, 9,474 directories — of which `cache/` is 953 MB and disposable.
- `openjdk` and `zig` are pinned and lock-recorded with `installed_versions:
  []`. The old README's `java -version # Temurin via ~/.proto/shims/java` is
  already false and no `java` shim exists.
- `~/.config` is 1.1 GB across 1,635 entries today, of which raycast (892 MB)
  and gatsby (187 MB) are caches. A store under it would take it to ~3.4 GB and
  ~66,300 entries, making proto 97% of everything there.

## What this edits in the 2026-08-21 design

- **"Deliberately out of scope"** — the first bullet reads "`~/.claude` and
  `~/.proto` keep their own repos at their real paths" and becomes
  "`~/.claude` keeps its own repo at its real path". Leaving the line standing
  while doing the opposite is how a design document stops being trustworthy.
- **"Per-tool activation"** — gains the proto row above, and the preamble's
  measured-against list gains proto's two versions.
- **"Destruction accounting"** — one line for the severed-link revert. No
  rewrite, because the store stays outside the tree.
- **"Dropped: opencode, gh and micro"** — gains a sentence noting that the file
  link gh was measured viable for is the mechanism proto now uses, so gh's
  disqualification remains payload size alone.
- **`README.md`** — four of the six contract items: what is managed, the
  fresh-machine quickstart, per-machine settings, and the linked-path hazard;
  plus the `--resolve <fish|git>` literal.

## Deprecating dotproto

Archive, with a pointer commit first. The repo has no external surface at all —
0 stars, 0 forks, 0 issues, 0 PRs, 0 releases, no topics, and a GitHub-wide code
search for its name returns only its own README — so deprecation costs nothing
and has nobody to notify.

Archiving *alone* is not enough. The banner says only that the repository is
read-only; it never says where the content went, so `git clone … ~/.proto` would
stay the first thing a visitor reads, and that instruction has no correct target
once consus owns the record. Two README sections are outright migration
casualties and must be deleted rather than rewritten: the clone bootstrap, and
the entire "Already have proto installed?" adopt-in-place block, whose
`git switch -f main` is the exact command `sancus` warns clobbers the local
`.prototools`.

Deletion is rejected. The 15 commit messages carry the causal record the four
files do not — in particular that the July version sweep was fallout from the
uninstall pin-loss rather than deliberate curation, and why ruby and rust carry
no lock entries. That is the reasoning behind the pins consus is about to adopt.

So: one final commit reducing `README.md` to a deprecation notice pointing at
consus, keeping `.prototools` and `.protolock` as a dated snapshot; then
archive. Order matters, because an archived repo is read-only.

Then, separately and locally, `~/.proto/.git` moves into the backup directory.
Deprecation is not finished while it exists: it claims ownership of
`~/.proto/.prototools`, so any `git checkout`, `git switch` or `git pull` run
there restores the old record over the link, and `git status` reports consus's
version as modified.

## What breaks in sancus

Prose only, which is the worst kind — it fails on rebuild day and nowhere
earlier. No sancus script references proto; the only hits under `bin/` and
`files/` are `brew "proto"` in the `Brewfile`, which stays correct.

Eight shipped lines across `README.md` and `docs/restore-checklist.md`: two
table rows, two "four config repos" counts, the adopt-in-place bullet, and the
clone-ordering bullet. That last one does not disappear — it **inverts**. Today
it says clone `dotproto` before anything starts proto, because a stray `proto`
call wedges the clone. Afterwards there is no clone to wedge, and the ordering
constraint becomes consus's: `bin/install` must run before the record is
expected to exist.

A further 41 lines live in sancus's own `docs/superpowers/` and are historical
records of what was true on their date. Whether those get corrected is a
question about that repo's conventions, not this one's, and is left to it.

This work does not touch sancus. It is recorded here so the follow-up is not
lost.

## Phases

0. Remove the self-installed proto so Homebrew's 0.62.2 wins, and confirm
   `proto status` recovers.
1. Move `~/.proto/.git` into a timestamped backup directory.
2. Add `configs/proto/.prototools` and `configs/proto/README.md`, the
   `.gitignore` line, and the `conf.d/proto.fish` corrections.
3. Teach `bin/install` the proto path and `bin/doctor` the two checks, with the
   sandbox suites extended to cover the file-link classify, the overwrite path,
   the refuse path, the digest contract and a severed link.
4. Run `bin/install`, review the diff it prints, and let it place the link.
5. `bin/doctor` exits 0.
6. Update `README.md` and the 2026-08-21 design.
7. Deprecate dotproto: pointer commit, then archive.

Phases 0 and 1 are the only ones that touch the machine before the record
exists, and both are reversible by moving something back.

## Rollback

Move the backed-up `.prototools` from the timestamped directory back over the
link, and move `~/.proto/.git` back if the checkout is wanted again. proto reads
a regular file exactly as it reads the link, so the machine is whole the moment
the file is in place. Reinstalling proto 0.58.2 is a `proto install proto
0.58.2` away but should not be wanted.

## Deliberately out of scope

- **The store's own drift.** Roughly 400 MB of `tools/` is versions nothing
  pins, four tool directories have no manifest, and the self-managed proto
  manifest disagrees with its own directory. `auto-clean` has not kept up.
  Recording the pins does not clean the store, and `proto clean` is a separate,
  network-free decision worth making on its own.
- **`rust`.** The pin stays, but proto's rust support defers to `~/.rustup`,
  which `configs/fish/conf.d/rustup.fish` already sources. Whether proto should
  own rust at all is a real question and not this change's.
- **sancus.** Eight prose lines, listed above, in another repo.
- **`~/.prototools`.** Does not exist on this machine and is not created. It
  would outrank the global record for everything under `$HOME` if it appeared,
  which is worth a doctor assertion someday.

## Open items

- **`proto regen --bin` is never invoked by this design**, because the store
  does not move. If it ever does, the ruby finding makes a reinstall mandatory
  and `regen` insufficient — that is recorded in "Verified facts" so a future
  relocation starts from it rather than rediscovering it.
- **The declared-but-not-installed check has no fixture yet.** The sandbox
  suites build fish and git trees; a proto fixture needs a fake
  `tools/<tool>/<version>/` layout, which is cheap but new.
- **Whether `lockfile = true` should stay at all.** It is inert at global scope
  today. It is kept because it expresses intent and costs nothing, and because
  upstream may honour global lockfiles later. Dropping it is a one-line change.
