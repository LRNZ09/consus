# claude into consus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the hand-written part of `~/.claude` — `settings.json`,
`AGENTS.md`, `hooks/` and the status-line script — into `consus` under
`configs/claude/`, reached through four links at Claude Code's own paths; move
the placeholder filter in as `bin/placeholders` with its guards covering the
whole repo; drop `~/.claude/CLAUDE.md`; and archive `LRNZ09/dotclaude`.

**Architecture:** Two file links (`settings.json`, `AGENTS.md`) and two
directory links (`hooks/`, `scripts/`). Claude Code saves `settings.json` by
temp file and rename on the link *target*, so the link survives and every save
lands here as an unstaged modification. Git stores placeholders for the private
`autoMode` values through a clean/smudge filter; the same script, run by
lefthook in `pre-commit`, `commit-msg` and `pre-push`, refuses any work term
anywhere in the repo. `bin/doctor` gains the four link tests, a version floor,
and the filter and map assertions.

**Tech Stack:** bash (`bin/placeholders` and the sandbox harnesses; `/usr/bin/env
bash` is `/bin/bash` 3.2.57 here), bats 1.14.0 (`bin/doctor.bats`), jq, git
2.55, lefthook 2.1.14, gitleaks, Claude Code 2.1.273 (terminal, stable cask)
and 2.1.281 (bundled in the VS Code extension), `gh` for the archive only.

**Spec:** `docs/superpowers/specs/2026-09-24-claude-into-consus-design.md`.
Read it alongside this plan: every "why" lives there, and this plan argues from
it without restating its measurements.

## Who runs what

This plan is **not** unattended, unlike the proto one. The executor stops and
waits at each of these, and a refinement of the wording is not a yes:

1. **Task 1** — the human backs up and narrows the map,
   `~/.claude/placeholders.tsv`. The executor never edits it, never prints a
   line of it, and never runs a check that prints a hit.
2. **Task 4 Step 5 or Task 6 Step 4** — if a commit is refused with "private
   term(s) found", the human decides what to map or change.
3. **Task 6 Step 2** — pushing dotclaude's pointer commit.
4. **Task 9 Step 1** — pushing consus, which is public, after the human has
   read the full diff.
5. **Task 9 Step 2** — archiving dotclaude.

## Global Constraints

Every task's requirements implicitly include this section.

- **Clone path:** `~/Developer/LRNZ09/consus`, on `main`. Every commit is
  signed (the clone's config does this). **Nothing in consus is pushed before
  Task 9**; dotclaude's pointer commit is pushed in Task 6 Step 2.
- **This plan and the spec's correction are committed on their own before Task
  0** (see "Execution order"), so the tree is clean and Task 1's audit covers
  both.
- **State file:** `~/Backups/claude-consus.env`, written once by Task 0. Every
  later step opens with `. ~/Backups/claude-consus.env`.
- **Sandbox:** `$SB` (`~/Backups/claude-consus-sandbox`, mode 700). The three
  harness scripts live there and are **not committed**, as the proto plan's
  harness was not: the spec fixes the repo layout, and a `tests/` directory is
  not a decision this plan gets to make.
- **Nothing on this machine is ever deleted.** Every displaced path is moved
  into `$BK` (`~/Backups/dotclaude-<timestamp>/`, mode 700), or copied there
  first when a rename is what replaces it. Exceptions, none of them outside a
  sandbox or this plan's own links: harnesses delete their own `mktemp`
  directories; Task 6 removes a stale `*.consus-link` it created itself; the
  rollback removes the links this plan made, never their targets; and Task 9
  Step 5, at the human's request, removes the raw copies of `settings.json`
  the old filter leaked into the user temp directory.
- **Backups go to `~/Backups` only**, never `~/Desktop` or `~/Documents`, both
  iCloud-synced.
- **`CLAUDE_CONFIG_DIR` is never set** by anything this plan writes. Task 0
  asserts it is unset; `bin/doctor.bats` *reads* it, mirroring Claude Code.
- **No work term in any committed file or commit message.** Fixtures use only
  the invented `zorblax`, `quuxcorp`, `ZQX`, the `.example` domain and
  `192.0.2.7` (RFC 5737's documentation range). The real map is never copied
  into the sandbox and never read by a harness.
- **Never `--no-verify`, never `LEFTHOOK=0`.** Hook-less commits exist only in
  sandbox repos: every commit in `test-placeholders.sh`'s fixture repo, and
  `test-wiring.sh`'s two leak fixtures, built with `-c core.hooksPath=<empty
  dir>` to prove `pre-push` stops what `pre-commit` would have.
- **No Brewfile change, no cask swap.** `autoUpdatesChannel` stays `"stable"`.
  The terminal `claude` is 2.1.273, so doctor's version test **fails on
  purpose** after activation; that is the one expected failure.
- **Environment for every command:**

  ```sh
  export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 GIT_EDITOR=false
  ```

- **Every destructive step guards its variables:**

  ```sh
  set -eu
  . ~/Backups/claude-consus.env
  : "${CLONE:?}" "${CH:?}" "${BK:?}" "${SB:?}"
  ```

  A state file that failed to source would otherwise expand them empty and aim
  a `mv` at `/`. **Every check that pipes into another command also sets
  `-o pipefail`**, or a failing producer feeds the check empty input and the
  `✔` prints anyway.
- **Commits** pass `-m` or `-F`; messages are sentence-case imperatives with no
  conventional-commit prefix and a wrapped body, as in `git log`. No
  `git commit --amend`, no `git reset --hard`, no interactive rebase.
- **`bin/placeholders` is bash**, as its predecessor was — it needs `pipefail`,
  `$'\t'` and process substitution — and must work on bash 3.2. Hard tabs for
  indentation, like `bin/doctor.bats`. It must pass `bash -n`.
- **`.gitignore`: no pattern carries a trailing comment.** gitignore honours
  `#` only at the start of a line.
- **Never commit a non-noreply email address** — `.gitleaks.toml` flags it.
  Sandbox commits use `sandbox@users.noreply.github.com`.
- **`bin/doctor` stays read-only and network-free.** `claude --version` is the
  only Claude Code invocation it makes.
- **bats expands a leading `~` in test names.** Measured on bats 1.14.0 under
  bash 3.2: `~/.claude/settings.json links into this clone` prints, and
  matches `--filter`, as `/Users/<you>/.claude/settings.json links into this
  clone`. Never grep doctor output or filter for a literal `~/`.
- **The record's `settings.json` is always derived by one transform** from the
  live file, so Task 4 and Task 6 cannot drift apart:

  ```sh
  jq --tab '.statusLine.command = "bash ~/.claude/scripts/statusline.sh"
  	| .pluginConfigs["agents-md@builtin"].options.instructionFiles = "claude-md-and-agents-md"'
  ```

## Review Focus

The five failure modes the spec implies but no happy-path test exercises, most
likely first. Each has a test in the owning task.

1. **Claude Code saves `settings.json` mid-migration** — between the record
   being taken and the link going in. Expected: the change is carried into the
   record, never lost. Task 6 Step 5 re-derives the record from the live file
   immediately before each rename and refuses to swap if they differ.
2. **A new work value arrives through the UI** — `/permissions` or
   `/auto-mode-setup` writes an entry naming work infrastructure. Expected:
   `git add` fails closed, nothing is staged, and no raw copy is left in
   `$TMPDIR`. Tasks 2 and 3.
3. **A guard lefthook would skip** — a typechange-only commit, an empty commit,
   a push of a branch other than `HEAD`. Expected: refused. lefthook 2.1.14
   skips a *command* whose file list is empty, so the guard is a lefthook
   *script* in `pre-commit` and `pre-push`. Task 3.
4. **A commit from a subdirectory**, the way an editor's git integration does.
   Expected: the filter and the guards apply, refusals included. Task 3.
5. **A machine without the map, or with a broken guard regex.** Expected:
   every commit refused with a message naming the map, and doctor naming the
   same file. Tasks 2, 3 and 5.

## Execution order, and the gates

- **Before Task 0**, once the human has approved this plan: commit the spec's
  correction and this plan, each on its own, under consus's current
  gitleaks-only hooks. Task 1's audit then covers both texts and both
  messages.

  ```sh
  cd ~/Developer/LRNZ09/consus
  git add docs/superpowers/specs/2026-09-24-claude-into-consus-design.md
  git commit -F - <<'EOF'
  Run the guard as lefthook scripts in the claude design

  An adversarial review of the plan measured that lefthook 2.1.14 skips a
  command whose file list is empty, so a guard written as one let an empty
  commit, a typechange and a push of another branch through. pre-commit and
  pre-push run it as scripts instead, which lefthook never skips. check now
  refuses a guard regex that does not compile, and clean no longer leaves a
  raw copy of its input behind when it refuses.
  EOF
  git add docs/superpowers/plans/2026-09-24-claude-into-consus.md
  git commit -m 'Add the claude migration plan'
  ```

- **Task 0** changes nothing and must pass first.
- **Task 1** is the human's: the audit must come back empty before Task 3
  switches the guards on.
- **Tasks 2–5** happen entirely inside the clone and the sandbox. `~/.claude`
  is untouched.
- **Task 5's sandbox run is the gate.** No step of Task 6 may start until
  `test-doctor.sh` passes.
- **Task 6 is the only task that changes `~/.claude`'s configuration.** Task 1
  (the map, by the human) and Task 9 Step 3 (the memory files) edit other
  files there.
- **Tasks 7–8** verify and document. **Task 9** publishes.

## File Structure

```text
~/Developer/LRNZ09/consus/
├── .gitattributes                   Task 3 — NEW: settings.json filter=placeholders
├── .gitignore                       Task 4 — one defensive line
├── .lefthook/                       Task 3 — NEW: the guard as lefthook scripts
│   ├── pre-commit/placeholders.sh
│   └── pre-push/placeholders.sh
├── lefthook.yml                     Task 3
├── README.md                        Task 8
├── INSTALL.md                       Task 8
├── bin/
│   ├── placeholders                 Task 2 — NEW: filter + guards (bash)
│   └── doctor.bats                  Task 5 — 7 new tests, 1 changed, 1 advisory
├── configs/claude/                  Task 4 — NEW
│   ├── AGENTS.md
│   ├── README.md
│   ├── settings.json                placeholders in git, real values on disk
│   ├── hooks/{pre-bash-memory-grep.sh,pre-bash-prefer-mcp.sh,cli-mcp-map.tsv}
│   └── scripts/statusline.sh        was ~/.claude/statusline-command.sh
└── docs/superpowers/
    ├── specs/2026-09-24-claude-into-consus-design.md   Task 8 — Status line
    ├── specs/2026-08-21-consus-migration-design.md     Task 8 — 4 edits
    └── plans/2026-09-24-claude-into-consus.md          this plan

~/Backups/claude-consus-sandbox/     NOT committed
├── test-placeholders.sh             Task 2
├── test-wiring.sh                   Task 3
└── test-doctor.sh                   Task 5
```

---

### Task 0: Preflight

Changes nothing on the machine except writing the state file and making the
sandbox directory.

**Files:** none in the repo. Creates `~/Backups/claude-consus.env`, `$SB`.

**Interfaces:**

- Produces: `CLONE`, `CH`, `BK`, `SB`, `CONSUS_BASE` in the state file.
  `CONSUS_BASE` is the plan's own commit, so `CONSUS_BASE..HEAD` is exactly
  the commits this plan makes.

- [ ] **Step 1: Refuse to start over a run in progress, then write the state file**

```sh
set -eu
[ ! -e ~/Backups/claude-consus.env ] || {
	echo "✖ ~/Backups/claude-consus.env exists — a run is in progress; resume it"
	exit 1
}
[ -z "${CLAUDE_CONFIG_DIR:-}" ] || { echo "✖ CLAUDE_CONFIG_DIR is set; unset it first"; exit 1; }
mkdir -p ~/Backups && chmod 700 ~/Backups
TS=$(date +%Y%m%dT%H%M%S)
# Unquoted heredoc on purpose: every value is expanded now and written as a
# literal, so sourcing the file later never re-evaluates a timestamp.
cat > ~/Backups/claude-consus.env <<EOF
# claude-into-consus migration state. Sourced by every task in
# docs/superpowers/plans/2026-09-24-claude-into-consus.md. Never committed.
CLONE=$HOME/Developer/LRNZ09/consus
CH=$HOME/.claude
BK=$HOME/Backups/dotclaude-$TS
SB=$HOME/Backups/claude-consus-sandbox
CONSUS_BASE=$(cd "$HOME/Developer/LRNZ09/consus" && git rev-parse HEAD)
EOF
chmod 600 ~/Backups/claude-consus.env
. ~/Backups/claude-consus.env
mkdir -p "$SB" && chmod 700 "$SB"
cat ~/Backups/claude-consus.env
```

Expected: five `KEY=value` lines with absolute paths.

- [ ] **Step 2: Assert the machine is in the state the spec measured**

```sh
set -eu
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}" "${SB:?}"
bad=0
say() { echo "✖ $*"; bad=1; }

for t in jq bats lefthook gitleaks gh claude gpg markdownlint-cli2; do
	command -v "$t" >/dev/null || say "$t is not installed"
done
gh auth status >/dev/null 2>&1 || say "gh is not authenticated (needed for the archive only)"

cd "$CLONE"
[ "$(git branch --show-current)" = main ] || say "consus is not on main"
[ -z "$(git status --porcelain)" ] || say "consus has uncommitted changes"
[ "$(git log -1 --format=%s)" = 'Add the claude migration plan' ] || say "the plan is not HEAD — see Execution order"
[ -x bin/doctor ] || say "consus has no bin/doctor"

cd "$CH"
[ -d .git ] || say "~/.claude is not the dotclaude checkout"
dirty=$(git status --porcelain | grep -v '^ M settings\.json$' || true)
[ -z "$dirty" ] || say "dotclaude has changes other than settings.json: $dirty"
for f in settings.json AGENTS.md statusline-command.sh CLAUDE.md; do
	[ -f "$f" ] && [ ! -L "$f" ] || say "~/.claude/$f is not a regular file"
done
[ -d hooks ] && [ ! -L hooks ] || say "~/.claude/hooks is not a real directory"
[ ! -e scripts ] || say "~/.claude/scripts already exists"
[ -x .git/placeholders-filter.sh ] || say "dotclaude's filter script is missing"

map="$CH/placeholders.tsv"
[ -r "$map" ] || say "$map is missing"
[ "$(stat -f %Lp "$map")" = 600 ] || say "$map is not mode 600"

# Moving ~/.claude/.git later would expose ~/.claude to any repo rooted above
# it. None exists today; if one appears, stop.
(cd "$HOME" && git rev-parse --show-toplevel >/dev/null 2>&1) && say "\$HOME is inside a git repo"

# Every task commits, so signing without a prompt is what has to work.
cd "$CLONE"
key=$(git config --get user.signingkey || true)
[ -n "$key" ] || say "no user.signingkey for consus"
printf 'preflight\n' | gpg --batch --local-user "$key" --detach-sign >/dev/null 2>&1 ||
	say "gpg cannot sign without a prompt"

claude --version
[ "$bad" -eq 0 ] && echo "✔ preflight passed"
```

Expected: `2.1.273 (Claude Code)` then `✔ preflight passed`. Any `✖` line stops
the plan here.

No commit: nothing in the repo changed.

---

### Task 1: The map — back it up and narrow the guard (human)

The guards will cover all of consus, and today it fails them: tracked files and
one commit message, all through two over-broad alternatives in the map's
`guard` row that match strings consus publishes legitimately — the `includeIf`
path and proto's file name. The record Task 4 will add is audited here too, so
a hit in it is resolved now rather than at a refused commit.

**Files:** `~/.claude/placeholders.tsv` (untracked, private). Nothing in the
repo.

- [ ] **Step 1: Back up the map before anything edits it**

```sh
set -eu
cp -p ~/.claude/placeholders.tsv ~/Backups/placeholders.tsv.pre-narrow-"$(date +%Y%m%dT%H%M%S)"
ls -l ~/Backups/placeholders.tsv.pre-narrow-*
```

Expected: one file, mode `-rw-------`. This copy only undoes a bad edit in
Step 3; it is not the off-machine backup Step 4 asks about.

- [ ] **Step 2: Run the audit — counts only, never the hits**

```sh
set -eu
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}"
F="$CH/.git/placeholders-filter.sh"
cd "$CLONE"
git ls-files -z | while IFS= read -r -d '' f; do
	n=$("$F" check < "$f" 2>&1 | grep -c '^[0-9]*:' || true)
	[ "$n" -eq 0 ] || echo "$n $f"
done
for f in "$CH/AGENTS.md" "$CH"/hooks/* "$CH/statusline-command.sh"; do
	n=$("$F" check < "$f" 2>&1 | grep -c '^[0-9]*:' || true)
	[ "$n" -eq 0 ] || echo "$n $f"
done
echo "--- commit messages:"
git log --format=%B | "$F" check 2>&1 | grep -c '^[0-9]*:' || true
```

Expected before the edit: nine or so consus files and a nonzero message count;
no `~/.claude` file. `bin/placeholders` does not exist yet, so this uses
dotclaude's current script.

- [ ] **Step 3: STOP — the human narrows the `guard` row**

The human, in their own terminal, runs `"$HOME/.claude/.git/placeholders-filter.sh"
check < <file>` on any file Step 2 named to see its hits, and edits the `guard`
row of `~/.claude/placeholders.tsv`. The executor runs neither and waits.

- [ ] **Step 4: Re-run Step 2's commands, then the gates**

Expected from Step 2's commands: no file lines, and `0` for commit messages.
Then:

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
cd "$CH"
F=.git/placeholders-filter.sh
# grep exits 2 on a regex it cannot compile, matches nothing, and dotclaude's
# script then passes everything: an empty audit proves nothing until this holds.
[ "$(printf 'x\n' | "$F" check 2>&1 | grep -c '^grep:' || true)" -eq 0 ] && echo "✔ the guard regexes compile"
[ "$(grep -c "^guard$(printf '\t')" placeholders.tsv)" -eq 1 ] && echo "✔ exactly one guard row"
git show HEAD:settings.json | "$F" check && echo "✔ dotclaude's stored settings still pass"
"$F" clean < settings.json >/dev/null && echo "✔ the live settings still clean"
```

Expected: four `✔` lines. Then the executor asks the human to confirm that the
off-machine backup of the map — wherever the human keeps it — now holds the
narrowed version. That backup, not `~/Backups`, is what INSTALL.md means by
"restore the map from backup".

No commit.

---

### Task 2: `bin/placeholders`

The filter and the three guards as one script with explicit subcommands. The
code is dotclaude's `.git/placeholders-filter.sh`, re-indented with tabs, with
four changes: dispatch on `$1` instead of the script's own name; `check` names
an unreadable map instead of reporting a missing guard row; `check` refuses a
guard regex that does not compile; and `check`'s temp file no longer shadows
the `clean`/`smudge` trap, which left a raw copy of the input in `$TMPDIR`
every time `clean` refused.

**Files:**

- Create: `bin/placeholders`
- Test: `$SB/test-placeholders.sh` (not committed)

**Interfaces:**

- Produces, for Tasks 3–5: `bin/placeholders clean|smudge` (stdin → stdout),
  `bin/placeholders check` (stdin), `bin/placeholders check-msg FILE`,
  `bin/placeholders check-staged`, `bin/placeholders check-push REMOTE`
  (git's pre-push ref lines on stdin). Exit 0 = pass, 1 = refused, 2 = usage
  (an unknown subcommand, or a missing argument). The map is
  `${PLACEHOLDER_MAP:-$HOME/.claude/placeholders.tsv}`. Temp files go under
  `${TMPDIR:-/tmp}` and never outlive a run.

- [ ] **Step 1: Write the harness**

Write `$SB/test-placeholders.sh`:

```bash
#!/usr/bin/env bash
# claude-into-consus sandbox: bin/placeholders against an invented map.
# Never reads the real map. Usage: test-placeholders.sh /path/to/bin/placeholders
set -uo pipefail
. ~/Backups/claude-consus.env
: "${SB:?}"
P=${1:?usage: test-placeholders.sh /path/to/bin/placeholders}
T=$(mktemp -d "$SB/ph.XXXXXX")
trap 'rm -rf "$T"' EXIT
[ -x "$P" ] || { echo "FAIL $P is not executable"; exit 1; }
mkdir "$T/tmp" && export TMPDIR="$T/tmp"
export PLACEHOLDER_MAP="$T/map.tsv"
printf '%s\n' '# invented fixture: no real term appears in this file' \
	"guard	zorblax|quuxcorp" \
	"guard_cs	ZQX" \
	"api.zorblax.example	<api-host>" \
	"zorblax	<company>" \
	"192.0.2.7	<ip>" > "$PLACEHOLDER_MAP"

pass=0 failed=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf 'FAIL %s\n' "$1"; }
# Exit status exactly: 0 passes, 1 is a refusal. Anything else — a crash, a
# usage error, a missing command — is neither, and fails both expectations.
expect_ok() { local n=$1 rc; shift; "$@" >/dev/null 2>&1; rc=$?; [ "$rc" -eq 0 ] && ok "$n" || bad "$n (rc=$rc)"; }
expect_fail() { local n=$1 rc; shift; "$@" >/dev/null 2>&1; rc=$?; [ "$rc" -eq 1 ] && ok "$n" || bad "$n (rc=$rc)"; }
clean_of() { printf '%s' "$1" | "$P" clean; }

# --- the filter
got=$(clean_of '{"b":"api.zorblax.example","a":["zorblax corp"]}')
want=$(printf '{\n\t"a": [\n\t\t"<company> corp"\n\t],\n\t"b": "<api-host>"\n}')
[ "$got" = "$want" ] && ok "clean swaps mapped values, longest first, in canonical layout" ||
	bad "clean swaps mapped values, longest first, in canonical layout"

in='{"z":1,"b":"api.zorblax.example","a":{"y":"zorblax"}}'
back=$(printf '%s' "$in" | "$P" clean | "$P" smudge)
[ "$back" = "$(printf '%s' "$in" | jq -j -S --tab .)" ] && ok "smudge undoes clean" || bad "smudge undoes clean"

expect_fail "clean refuses an unmapped guarded term" clean_of '{"a":"quuxcorp"}'
expect_fail "clean refuses it in any case" clean_of '{"a":"QuuxCorp"}'
expect_fail "clean refuses a case-sensitive guarded term" clean_of '{"a":"ZQX"}'
expect_ok "clean allows the case-sensitive term in another case" clean_of '{"a":"zqx"}'
expect_fail "clean refuses invalid JSON" clean_of '{"a":'

out=$(printf '{"a":"<company>"}' | PLACEHOLDER_MAP="$T/none" "$P" smudge 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = '{"a":"<company>"}' ] && ok "smudge without a map passes the blob through" ||
	bad "smudge without a map passes the blob through"

# --- the value scan on its own: 192.0.2.7 is mapped but no guard regex names it
value_check() { printf 'db at 192.0.2.7\n' | "$P" check; }
expect_fail "check refuses a mapped value the guard regex misses" value_check

# --- fail closed (Review Focus 5)
nomap_check() { printf 'neutral text\n' | PLACEHOLDER_MAP="$T/none" "$P" check; }
expect_fail "check refuses everything without a map" nomap_check
out=$(nomap_check 2>&1)
printf '%s\n' "$out" | grep -qF "can't read $T/none" && ok "and names the map it could not read" ||
	bad "and names the map it could not read"
printf 'x\t<y>\n' > "$T/noguard.tsv"
noguard_check() { printf 'neutral text\n' | PLACEHOLDER_MAP="$T/noguard.tsv" "$P" check; }
expect_fail "check refuses everything with no guard row" noguard_check
# A trailing | is what deleting the last alternative by hand leaves behind.
printf '%s\n' "guard	zorblax|" > "$T/badrx.tsv"
badrx_check() { printf 'zorblax\n' | PLACEHOLDER_MAP="$T/badrx.tsv" "$P" check; }
expect_fail "check refuses everything when a guard regex does not compile" badrx_check

# --- commit messages and usage
printf 'Add the claude record\n' > "$T/msg-ok"
printf 'Mention Zorblax in passing\n' > "$T/msg-bad"
expect_ok "check-msg passes a neutral message" "$P" check-msg "$T/msg-ok"
expect_fail "check-msg refuses a guarded term" "$P" check-msg "$T/msg-bad"
"$P" frobnicate >/dev/null 2>&1; [ $? -eq 2 ] && ok "an unknown subcommand exits 2" || bad "an unknown subcommand exits 2"
"$P" check-msg >/dev/null 2>&1; [ $? -eq 2 ] && ok "check-msg without a file exits 2" || bad "check-msg without a file exits 2"
"$P" check-push </dev/null >/dev/null 2>&1; [ $? -eq 2 ] && ok "check-push without a remote exits 2" ||
	bad "check-push without a remote exits 2"

# --- staged diffs
g() {
	git -c user.name=sandbox -c user.email=sandbox@users.noreply.github.com \
		-c commit.gpgsign=false -c core.hooksPath="$T/nohooks" "$@"
}
mkdir -p "$T/nohooks"
git init -q -b main "$T/repo" && cd "$T/repo"
printf 'zorblax\n' > old.txt && g add old.txt && g commit -q -m base
g rm -q old.txt
expect_ok "check-staged allows removing a guarded term" "$P" check-staged
g commit -q -m 'Remove old'
printf 'hello quuxcorp\n' > new.txt && g add new.txt
expect_fail "check-staged refuses an added guarded term" "$P" check-staged
g rm -q --cached new.txt && rm new.txt
printf 'hello\n' > fine.txt && g add fine.txt
expect_ok "check-staged passes a neutral change" "$P" check-staged
g commit -q -m 'Add fine'

# --- pushes
git init -q --bare "$T/remote.git"
g remote add origin "$T/remote.git" && g push -q origin main
base=$(git rev-parse HEAD)
Z=0000000000000000000000000000000000000000
pp() { printf '%s %s %s %s\n' "$1" "$2" "$3" "$4" | "$P" check-push origin; }
printf 'more\n' >> fine.txt && g commit -q -am 'Extend fine'
expect_ok "check-push passes a neutral commit" pp refs/heads/main "$(git rev-parse HEAD)" refs/heads/main "$base"
g commit -q --allow-empty -m 'Mention zorblax'
expect_fail "check-push refuses a guarded term in a message" pp refs/heads/main "$(git rev-parse HEAD)" refs/heads/main "$base"
g switch -q -c content "$base"
printf 'quuxcorp\n' > leak.txt && g add leak.txt && g commit -q -m 'Add leak'
expect_fail "check-push refuses a guarded term in content" pp refs/heads/content "$(git rev-parse HEAD)" refs/heads/content "$Z"
expect_ok "check-push skips a branch deletion" pp '(delete)' "$Z" refs/heads/gone "$base"
expect_ok "check-push scans only what the remote lacks on a new branch" pp refs/heads/new "$base" refs/heads/new "$Z"

# --- Review Focus 2: every refusal above ran with TMPDIR here
[ -z "$(ls -A "$T/tmp")" ] && ok "no temporary file outlives a run, refused or not" ||
	bad "no temporary file outlives a run, refused or not"

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
```

```sh
chmod +x ~/Backups/claude-consus-sandbox/test-placeholders.sh
```

- [ ] **Step 2: Run it to see it fail**

```sh
. ~/Backups/claude-consus.env && "$SB/test-placeholders.sh" "$CLONE/bin/placeholders"
```

Expected: `FAIL …/bin/placeholders is not executable`, exit 1.

- [ ] **Step 3: Write `bin/placeholders`**

```bash
#!/usr/bin/env bash
# consus/bin/placeholders — keeps private values and work terms out of what git
# stores. See configs/claude/README.md, "Private values".
#
# As the git filter on configs/claude/settings.json (.gitattributes names the
# file; the filter itself is per-clone git config, INSTALL.md step 2):
#   clean              settings.json -> blob: canonical JSON with placeholders;
#                      fails closed
#   smudge             blob -> settings.json: real values back; never fails, so
#                      a broken map cannot make a checkout delete the file
# As lefthook's guards (lefthook.yml), over the whole repo:
#   check-msg FILE     commit-msg: the message in FILE
#   check-staged       pre-commit: the lines the staged diff adds
#   check-push REMOTE  pre-push: every message and added line in the commits
#                      being pushed, read from git's ref lines on stdin
# And by hand:
#   check              stdin: fail if it names a private term
#
# Exit 0 passes, 1 refuses, 2 is a usage error. The map is
# ~/.claude/placeholders.tsv, untracked; PLACEHOLDER_MAP overrides it. Without
# it every guard refuses everything, on purpose.
set -uo pipefail
export LC_ALL=C PATH=$PATH:/opt/homebrew/bin
map=${PLACEHOLDER_MAP:-$HOME/.claude/placeholders.tsv}

fail() { echo "placeholders: $*" >&2; exit 1; }
usage() { echo "usage: placeholders $*" >&2; exit 2; }

# Swaps values for placeholders (clean) or back (smudge) in every JSON string,
# longest first, and prints canonical JSON: sorted keys, tabs, no final newline.
swap() {
	[ -r "$map" ] || { echo "placeholders: can't read $map" >&2; return 1; }
	jq -j -S --tab --rawfile m "$map" --arg mode "$1" '
		([$m | split("\n")[] | select(test("^(#|guard(_cs)?\t|\\s*$)") | not) | split("\t")
			| if length == 2 and all(length > 0) then . else error("bad map row: \(join("<TAB>"))") end]
			| if (map(.[1]) | unique | length) < length then error("a placeholder is used twice") else . end
			| map(if $mode == "clean" then . else reverse end)
			| sort_by(-(.[0] | length))) as $rows
		| walk(if type == "string" then reduce $rows[] as [$from, $to] (.; split($from) | join($to)) else . end)'
}

# Fails when stdin names a guarded term or a mapped value; prints each hit.
# Its temp file is $buf, never $tmp: a local tmp here would shadow the one
# clean's and smudge's EXIT trap removes, and leave their raw input behind.
check() {
	local buf kind rx ci= cs= hits
	buf=$(mktemp "${TMPDIR:-/tmp}/placeholders.XXXXXX") || exit 1
	cat > "$buf"
	[ -r "$map" ] || { rm -f "$buf"; fail "can't read $map, refusing to pass anything"; }
	while IFS=$'\t' read -r kind rx || [ -n "$kind" ]; do
		case $kind in guard) ci=$rx ;; guard_cs) cs=$rx ;; esac
	done < "$map"
	[ -n "$ci" ] || { rm -f "$buf"; fail "no guard row in $map, refusing to pass anything"; }
	# grep exits 2 on a regex it cannot compile and matches nothing, which would
	# pass everything: each guard must compile first.
	for rx in "$ci" "$cs"; do
		[ -n "$rx" ] || continue
		grep -E -e "$rx" /dev/null 2>/dev/null
		[ $? -eq 1 ] || { rm -f "$buf"; fail "a guard row in $map is not a valid extended regex, refusing to pass anything"; }
	done
	hits=$({ grep -a -n -o -i -E "$ci" "$buf"
		[ -z "$cs" ] || grep -a -n -o -E "$cs" "$buf"
		awk -F '\t' '!/^#/ && NF == 2 && $1 !~ /^guard(_cs)?$/ { print $1 }' "$map" | grep -a -n -o -w -F -f - "$buf"
	} | sort -u -t : -k 1n -k 2)
	rm -f "$buf"
	[ -z "$hits" ] || fail "private term(s) found; map them in $map or keep them in a work repo:
$hits"
}

# Keeps added lines and file headers; a diff with nothing added is not an error.
added_lines() { grep -a -E '^(\+|diff --git )' || [ $? -eq 1 ]; }

case ${1:-} in
	clean)
		tmp=$(mktemp -d "${TMPDIR:-/tmp}/placeholders.XXXXXX") || exit 1
		trap 'rm -rf "$tmp"' EXIT
		cat > "$tmp/in"
		swap clean < "$tmp/in" > "$tmp/out" || fail "settings.json is not valid JSON, or $map is unreadable"
		jq -j -S --tab . "$tmp/in" | cmp -s - <(swap smudge < "$tmp/out") ||
			fail "placeholders don't swap back to the same file; make them unique in $map"
		check < "$tmp/out"
		cat "$tmp/out"
		;;
	smudge)
		tmp=$(mktemp -d "${TMPDIR:-/tmp}/placeholders.XXXXXX") || exit 1
		trap 'rm -rf "$tmp"' EXIT
		cat > "$tmp/in"
		if swap smudge < "$tmp/in" > "$tmp/out" 2> "$tmp/err"; then
			cat "$tmp/out"
		else
			echo "placeholders: $(head -1 "$tmp/err"); checked out with placeholders" >&2
			cat "$tmp/in"
		fi
		;;
	check) check ;;
	check-msg)
		[ -n "${2:-}" ] || usage "check-msg FILE"
		check < "$2"
		;;
	check-staged) git diff --cached -U0 --no-renames --text | added_lines | check ;;
	check-push)
		[ -n "${2:-}" ] || usage "check-push REMOTE"
		remote=$2
		while read -r _ sha _ _; do
			[ "$sha" = 0000000000000000000000000000000000000000 ] && continue
			{ git log --format=%B "$sha" --not --remotes="$remote"
				git log -p -U0 --no-renames --text --diff-merges=first-parent --format= "$sha" --not --remotes="$remote" | added_lines
			} | check || exit 1
		done
		;;
	*) usage "clean|smudge|check|check-msg FILE|check-staged|check-push REMOTE" ;;
esac
```

```sh
cd ~/Developer/LRNZ09/consus && chmod +x bin/placeholders && bash -n bin/placeholders
```

- [ ] **Step 4: Run the harness to see it pass**

```sh
. ~/Backups/claude-consus.env && "$SB/test-placeholders.sh" "$CLONE/bin/placeholders"
```

Expected: 27 `ok` lines, `27 passed, 0 failed`, exit 0.

- [ ] **Step 5: Check it against the real map without printing anything**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
cd "$CLONE"
git ls-files -z | xargs -0 cat | bin/placeholders check && echo "✔ every tracked file passes"
git log --format=%B | bin/placeholders check && echo "✔ every commit message passes"
bin/placeholders check < bin/placeholders && echo "✔ the script itself passes"
bin/placeholders clean < "$CH/settings.json" | bin/placeholders check && echo "✔ the live settings clean"
```

Expected: four `✔` lines. The first two are Task 1's gate, re-run through the
new script; the plan's own text and commit messages are among what they scan.

- [ ] **Step 6: Commit**

```sh
cd ~/Developer/LRNZ09/consus
git add bin/placeholders
git commit -F - <<'EOF'
Add bin/placeholders

dotclaude's placeholder filter, moved here so it can guard a public repo. It
dispatched on its own name because it was symlinked as each git hook; lefthook
owns the hooks here, so the three hook bodies become check-msg, check-staged
and check-push.

check now names an unreadable map, and refuses a guard regex that does not
compile, where grep's exit 2 used to pass everything. Its temp file no longer
shadows the one clean's trap removes, which left a raw copy of the input in
TMPDIR every time clean refused.

Nothing is wired yet: .gitattributes and lefthook.yml come next.
EOF
```

This commit's message meets no guard yet; Step 5 already scanned it, as part
of the plan's text.

---

### Task 3: Wire the filter and the guards

**Files:**

- Create: `.gitattributes`, `.lefthook/pre-commit/placeholders.sh`,
  `.lefthook/pre-push/placeholders.sh`
- Modify: `lefthook.yml` (whole file below)
- Test: `$SB/test-wiring.sh` (not committed)
- Per-clone config: `filter.placeholders.*` in `.git/config`

**Interfaces:**

- Consumes: Task 2's subcommands.
- Produces: `git add configs/claude/settings.json` stores placeholders, and
  lefthook runs the guard in `pre-commit`, `commit-msg` and `pre-push` in this
  clone. Task 5's doctor tests assert
  `filter.placeholders.clean = bin/placeholders clean`,
  `filter.placeholders.smudge = bin/placeholders smudge`,
  `filter.placeholders.required = true`, and lefthook in those three hooks.

- [ ] **Step 1: Write the harness**

Write `$SB/test-wiring.sh`:

```bash
#!/usr/bin/env bash
# claude-into-consus sandbox: the filter and lefthook's guards, wired, in a
# throwaway clone of the real one. Never reads the real map.
set -uo pipefail
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${SB:?}"
T=$(mktemp -d "$SB/wiring.XXXXXX")
trap 'rm -rf "$T"' EXIT
export PLACEHOLDER_MAP="$T/map.tsv"
printf '%s\n' '# invented fixture' "guard	zorblax|quuxcorp" \
	"api.zorblax.example	<api-host>" "192.0.2.7	<ip>" > "$PLACEHOLDER_MAP"

pass=0 failed=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf 'FAIL %s\n' "$1"; }
# Exit status only: git exits 1 when a hook refuses and 128 when a filter does,
# so each refusal below is also checked by its effect.
expect_ok() { local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
expect_fail() { local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n"; else ok "$n"; fi; }
remote_sha() { git ls-remote origin "refs/heads/$1" | cut -f1; }
hookless() { git -c core.hooksPath="$T/nohooks" "$@"; }
filter_on() {
	git config filter.placeholders.clean 'bin/placeholders clean'
	git config filter.placeholders.smudge 'bin/placeholders smudge'
	git config filter.placeholders.required true
}

# A bare copy as the remote, so remote-tracking refs exist and pre-push scans
# only what this harness adds.
git clone -q --bare "$CLONE" "$T/remote.git"
git clone -q "$T/remote.git" "$T/clone"
cd "$T/clone"
git config user.name sandbox
git config user.email sandbox@users.noreply.github.com
git config commit.gpgsign false
filter_on
# From Task 4 on, the clone holds configs/claude/settings.json, checked out
# before the filter existed: check it out again through it, as INSTALL.md
# step 2 does. Before Task 4 the file does not exist and this does nothing.
[ ! -e configs/claude/settings.json ] || { rm configs/claude/settings.json && git restore configs/claude/settings.json; }
lefthook install >/dev/null 2>&1
mkdir -p "$T/nohooks"

for h in pre-commit commit-msg pre-push; do
	grep -q lefthook ".git/hooks/$h" 2>/dev/null && ok "lefthook owns $h" || bad "lefthook owns $h"
done

# --- commit-msg and pre-commit
head=$(git rev-parse HEAD)
printf 'x\n' > a.txt && git add a.txt
expect_fail "commit-msg refuses a guarded term in the message" git commit -q -m 'Add zorblax notes'
[ "$(git rev-parse HEAD)" = "$head" ] && ok "and no commit was made" || bad "and no commit was made"
expect_ok "a neutral commit passes" git commit -q -m 'Add a neutral file'

printf 'quuxcorp\n' > b.txt && git add b.txt
expect_fail "pre-commit refuses a staged guarded term" git commit -q -m 'Add b'
git rm -q --cached b.txt && rm b.txt

# Review Focus 3: a typechange-only commit gives lefthook no staged files, so a
# command would be skipped; the script is not.
printf 'plain\n' > t.txt && git add t.txt && git commit -q -m 'Add t' >/dev/null 2>&1
rm t.txt && ln -s quuxcorp-target t.txt && git add t.txt
expect_fail "pre-commit refuses a typechange that names a guarded term" git commit -q -m 'Change t'
git restore --staged t.txt && rm t.txt && git restore t.txt

# --- Review Focus 4: from a subdirectory, the way an editor commits.
mkdir -p configs/claude && cd configs/claude
expect_fail "commit-msg refuses from a subdirectory" git commit -q --allow-empty -m 'Mention zorblax'
printf '{"autoMode":{"environment":["Source control: api.zorblax.example"]}}' > settings.json
git add settings.json
expect_ok "a commit from a subdirectory passes the filter and the guards" git commit -q -m 'Add sandbox settings'
cd "$T/clone"
S=configs/claude/settings.json
git show "HEAD:$S" | grep -q '<api-host>' && ok "the blob holds the placeholder" || bad "the blob holds the placeholder"
git show "HEAD:$S" | grep -q zorblax && bad "the blob holds no real value" || ok "the blob holds no real value"
[ -z "$(git status --porcelain)" ] && ok "the tree is clean after the commit" || bad "the tree is clean after the commit"
rm "$S" && git restore "$S"
grep -q api.zorblax.example "$S" && ok "a fresh checkout smudges the real value back" ||
	bad "a fresh checkout smudges the real value back"
cp "$S" "$T/settings.good"

# --- Review Focus 2: a value that arrived through the UI, unmapped.
printf '{"autoMode":{"environment":["Trusted: quuxcorp.example"]}}' > "$S"
expect_fail "git add refuses an unmapped guarded term in settings.json" git add "$S"
git diff --cached --quiet && ok "and nothing was staged" || bad "and nothing was staged"
cp "$T/settings.good" "$S"

# --- the raw path: with the filter undefined, a mapped value the guard regex
# misses is still refused, by the value scan.
for k in clean smudge required; do git config --unset "filter.placeholders.$k"; done
printf '{"autoMode":{"environment":["db at 192.0.2.7"]}}' > "$S"
git add "$S"
expect_fail "with the filter undefined, a raw mapped value is refused at commit" git commit -q -m 'Update settings'
git restore --staged "$S" && cp "$T/settings.good" "$S"
filter_on
[ -z "$(git status --porcelain)" ] && ok "and the tree is clean again" || bad "and the tree is clean again"

# --- pre-push, which is also what sees cherry-picked, rebased and merged
# commits: none of those runs pre-commit.
expect_ok "pre-push passes clean commits" git push -q origin main
before=$(remote_sha main)
git switch -q -c leak
hookless commit -q --allow-empty -m 'Mention zorblax'
expect_fail "pre-push refuses an empty commit whose message names a guarded term" git push -q origin leak:main
[ "$(remote_sha main)" = "$before" ] && ok "and the remote did not move" || bad "and the remote did not move"
git switch -q main
git switch -q -c side
printf 'quuxcorp\n' > side.txt && git add side.txt && hookless commit -q -m 'Add side'
git switch -q main
expect_fail "pre-push refuses another branch, pushed from an up-to-date main" git push -q origin side
[ -z "$(remote_sha side)" ] && ok "and that branch did not reach the remote" ||
	bad "and that branch did not reach the remote"

# Review Focus 5.
expect_fail "without the map, no commit is possible" env PLACEHOLDER_MAP="$T/none" git commit -q --allow-empty -m 'Neutral'

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
```

```sh
chmod +x ~/Backups/claude-consus-sandbox/test-wiring.sh
```

- [ ] **Step 2: Run it to see it fail**

```sh
. ~/Backups/claude-consus.env && "$SB/test-wiring.sh"
```

Expected: `FAIL` lines including at least `lefthook owns commit-msg`,
`lefthook owns pre-push`, `commit-msg refuses a guarded term in the message`,
`the blob holds the placeholder` and `pre-push refuses an empty commit whose
message names a guarded term` — the committed clone has no `.gitattributes`
and a pre-commit-only `lefthook.yml`. Exit 1.

- [ ] **Step 3: Write `.gitattributes`, the two lefthook scripts and `lefthook.yml`**

`.gitattributes`:

```gitattributes
# The private values in settings.json go through bin/placeholders on their way
# into git and back; the filter is per-clone git config (INSTALL.md step 2).
configs/claude/settings.json filter=placeholders
```

`.lefthook/pre-commit/placeholders.sh`:

```sh
#!/bin/sh
# The work-term guard over the staged diff. A lefthook script rather than a
# command: see lefthook.yml.
exec bin/placeholders check-staged
```

`.lefthook/pre-push/placeholders.sh`:

```sh
#!/bin/sh
# The work-term guard over every commit being pushed. lefthook passes the
# remote as $1 and git's ref lines on stdin.
exec bin/placeholders check-push "$1"
```

`lefthook.yml`, replacing the whole file:

```yaml
assert_lefthook_installed: true
# The work-term guard (bin/placeholders) runs as scripts in pre-commit and
# pre-push, from .lefthook/<hook>/placeholders.sh. Measured on 2.1.14: lefthook
# skips a command whose own file list is empty — a typechange-only commit, a
# commit that changes no file, a push of a branch other than HEAD — and a
# skipped guard passes everything. Scripts always run.
pre-commit:
  parallel: true
  commands:
    gitleaks:
      run: |
        command -v gitleaks >/dev/null || { echo "✖ gitleaks not installed — brew install gitleaks"; exit 1; }
        gitleaks git --staged --no-banner --redact -v --config .gitleaks.toml
  scripts:
    placeholders.sh:
      runner: sh
commit-msg:
  commands:
    placeholders:
      run: bin/placeholders check-msg {1}
pre-push:
  scripts:
    placeholders.sh:
      runner: sh
      use_stdin: true
```

Measured on lefthook 2.1.14: `{1}` is `.git/COMMIT_EDITMSG` for `commit-msg`;
a `pre-push` script gets the remote's name as `$1` and the ref lines on stdin
under `use_stdin: true`; a failing command or script blocks the commit or
push; and lefthook chmods a script to 0751 each time it runs it, runner or
not, so both scripts are committed 100755 — as 100644 they would show as a
mode change after their first run.

- [ ] **Step 4: Commit, then configure the filter in this clone**

```sh
cd ~/Developer/LRNZ09/consus
chmod +x .lefthook/pre-commit/placeholders.sh .lefthook/pre-push/placeholders.sh
git add .gitattributes lefthook.yml .lefthook
git commit -F - <<'EOF'
Run the work-term guard in every hook

lefthook now runs bin/placeholders in pre-commit beside gitleaks, in
commit-msg, and in pre-push, so the guard covers every file and every message
in the repo rather than one settings file. pre-push is its backstop, and what
sees cherry-picked, rebased and merged commits: the map is private, so unlike
gitleaks it can never run in CI.

pre-commit and pre-push run it as lefthook scripts, because lefthook skips a
command whose file list is empty, and a skipped guard passes everything.

.gitattributes routes configs/claude/settings.json through the filter. The
filter itself is per-clone git config, so a clone without it stores that file
as it is on disk; bin/doctor will assert it.
EOF
git config filter.placeholders.clean 'bin/placeholders clean'
git config filter.placeholders.smudge 'bin/placeholders smudge'
git config filter.placeholders.required true
lefthook install
```

lefthook sees that `lefthook.yml` changed and re-syncs its hooks during this
commit's `pre-commit`, so the commit already runs the guard and `commit-msg`
against the real map; the `lefthook install` afterwards only confirms it. If
the commit is refused with "private term(s) found", stop: Task 1 missed
something, and the human decides.

- [ ] **Step 5: Run the harness to see it pass**

```sh
. ~/Backups/claude-consus.env && "$SB/test-wiring.sh"
```

Expected: `24 passed, 0 failed`, exit 0.

- [ ] **Step 6: Check the real clone's hooks without committing**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
cd "$CLONE"
for h in pre-commit commit-msg pre-push; do grep -q lefthook ".git/hooks/$h" && echo "✔ $h is lefthook's"; done
m=$(mktemp) && printf 'Neutral message\n' > "$m"
bin/placeholders check-msg "$m" && echo "✔ the real map passes a neutral message"
rm -f "$m"
git log --format=%B "$CONSUS_BASE"..HEAD | bin/placeholders check && echo "✔ this plan's commit messages pass"
```

Expected: five `✔` lines. The sandbox already proved the wiring end to end;
this proves the hooks are installed here and the real map loads.

---

### Task 4: The record

**Files:**

- Create: `configs/claude/AGENTS.md`, `configs/claude/settings.json`,
  `configs/claude/hooks/{pre-bash-memory-grep.sh,pre-bash-prefer-mcp.sh,cli-mcp-map.tsv}`,
  `configs/claude/scripts/statusline.sh`, `configs/claude/README.md`
- Modify: `.gitignore` (append)

**Interfaces:**

- Consumes: Task 3's filter (the clone must have it configured before the
  real `settings.json` is written here).
- Produces: the four link targets Task 6 points at, by these exact paths.

- [ ] **Step 1: Copy the live files, applying the transform to settings.json**

```sh
set -eu
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}"
cd "$CLONE"
[ "$(git config --get filter.placeholders.clean)" = 'bin/placeholders clean' ] || {
	echo "✖ the filter is not configured in this clone — Task 3 Step 4"; exit 1; }
mkdir -p configs/claude/hooks configs/claude/scripts
cp -p "$CH/AGENTS.md" configs/claude/AGENTS.md
cp -p "$CH/hooks/pre-bash-memory-grep.sh" "$CH/hooks/pre-bash-prefer-mcp.sh" \
	"$CH/hooks/cli-mcp-map.tsv" configs/claude/hooks/
cp -p "$CH/statusline-command.sh" configs/claude/scripts/statusline.sh
jq --tab '.statusLine.command = "bash ~/.claude/scripts/statusline.sh"
	| .pluginConfigs["agents-md@builtin"].options.instructionFiles = "claude-md-and-agents-md"' \
	"$CH/settings.json" > configs/claude/settings.json
ls -la "$CH/hooks"
```

Expected: `ls` shows exactly the three hook files. If it shows a fourth, stop:
the spec's record would be incomplete.

- [ ] **Step 2: Append the .gitignore rule**

Append to `.gitignore`:

```gitignore

# Claude Code saves settings.json by temp file and rename next to the link
# target, so a save interrupted mid-write leaves the temp file here. It holds
# the real, unfiltered values, and the filter only applies to settings.json:
# it must never be stageable.
/configs/claude/*.tmp.*
```

- [ ] **Step 3: Write `configs/claude/README.md`**

````markdown
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

## Global instructions

Nothing imports `AGENTS.md`: there is no `~/.claude/CLAUDE.md`. Claude Code
reads `AGENTS.md` itself from 2.1.277, and only as a project file — the upward
walk from any directory under `$HOME` reaches `$HOME/.claude/AGENTS.md`.
`settings.json` sets `pluginConfigs."agents-md@builtin".options.instructionFiles`
to `claude-md-and-agents-md` so that repos with their own `CLAUDE.md` still load
it. Sessions started outside `$HOME` do not, and neither do subagents that skip
project instructions.

## Private values

Some values in `settings.json`, all of them under `autoMode`, are private. Git
stores `<placeholder>` tokens instead; the file on disk keeps the real values.
`bin/placeholders` swaps them as a git filter using the untracked map
`~/.claude/placeholders.tsv`, and stores the file in one canonical layout:
sorted keys, tabs.

- **Add a map row before staging a new private value** — including one that
  `/permissions` or `/auto-mode-setup` wrote. Until the row exists, `git add`
  and even `git diff` on `settings.json` fail with "private term(s) found".
  Map it rather than `git restore` the file: the restore would silently throw
  the new entry away.
- **After Claude Code saves `settings.json`, `git status` may list it while
  `git diff` is empty.** Claude Code re-serializes the file on every save, and
  the canonical layout makes what git stores identical. `git add` clears it.
- **The map is the only copy of the real values.** Keep an off-machine backup
  of it. Without it, nothing in this repo can be committed — every guard fails
  closed.
- **Commit with the git CLI**, or a client that runs it, as VS Code's does.
  libgit2-based clients skip external filters and hooks.

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
````

- [ ] **Step 4: Stage, and check what git stores**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
cd "$CLONE"
git add .gitignore configs/claude
git show :configs/claude/settings.json | bin/placeholders check && echo "✔ the stored settings name no private term"
git show :configs/claude/settings.json | bin/placeholders smudge | cmp -s - <(jq -j -S --tab . configs/claude/settings.json) &&
	echo "✔ smudging the stored settings gives back the file on disk"
[ -z "$(git diff)" ] && echo "✔ nothing unstaged"
jq -e '.statusLine.command == "bash ~/.claude/scripts/statusline.sh"
	and .pluginConfigs["agents-md@builtin"].options.instructionFiles == "claude-md-and-agents-md"' \
	configs/claude/settings.json >/dev/null && echo "✔ the transform applied"
for f in AGENTS.md hooks/pre-bash-memory-grep.sh hooks/pre-bash-prefer-mcp.sh hooks/cli-mcp-map.tsv; do
	cmp -s "$CH/$f" "configs/claude/$f" && echo "✔ $f is identical"
done
cmp -s "$CH/statusline-command.sh" configs/claude/scripts/statusline.sh && echo "✔ statusline.sh is identical"
git check-ignore -q configs/claude/settings.json.tmp.1234.abcdef && echo "✔ a temp file is ignored"
git check-ignore -q configs/claude/settings.json || echo "✔ settings.json itself is not"
git ls-files --stage configs/claude/hooks configs/claude/scripts | awk '{print $1, $4}'
```

Expected: eleven `✔` lines, and the last command showing `100755` for the two
hook scripts and `100644` for `cli-mcp-map.tsv` and `statusline.sh` — the
status line is run as `bash …`, so it was never executable and need not be.

- [ ] **Step 5: Commit**

```sh
cd ~/Developer/LRNZ09/consus
git commit -F - <<'EOF'
Track the claude record

configs/claude/ is the hand-written part of ~/.claude, copied from the
dotclaude checkout: settings.json, the global AGENTS.md, the two PreToolUse
hooks and the status-line script, which moves into scripts/ as statusline.sh.
settings.json goes through the placeholders filter, so git stores
placeholders while the file on disk keeps the real values.

Two settings change. statusLine follows the script to scripts/, and
instructionFiles is claude-md-and-agents-md, because CLAUDE.md is dropped and
AGENTS.md now loads as a project file that any repo's own CLAUDE.md would
otherwise suppress.

.gitignore keeps an interrupted save's temp file out: Claude Code writes it
next to the link target, here, with the real values unfiltered.
EOF
```

If the commit is refused with "private term(s) found", stop: the human decides
whether to map, narrow or change the line. The executor edits neither the map
nor the record.

---

### Task 5: Teach doctor the claude links, the filter and the map

**Files:**

- Modify: `bin/doctor.bats` — header comment, `setup_file`, the lefthook test,
  seven new tests after the agents lock test, the "Advisories" comment, one
  advisory in `teardown_file`
- Test: `$SB/test-doctor.sh` (not committed)

**Interfaces:**

- Consumes: Task 3's config keys; Task 4's four target paths; Task 2's map
  default.
- Produces: `CLAUDE_HOME` and `PLACEHOLDER_MAP` exported from `setup_file`,
  and seven test names: `~/.claude/settings.json links into this clone`,
  `~/.claude/AGENTS.md links into this clone`, `~/.claude/hooks links into
  this clone`, `~/.claude/scripts links into this clone`, `claude is 2.1.277
  or later`, `the placeholders filter is configured in this clone`, `the
  placeholder map is readable`. bats prints the first four with the leading
  `~` expanded to `$HOME`.

- [ ] **Step 1: Write the harness**

Write `$SB/test-doctor.sh`:

```bash
#!/usr/bin/env bash
# claude-into-consus sandbox: the new doctor tests against a throwaway clone
# and a throwaway CLAUDE_CONFIG_DIR. Never reads the real map.
set -uo pipefail
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${SB:?}"
T=$(mktemp -d "$SB/doctor.XXXXXX")
trap 'rm -rf "$T"' EXIT
git clone -q "$CLONE" "$T/clone"
C=$T/clone H=$T/home
# The working doctor.bats, not the committed one: this runs before the commit.
cp "$CLONE/bin/doctor.bats" "$C/bin/doctor.bats"
mkdir -p "$H" "$T/bin"
printf '%s\n' "guard	zorblax" > "$T/map.tsv"
BATS=$(command -v bats)

pass=0 failed=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf 'FAIL %s\n' "$1"; }
doc() {
	CLAUDE_CONFIG_DIR="$H" PLACEHOLDER_MAP="${MAP:-$T/map.tsv}" PATH="$T/bin:$PATH" \
		"$BATS" --print-output-on-failure --filter "$1" "$C/bin/doctor.bats" 2>&1
}
# Measured on bats 1.14.0: a filter that matches no test exits 1 with "ERROR:
# Found no tests." — which must never read as the expected failure.
ran() { ! printf '%s\n' "$1" | grep -qE 'Found no tests|^1\.\.0$'; }
show() { printf '%s\n' "$1" | sed 's/^/    /'; }
# passes NAME FILTER / fails NAME FILTER [text the output must contain]
passes() {
	local out rc
	out=$(doc "$2"); rc=$?
	[ "$rc" -eq 0 ] && ran "$out" && ok "$1" || { bad "$1"; show "$out"; }
}
fails() {
	local out rc
	out=$(doc "$2"); rc=$?
	[ "$rc" -ne 0 ] && ran "$out" && { [ -z "${3:-}" ] || printf '%s' "$out" | grep -qF -- "$3"; } &&
		ok "$1" || { bad "$1"; show "$out"; }
}
cfg() { (cd "$C" && git config "$@"); }
link_all() {
	ln -sfn "$C/configs/claude/settings.json" "$H/settings.json"
	ln -sfn "$C/configs/claude/AGENTS.md" "$H/AGENTS.md"
	ln -sfn "$C/configs/claude/hooks" "$H/hooks"
	ln -sfn "$C/configs/claude/scripts" "$H/scripts"
}
fake_claude() { printf '#!/bin/sh\necho "%s (Claude Code)"\n' "$1" > "$T/bin/claude"; chmod +x "$T/bin/claude"; }
# bats expands the leading ~ of a test name, so filter on the rest of it.
LINKS='/\.claude/[^ ]+ links into this clone'

link_all
out=$(doc "$LINKS"); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx '1\.\.4' && ok "four healthy links pass" ||
	{ bad "four healthy links pass"; show "$out"; }

mv "$C/configs/claude/settings.json" "$T/settings.aside"
fails "a dangling settings.json link fails" 'settings\.json links' "the target does not exist"
mv "$T/settings.aside" "$C/configs/claude/settings.json"

rm "$H/settings.json" && printf '{}' > "$H/settings.json"
fails "a regular settings.json fails" 'settings\.json links' "is not a symlink"
link_all

ln -sfn "$T" "$H/hooks"
fails "hooks linked elsewhere fails" 'hooks links' "(expected -> $C/configs/claude/hooks)"
link_all

rm "$H/scripts"
fails "a missing scripts link fails" 'scripts links' "is not a symlink"
link_all

fake_claude 2.1.276; fails "claude 2.1.276 fails" 'claude is' "below 2.1.277"
fake_claude 2.1.277; passes "claude 2.1.277 passes" 'claude is'
fake_claude 2.1.281; passes "claude 2.1.281 passes" 'claude is'
fake_claude 2.2.0; passes "claude 2.2.0 passes" 'claude is'

fails "an undefined filter fails" 'filter is configured' "filter.placeholders.clean"
cfg filter.placeholders.clean 'bin/placeholders clean'
cfg filter.placeholders.smudge 'bin/placeholders smudge'
cfg filter.placeholders.required true
passes "a configured filter passes" 'filter is configured'
cfg filter.placeholders.required false
fails "a filter that is not required fails" 'filter is configured' "filter.placeholders.required"
cfg filter.placeholders.required true

MAP="$T/none" fails "a missing map fails" 'map is readable' "missing or unreadable"
printf 'x\t<y>\n' > "$T/noguard.tsv"
MAP="$T/noguard.tsv" fails "a map without a guard row fails" 'map is readable' "no guard row"
passes "a readable map with a guard row passes" 'map is readable'

fails "a clone without lefthook's hooks fails" "lefthook's hooks" "commit-msg is not lefthook's"
(cd "$C" && lefthook install >/dev/null 2>&1)
passes "a clone with all three passes" "lefthook's hooks"

mkdir "$H/.git"
out=$(doc 'placeholder map')
printf '%s\n' "$out" | grep -qF "note: $H/.git exists" && ok "a leftover checkout prints the advisory" ||
	bad "a leftover checkout prints the advisory"

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
```

```sh
chmod +x ~/Backups/claude-consus-sandbox/test-doctor.sh
```

- [ ] **Step 2: Run it to see it fail**

```sh
. ~/Backups/claude-consus.env && "$SB/test-doctor.sh"
```

Expected: 17 `FAIL` lines — no test the harness filters for exists yet, and an
empty run counts as neither a pass nor a failure — and one `ok`, `a clone with
all three passes`, which today's pre-commit-only lefthook test also passes.
`1 passed, 17 failed`, exit 1.

- [ ] **Step 3: Edit `bin/doctor.bats` — the header comment**

Replace:

```bash
# Link integrity is the one invariant git cannot express — the repo can be
# pristine while $XDG_CONFIG_HOME points somewhere else, and for git, fish and
# proto a severed link is completely silent. For agents a dangling one is
# worse than silent: see the agents link test. Since the links are now made by
# hand (INSTALL.md), the two things the old installer did quietly — the clone's
# mode and lefthook's hooks — are asserted here too.
```

with:

```bash
# Link integrity is the one invariant git cannot express — the repo can be
# pristine while $XDG_CONFIG_HOME points somewhere else, and for git, fish and
# proto a severed link is completely silent. For agents and for claude's
# settings.json a dangling one is worse than silent: see their link tests.
# Since the links are now made by hand (INSTALL.md), the two things the old
# installer did quietly — the clone's mode and lefthook's hooks — are asserted
# here too, and so is the placeholders filter, which is per-clone git config.
```

- [ ] **Step 4: `setup_file`**

Replace:

```bash
	AGENTS_ROOT="${DOTAGENTS_HOME:-$HOME/.agents}"
	export REPO CONFIG_HOME RECORD PROTO_STORE AGENTS_ROOT
	echo "# repo: $REPO" >&3
	echo "# proto store: $PROTO_STORE" >&3
	echo "# agents root: $AGENTS_ROOT" >&3
```

with:

```bash
	AGENTS_ROOT="${DOTAGENTS_HOME:-$HOME/.agents}"
	# Claude Code's own lookup. Its record is four links rather than one
	# directory link: CLAUDE_CONFIG_DIR relocates sessions, transcripts and
	# plugins along with the settings — 4 GB that must stay out of this repo.
	CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
	# bin/placeholders' own default, with the same override.
	PLACEHOLDER_MAP="${PLACEHOLDER_MAP:-$HOME/.claude/placeholders.tsv}"
	export REPO CONFIG_HOME RECORD PROTO_STORE AGENTS_ROOT CLAUDE_HOME PLACEHOLDER_MAP
	echo "# repo: $REPO" >&3
	echo "# proto store: $PROTO_STORE" >&3
	echo "# agents root: $AGENTS_ROOT" >&3
	echo "# claude home: $CLAUDE_HOME" >&3
```

- [ ] **Step 5: The lefthook test**

Replace:

```bash
@test "lefthook's hooks are installed in this clone" {
	grep -q lefthook "$REPO/.git/hooks/pre-commit" 2>/dev/null || {
		echo "run: cd $REPO && lefthook install"
		echo "without them gitleaks does not see a commit until it is pushed"
		return 1
	}
}
```

with:

```bash
@test "lefthook's hooks are installed in this clone" {
	# All three, not only pre-commit: lefthook install writes just the hooks
	# lefthook.yml lists, so a clone installed before the work-term guard has a
	# pre-commit hook and neither of the other two.
	local hook missing=0
	for hook in pre-commit commit-msg pre-push; do
		grep -q lefthook "$REPO/.git/hooks/$hook" 2>/dev/null || {
			echo "$hook is not lefthook's"
			missing=1
		}
	done
	[ "$missing" -eq 0 ] || {
		echo "run: cd $REPO && lefthook install"
		echo "without them gitleaks does not see a commit until it is pushed, and"
		echo "the work-term guard, which never runs in CI, does not see it at all"
		return 1
	}
}
```

- [ ] **Step 6: The seven new tests**

Insert immediately before the line `# Advisories. Deliberately not assertions:
neither is a broken machine, and the`:

```bash
@test "~/.claude/settings.json links into this clone" {
	# The worst dangling case in the repo. Claude Code saves by temp file and
	# rename on the link target, so the link survives every save — but measured
	# on 2.1.273, with the target gone it reads empty settings in silence (no
	# permission rule, hook or autoMode entry), and its next save writes a
	# settings.json holding only that one change into configs/claude/.
	# git restore it, then look for anything saved in between.
	assert_link "$CLAUDE_HOME/settings.json" "$RECORD/claude/settings.json"
}

@test "~/.claude/AGENTS.md links into this clone" {
	# Severed, the global instructions are simply absent from every session.
	assert_link "$CLAUDE_HOME/AGENTS.md" "$RECORD/claude/AGENTS.md"
}

@test "~/.claude/hooks links into this clone" {
	# Severed, the two PreToolUse hooks stop injecting their context. Neither
	# ever blocks a call, so nothing else says so.
	assert_link "$CLAUDE_HOME/hooks" "$RECORD/claude/hooks"
}

@test "~/.claude/scripts links into this clone" {
	# Severed, the status line disappears.
	assert_link "$CLAUDE_HOME/scripts" "$RECORD/claude/scripts"
}

@test "claude is 2.1.277 or later" {
	command -v claude >/dev/null 2>&1 || skip "claude is not installed"
	# Below 2.1.277 Claude Code reads no AGENTS.md at all, and nothing here
	# gives it a CLAUDE.md, so terminal sessions run without the global
	# instructions. The stable cask was 2.1.273 on 2026-09-24: this fails on
	# purpose until stable catches up. The VS Code extension bundles its own
	# binary, which this does not ask about.
	local v
	v=$(claude --version 2>/dev/null | awk '{ print $1 }')
	[ -n "$v" ] || {
		echo "claude --version printed nothing"
		return 1
	}
	printf '%s\n%s\n' 2.1.277 "$v" | sort -V -C || {
		echo "claude is $v, below 2.1.277: terminal sessions load no AGENTS.md"
		return 1
	}
}

@test "the placeholders filter is configured in this clone" {
	# .gitattributes names the filter; this clone's git config defines it.
	# Undefined, git stores configs/claude/settings.json exactly as it is on
	# disk — real values included — and filter.placeholders.required only
	# applies once the filter is defined.
	local key got bad=0
	for key in clean smudge; do
		got=$(git -C "$REPO" config --get "filter.placeholders.$key" || true)
		[ "$got" = "bin/placeholders $key" ] || {
			echo "filter.placeholders.$key is '$got' (expected 'bin/placeholders $key')"
			bad=1
		}
	done
	got=$(git -C "$REPO" config --type=bool --get filter.placeholders.required || true)
	[ "$got" = true ] || {
		echo "filter.placeholders.required is '$got' (expected true)"
		bad=1
	}
	[ "$bad" -eq 0 ] || {
		echo "run the three git config filter.placeholders lines of INSTALL.md step 2 —"
		echo "not the step's last line, which is for a fresh clone only"
		return 1
	}
}

@test "the placeholder map is readable" {
	# Without it every guard fails closed and nothing can be committed; this
	# names the file before a commit does. It is untracked and exists nowhere
	# else on this machine.
	[ -r "$PLACEHOLDER_MAP" ] || {
		echo "$PLACEHOLDER_MAP is missing or unreadable — restore it from backup"
		return 1
	}
	grep -q "^guard$(printf '\t')" "$PLACEHOLDER_MAP" || {
		echo "$PLACEHOLDER_MAP has no guard row, so every guard refuses everything"
		return 1
	}
}

```

- [ ] **Step 7: The "Advisories" comment and the advisory**

Replace `# Advisories. Deliberately not assertions: neither is a broken machine,
and the` with `# Advisories. Deliberately not assertions: none is a broken
machine, and the` — the line's wrap is unchanged. Then, in `teardown_file`,
after the block that ends with the `$AGENTS_ROOT/.git` note and before the
function's closing `}`, insert:

```bash
	# The same for the retired dotclaude checkout, which still tracks
	# settings.json, AGENTS.md and hooks/ at the paths the links now occupy.
	if [ -e "$CLAUDE_HOME/.git" ]; then
		echo "# note: $CLAUDE_HOME/.git exists — a checkout there restores" >&3
		echo "#       regular files over three of the four links." >&3
	fi
```

- [ ] **Step 8: Run the harness against the edited file**

```sh
. ~/Backups/claude-consus.env
cd "$CLONE" && bats --count bin/doctor.bats
"$SB/test-doctor.sh"
```

Expected: `bats --count` prints `18` (11 before, 7 added), and the harness ends
`18 passed, 0 failed`, exit 0.

- [ ] **Step 9: Run doctor on the machine**

```sh
cd ~/Developer/LRNZ09/consus && ./bin/doctor; echo "rc=$?"
```

Expected: `not ok` for exactly the four `$HOME/.claude/… links into this
clone` tests (the links do not exist yet; bats prints the `~` expanded) and
`claude is 2.1.277 or later`; `ok` for the filter, the map, lefthook and
everything that passed before; `rc=1`. Two notes follow the tests, and neither
is a failure: `bin/doctor.bats` listed as uncommitted (Step 10 commits it),
and `$HOME/.claude/.git exists` (Task 6 Step 3 retires the checkout).

- [ ] **Step 10: Commit**

```sh
cd ~/Developer/LRNZ09/consus
git add bin/doctor.bats
git commit -F - <<'EOF'
Teach doctor the claude links, the filter and the map

Four link tests, one per path Claude Code reads the record from. The
settings.json one carries the worst dangling case in the repo, measured on
2.1.273: empty settings read in silence, then a near-empty record written
here by the next save.

claude must be 2.1.277 or later, since nothing gives it a CLAUDE.md any more;
it fails today on purpose, on the stable cask's 2.1.273. The filter test exists
because an undefined filter stores settings.json raw, and the map test because
without the map no commit is possible. The lefthook test now wants commit-msg
and pre-push as well. A leftover ~/.claude/.git prints as a note.

Verified: 18 throwaway-home cases, each behaving as intended.
EOF
```

---

### Task 6: Activate

The only task that changes `~/.claude`'s configuration. Task 5's sandbox run
must have passed. Every step from Step 3 on is safe to re-run, and the rollback
applies from Step 3 on.

**Files:** `~/.claude/*` (machine), `$BK` (backups), possibly
`configs/claude/settings.json` and `configs/claude/AGENTS.md` (drift).

**Interfaces:**

- Consumes: Task 4's targets; Task 5's doctor.
- Produces: the four links; `DOTCLAUDE_HEAD` appended to the state file.

- [ ] **Step 1: Preconditions, then dotclaude's pointer commit**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}"
cd "$CLONE"
[ -z "$(git status --porcelain)" ] || { echo "✖ consus has uncommitted changes"; exit 1; }
# Nothing is retired until the live settings are known to be stageable.
bin/placeholders clean < "$CH/settings.json" >/dev/null ||
	{ echo "✖ the live settings.json cannot be staged — the human maps the term first"; exit 1; }
cd "$CH"
cat > README.md <<'EOF'
# dotclaude (archived)

Since 2026-09-24 the hand-written part of `~/.claude` lives in
[consus](https://github.com/LRNZ09/consus) under `configs/claude/`, reached
through links at Claude Code's own paths. The design is
`docs/superpowers/specs/2026-09-24-claude-into-consus-design.md` there.

The files here are a snapshot of the last state this repository tracked. Do not
clone it into `~/.claude`: a checkout there would put regular files back over
the links.
EOF
git add README.md
git commit -F - <<'EOF'
Point to consus, where this record now lives

The tracked files stay as a snapshot; the README says where they went and why a
checkout into ~/.claude must not happen again.
EOF
git show --stat HEAD
```

Expected: one file changed, `README.md`; the commit passed dotclaude's
pre-commit and commit-msg guards (its pre-push guard runs at Step 2's push).
`settings.json` stays modified and uncommitted — its change travels with the
live file into consus.

- [ ] **Step 2: STOP — show the human the commit and push only on an explicit yes**

Show the output of `git show HEAD` in `~/.claude` and ask: "Push this pointer
commit to LRNZ09/dotclaude?" On yes:

```sh
set -eu
. ~/Backups/claude-consus.env
: "${CH:?}"
cd "$CH"
git push origin main
[ "$(git ls-remote origin refs/heads/main | cut -f1)" = "$(git rev-parse HEAD)" ] ||
	{ echo "✖ origin/main is not the pointer commit"; exit 1; }
echo "DOTCLAUDE_HEAD=$(git rev-parse HEAD)" >> ~/Backups/claude-consus.env
```

Expected: the push passes dotclaude's pre-push guard, and the state file gains
`DOTCLAUDE_HEAD` only if the remote holds the commit.

- [ ] **Step 3: Back up, and retire the checkout**

```sh
set -eu
. ~/Backups/claude-consus.env
: "${CH:?}" "${BK:?}" "${DOTCLAUDE_HEAD:?}"
if [ ! -e "$BK" ]; then
	(cd "$CH" && [ "$(git ls-remote origin refs/heads/main | cut -f1)" = "$DOTCLAUDE_HEAD" ]) ||
		{ echo "✖ dotclaude's remote does not hold the pointer commit"; exit 1; }
	mkdir -m 700 "$BK"
	# settings.json and AGENTS.md are replaced by a rename in Step 5, so these
	# copies are the only record of what they held before the migration.
	# Written once, here, and never overwritten.
	cp -p "$CH/settings.json" "$CH/AGENTS.md" "$BK/"
fi
for p in .git .gitignore README.md CLAUDE.md; do
	[ -e "$CH/$p" ] || continue
	[ ! -e "$BK/$p" ] || { echo "✖ $BK/$p exists — move $CH/$p aside by hand, never over it"; exit 1; }
	mv "$CH/$p" "$BK/"
done
(cd "$CH" && git rev-parse --show-toplevel >/dev/null 2>&1) && { echo "✖ ~/.claude is still inside a repo"; exit 1; }
ls -la "$BK"
```

Expected: `$BK` holds `.git`, `.gitignore`, `README.md`, `CLAUDE.md`,
`settings.json`, `AGENTS.md`; the last check prints nothing.

- [ ] **Step 4: Re-derive the record from the live files**

Review Focus 1: anything Claude Code saved since Task 4 is carried here. Only
paths that are still regular files are read, so re-running this after Step 5
changes nothing.

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}"
cd "$CLONE"
R=configs/claude
# Re-deriving overwrites the record, and after a rollback the record holds
# whatever was saved through its link. Never over an uncommitted change.
for f in settings.json AGENTS.md; do
	[ -L "$CH/$f" ] || git diff --quiet HEAD -- "$R/$f" || {
		echo "✖ $R/$f has uncommitted changes. If an earlier run of this step wrote them, commit them (below) first;"
		echo "  after a rollback, carry what is wanted into $CH/$f, then commit or git restore $R/$f"
		exit 1
	}
done
[ -L "$CH/settings.json" ] || jq --tab '.statusLine.command = "bash ~/.claude/scripts/statusline.sh"
	| .pluginConfigs["agents-md@builtin"].options.instructionFiles = "claude-md-and-agents-md"' \
	"$CH/settings.json" > "$R/settings.json"
[ -L "$CH/AGENTS.md" ] || cp -p "$CH/AGENTS.md" "$R/AGENTS.md"
[ -L "$CH/hooks" ] || diff -r "$CH/hooks" "$R/hooks"
[ ! -e "$CH/statusline-command.sh" ] || cmp "$CH/statusline-command.sh" "$R/scripts/statusline.sh"
git status --short "$R"
```

Expected: no `diff` or `cmp` output. `git status` lists nothing, or
`settings.json` / `AGENTS.md` if something was saved since Task 4. In that case
check `git diff configs/claude` shows only that saved change, and commit it:

```sh
cd ~/Developer/LRNZ09/consus
git add configs/claude/settings.json configs/claude/AGENTS.md configs/claude/hooks configs/claude/scripts
git commit -F - <<'EOF'
Carry the settings saved since the record was taken

What Claude Code saved to the old ~/.claude/settings.json between tracking the
record and linking it, so nothing is lost across the swap.
EOF
```

If `diff -r` or `cmp` reported a change, copy the live file over the record's
(`cp -p "$CH/hooks/<file>" configs/claude/hooks/`, or
`cp -p "$CH/statusline-command.sh" configs/claude/scripts/statusline.sh`),
re-run this step, and commit: the `git add` includes both directories. If the
commit is refused with "private term(s) found", stop: the human maps it.

- [ ] **Step 5: The links**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
: "${CLONE:?}" "${CH:?}" "${BK:?}"
R="$CLONE/configs/claude"
derive() {
	jq --tab '.statusLine.command = "bash ~/.claude/scripts/statusline.sh"
		| .pluginConfigs["agents-md@builtin"].options.instructionFiles = "claude-md-and-agents-md"' \
		"$CH/settings.json"
}
# hooks/ and the status line are not compared at their swap, as the files
# are: only a hand edit changes them. Both are checked before anything moves.
[ -L "$CH/hooks" ] || [ ! -e "$CH/hooks" ] || diff -rq "$CH/hooks" "$R/hooks" >/dev/null ||
	{ echo "✖ hooks/ changed since Step 4 — re-run Step 4"; exit 1; }
[ ! -e "$CH/statusline-command.sh" ] || cmp -s "$CH/statusline-command.sh" "$R/scripts/statusline.sh" ||
	{ echo "✖ statusline-command.sh changed since Step 4 — re-run Step 4"; exit 1; }
# scripts/ first: the new settings name it, and nothing is displaced.
[ -L "$CH/scripts" ] || ln -s "$R/scripts" "$CH/scripts"
# A directory cannot be renamed over atomically — measured, `mv -f link dir`
# moves the link INTO the directory — so hooks takes a brief gap. Harmless:
# neither hook ever blocks a call. A run interrupted inside the gap leaves
# ~/.claude/hooks missing; the next run links it.
if [ ! -L "$CH/hooks" ]; then
	if [ -e "$CH/hooks" ]; then
		[ ! -e "$BK/hooks" ] || { echo "✖ $BK/hooks exists — see Rollback"; exit 1; }
		mv "$CH/hooks" "$BK/hooks"
	fi
	ln -s "$R/hooks" "$CH/hooks"
fi
# Files go in by one rename(2) each, so no reader ever sees them missing:
# running sessions watch settings.json, and a missing file reads as empty
# settings, which a save would then write into the record. Each is compared
# with the record immediately before its rename; a difference means a save
# landed since Step 4.
if [ ! -L "$CH/AGENTS.md" ]; then
	cmp -s "$CH/AGENTS.md" "$R/AGENTS.md" || { echo "✖ AGENTS.md changed since Step 4 — re-run Step 4"; exit 1; }
	[ ! -L "$CH/AGENTS.md.consus-link" ] || rm "$CH/AGENTS.md.consus-link"
	ln -s "$R/AGENTS.md" "$CH/AGENTS.md.consus-link" && mv -f "$CH/AGENTS.md.consus-link" "$CH/AGENTS.md"
fi
if [ ! -L "$CH/settings.json" ]; then
	derive | cmp -s - "$R/settings.json" || { echo "✖ settings.json changed since Step 4 — re-run Step 4"; exit 1; }
	[ ! -L "$CH/settings.json.consus-link" ] || rm "$CH/settings.json.consus-link"
	ln -s "$R/settings.json" "$CH/settings.json.consus-link" && mv -f "$CH/settings.json.consus-link" "$CH/settings.json"
fi
if [ -e "$CH/statusline-command.sh" ]; then
	[ ! -e "$BK/statusline-command.sh" ] ||
		{ echo "✖ $BK/statusline-command.sh exists — move $CH/statusline-command.sh aside by hand, never over it"; exit 1; }
	mv "$CH/statusline-command.sh" "$BK/"
fi
ls -la "$CH" | grep -E ' (settings\.json|AGENTS\.md|hooks|scripts|CLAUDE\.md|statusline-command\.sh)( |$)'
```

Expected: four `->` lines pointing into `configs/claude/`, and no `CLAUDE.md`
or `statusline-command.sh` line. On "re-run Step 4": run Step 4 (commit its
drift), then this step again.

- [ ] **Step 6: Run doctor**

```sh
cd ~/Developer/LRNZ09/consus && ./bin/doctor > ~/Backups/claude-consus-sandbox/doctor-after.txt 2>&1; true
grep -c '^not ok' ~/Backups/claude-consus-sandbox/doctor-after.txt
grep '^not ok' ~/Backups/claude-consus-sandbox/doctor-after.txt
```

Expected: `1`, and that one line is `not ok … claude is 2.1.277 or later`. Any
other failure: stop and run the rollback.

- [ ] **Step 7: Tell the human to restart their Claude Code sessions**

Running sessions read settings through the old regular file's watcher. New
sessions read through the links. No commit in this step.

---

### Task 7: Verify, live

Changes nothing. Every check is a command with an exit code.

- [ ] **Step 1: The settings Claude Code actually uses**

```sh
set -euo pipefail
. ~/Backups/claude-consus.env
S="$CLONE/configs/claude/settings.json"
for k in $(jq -r '.autoMode | keys[]' "$S"); do
	claude auto-mode config 2>/dev/null | jq -e --slurpfile s "$S" --arg k "$k" '
		. as $eff | (($s[0].autoMode[$k] // []) - ["$defaults"])
		| all(.[]; . as $e | $eff[$k] | any(.[]; . == $e))' >/dev/null && echo "✔ autoMode.$k in effect"
done
```

Expected: one `✔` per `autoMode` key in the record — `allow`, `environment`
and `soft_deny` today. The check compares without printing a value.

- [ ] **Step 2: The status line and a hook**

```sh
set -euo pipefail
printf '{"cwd":"%s","model":{"display_name":"probe"}}' "$HOME" |
	bash ~/.claude/scripts/statusline.sh | grep -q probe && echo "✔ the status line draws"
printf '{"tool_input":{"command":"git status --short"},"cwd":"%s"}' "$HOME/Developer/LRNZ09/consus" |
	~/.claude/hooks/pre-bash-memory-grep.sh |
	jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null && echo "✔ the memory-grep hook injects context"
```

Expected: both `✔` lines.

- [ ] **Step 3: AGENTS.md loads without CLAUDE.md**

Use the VS Code extension's bundled binary, which is new enough, from a
directory with its own `CLAUDE.md` and from `$HOME`:

```sh
set -eu
. ~/Backups/claude-consus.env
EXT=$(ls -d ~/.vscode/extensions/anthropic.claude-code-*-darwin-arm64 | sort -V | tail -1)/resources/native-binary/claude
"$EXT" --version
mkdir -p "$SB/with-claude-md" && printf '# probe project\n' > "$SB/with-claude-md/CLAUDE.md"
Q='Your instructions include a rule about which output flag to pass to the twg CLI. Reply with only that flag, or NONE if you have no such instruction.'
(cd "$SB/with-claude-md" && "$EXT" -p "$Q")
(cd "$HOME" && "$EXT" -p "$Q")
```

Expected: a version ≥ 2.1.281, then `-o json` twice. Optional, to confirm the
accepted gaps rather than to gate on them: the same question from `/private/tmp`,
or through the terminal `claude` (2.1.273), answers `NONE`.

- [ ] **Step 4: The record is clean**

```sh
. ~/Backups/claude-consus.env
cd "$CLONE" && git status --short && git log --oneline "$CONSUS_BASE"..HEAD
```

Expected: no status lines — a `settings.json` line with an empty `git diff` is
the documented re-serialization, cleared by `git add` — and the commits this
plan made.

---

### Task 8: Documentation

**Files:**

- Modify: `README.md`, `INSTALL.md`, `configs/claude/README.md` (only if Step
  11's lint says so),
  `docs/superpowers/specs/2026-08-21-consus-migration-design.md`,
  `docs/superpowers/specs/2026-09-24-claude-into-consus-design.md`

- [ ] **Step 1: README.md — the link table and the paragraph after it**

Replace:

````markdown
```text
~/.config/git          →  <this clone>/configs/git
~/.config/fish         →  <this clone>/configs/fish
~/.proto/.prototools   →  <this clone>/configs/proto/.prototools
~/.agents/agents.toml  →  <this clone>/configs/agents/agents.toml
```

proto and agents are the two tools whose paths are not under `~/.config`,
because neither proto nor dotagents reads `XDG_CONFIG_HOME`, and the two
whose links are on a file rather than a directory: proto's 2.3 GB store and
dotagents' installed skills are the directories.
````

with:

````markdown
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
````

- [ ] **Step 2: README.md — "What is here"**

After the `configs/agents` bullet (the one ending "directory's README says
why, and what not to run there."), insert:

```markdown
- **configs/claude** — `settings.json`, the global `AGENTS.md`, two hooks and
  the status-line script. Everything else in `~/.claude` stays there. Git
  stores placeholders for the private values in `settings.json`; the
  directory's README says how, and what not to do there.
```

- [ ] **Step 3: README.md — "A fresh machine"**

Replace:

```markdown
The commands are in [INSTALL.md](INSTALL.md): the prerequisites, `chmod 700`
and `lefthook install`, the four links and the ghostty include, the
toolchains, fisher, the skills, and `bin/doctor` to verify. Seven steps, run
once per machine.
```

with:

```markdown
The commands are in [INSTALL.md](INSTALL.md): the prerequisites, `chmod 700`,
`lefthook install` and the placeholders filter, the eight links and the
ghostty include, the toolchains, fisher, the skills, and `bin/doctor` to
verify. Seven steps, run once per machine.
```

- [ ] **Step 4: README.md — "Per-machine settings"**

After the `proto` bullet (the one ending "proto uses when no project pin
applies."), insert:

```markdown
- **claude** — `~/.claude/placeholders.tsv`, the map from each private value
  to the placeholder git stores instead. It is untracked and nothing in this
  repo restores it, so it needs an off-machine backup: without it
  `settings.json` cannot be staged and the guards refuse every commit.
  `~/.claude/settings.local.json` and everything else in `~/.claude` stay
  machine-local.
```

- [ ] **Step 5: README.md — "The hazard of a linked directory"**

After the proto paragraph (the one ending `` That is what `bin/doctor`
catches. ``), insert:

```markdown
claude has both kinds. `~/.claude/hooks` and `~/.claude/scripts` are directory
links, so `rm -rf ~/.claude/hooks/` empties `configs/claude/hooks/` — though
`git restore` recovers all of it, since nothing untracked lives there. The
`settings.json` link is the one that hurts to lose: with its target gone,
Claude Code reads empty settings without a word, and its next save writes a
`settings.json` holding only that one change into `configs/claude/`.
`bin/doctor` catches the dangling link; `git restore` undoes the rest.
```

- [ ] **Step 6: README.md — "Secret scanning"**

After the existing paragraph (its last line is `flags any committed email
address that is not a GitHub noreply.`), insert:

```markdown
A second guard keeps work terms out, and it covers every file and every commit
message, not only `settings.json`. `bin/placeholders` runs in lefthook's
`pre-commit`, `commit-msg` and `pre-push` hooks against the untracked map, and
fails closed: without the map nothing can be committed. Cherry-pick, rebase,
am and merge run no `pre-commit`, so `pre-push` is what sees their commits.
`bin/placeholders` is also the git filter that swaps each private value in
`configs/claude/settings.json` for its placeholder on the way into git and back
on checkout; `.gitattributes` names the file, and the filter itself is
per-clone git config (INSTALL.md step 2). Unlike gitleaks it cannot run in CI —
the map is private — so `pre-push` is its backstop.
```

- [ ] **Step 7: INSTALL.md — step 1's prose, step 2 and step 3**

In step 1, replace:

```markdown
   `bats-core` is what `bin/doctor` runs on; `jq` is what it reads proto's
   manifests with. Both are in the [brewfile][brewfile] too, so a machine built
   from that already has them.
```

with:

```markdown
   `bats-core` is what `bin/doctor` runs on; `jq` is what it reads proto's
   manifests with, and what `bin/placeholders` rewrites `settings.json` with.
   Both are in the [brewfile][brewfile] too, so a machine built from that
   already has them.
```

Replace step 2 (from `2. The repo's own two settings.` through its closing
code fence) with:

````markdown
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
````

In step 3, replace `3. The four links and the ghostty include.` with
`3. The eight links and the ghostty include.`, replace
`mkdir -p ~/.config ~/.config/ghostty ~/.proto ~/.agents` with
`mkdir -p ~/.config ~/.config/ghostty ~/.proto ~/.agents ~/.claude`, and insert
after the line that links `~/.agents/agents.toml` (keeping its three-space
indent):

```sh
   ln -s "$PWD/configs/claude/settings.json" ~/.claude/settings.json
   ln -s "$PWD/configs/claude/AGENTS.md" ~/.claude/AGENTS.md
   ln -sn "$PWD/configs/claude/hooks" ~/.claude/hooks
   ln -sn "$PWD/configs/claude/scripts" ~/.claude/scripts
```

- [ ] **Step 8: INSTALL.md — the intro, step 7 and the traps**

In the intro, replace `refuse rather than clobber — see "Traps".` with `never
clobber but can refuse or land inside a directory — see "Traps".` (one line in
the file; the result still wraps inside 80 columns — rewrap the paragraph if
not).

In step 7, replace:

```markdown
   output. Each assertion, and the reason it exists, is one named test in
   `bin/doctor.bats`.
```

with:

```markdown
   output. The one expected failure until the stable cask reaches 2.1.277 is
   `claude is 2.1.277 or later` — see "Traps". Each assertion, and the reason
   it exists, is one named test in `bin/doctor.bats`.
```

Replace the fish trap's opening:

```markdown
- `ln -s` refuses when something is already at the path, and fish creates
  `~/.config/fish` on its first run — so on a machine that has started fish
  once, there will be. Move it aside rather than deleting it:
```

with:

```markdown
- fish creates `~/.config/fish` on its first run, so on a machine that has
  started fish once, there is a directory at the path, and `ln -s` quietly
  puts the link inside it rather than refusing. Move it aside rather than
  deleting it first:
```

After the trap that ends `` `mv ~/.agents/agents.toml ~/agents.toml.bak`. ``,
insert:

```markdown
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
```

In the last trap, replace:

```markdown
  built for a provisioner that no longer exists; step 3 is what it did.
```

with:

```markdown
  built for a provisioner that no longer exists; step 3, less its agents and
  `~/.claude` links, is what it did.
```

- [ ] **Step 9: The 2026-08-21 design — four edits**

Each block below is indented three spaces for this list; strip that indent
before matching or inserting.

1. After the header line `` `agents.toml` — see `configs/agents/README.md`. ``
   insert:

   ```markdown
   **Amended 2026-09-24, again:** `~/.claude` joins as four links, with the
   placeholders filter and a work-term guard over the whole repo — see
   `docs/superpowers/specs/2026-09-24-claude-into-consus-design.md`.
   ```

2. In "Per-tool activation", replace

   ```markdown
   Measured against git 2.55.0, fish 4.8.0, ghostty 1.3.1, gh 2.96.0, proto 0.62.2
   and dotagents 3.1.0.
   ```

   with

   ```markdown
   Measured against git 2.55.0, fish 4.8.0, ghostty 1.3.1, gh 2.96.0, proto 0.62.2,
   dotagents 3.1.0, and Claude Code 2.1.273 and 2.1.281.
   ```

   and after the `agents` row insert:

   ```markdown
   | `claude` | `$CLAUDE_CONFIG_DIR`, default `~/.claude` | two file links, two directory links | `bin/doctor` link tests |
   ```

3. In "Destruction accounting", after the bullet that starts `` - A severed
   `proto` link is silent `` (its last line is two spaces, then
   `toolchains.`), insert:

   ```markdown
   - A dangling `~/.claude/settings.json` link is read as empty settings in
     silence, and Claude Code's next save writes a near-empty
     `configs/claude/settings.json` holding only that change. The rest of
     `~/.claude` — sessions, transcripts, memory — is not under the repo, so
     nothing run inside it can reach them.
   ```

4. In "Deliberately out of scope", replace the bullet

   ```markdown
   - `~/.claude` keeps its own repo at its real path. `~/.proto` does not: see
     `docs/superpowers/specs/2026-09-21-proto-into-consus-design.md` for where its
     record went and why.
   ```

   with:

   ```markdown
   - Neither `~/.claude` nor `~/.proto` keeps its own repo any more: see
     `docs/superpowers/specs/2026-09-24-claude-into-consus-design.md` and
     `docs/superpowers/specs/2026-09-21-proto-into-consus-design.md` for where
     each record went and why. The rest of `~/.claude` — sessions, transcripts,
     plugins, memory — stays unmanaged.
   ```

- [ ] **Step 10: The 2026-09-24 spec — status**

Replace `**Status:** designed` with `**Status:** executed 2026-09-24`. The
migration is executed once Task 7 passes; publishing is Task 9's separate,
reversible step.

- [ ] **Step 11: Verify the documents**

```sh
set -eu
cd ~/Developer/LRNZ09/consus
D=docs/superpowers/specs/2026-08-21-consus-migration-design.md
c() { if grep -q -- "$1" "$2"; then echo "✔ $3"; else echo "✖ $3"; fi; }
c '~/.claude/scripts        →' README.md "README table"
c '^- \*\*configs/claude\*\*' README.md "README what is here"
c 'the eight links' README.md "README eight links"
c '^- \*\*claude\*\* — `~/.claude/placeholders.tsv`' README.md "README per-machine"
c '^claude has both kinds' README.md "README hazard"
c '^A second guard keeps work terms out' README.md "README secret scanning"
c '^3\. The eight links and the ghostty include\.' INSTALL.md "INSTALL eight links"
c 'filter.placeholders.required true' INSTALL.md "INSTALL filter"
c 'what `bin/placeholders` rewrites' INSTALL.md "INSTALL step 1"
c 'ln -sn "$PWD/configs/claude/hooks"' INSTALL.md "INSTALL links"
c 'On a machine where Claude Code already ran' INSTALL.md "INSTALL trap: move aside"
c 'The terminal `claude` below 2.1.277' INSTALL.md "INSTALL trap: version"
c '`claude is 2.1.277 or later` — see "Traps"' INSTALL.md "INSTALL step 7"
c 'less its agents and' INSTALL.md "INSTALL last trap"
c 'Amended 2026-09-24, again' "$D" "design header"
c 'Claude Code 2.1.273 and 2.1.281' "$D" "design measured-against"
c '| `claude` |' "$D" "design table"
c 'A dangling `~/.claude/settings.json` link' "$D" "design destruction accounting"
grep -q '`~/.claude` keeps its own repo' "$D" && echo "✖ design out-of-scope" || echo "✔ design out-of-scope"
c 'Status:\*\* executed 2026-09-24' docs/superpowers/specs/2026-09-24-claude-into-consus-design.md "spec status"
markdownlint-cli2 README.md INSTALL.md configs/claude/README.md "$D" docs/superpowers/specs/2026-09-24-claude-into-consus-design.md
```

Expected: twenty `✔` lines, no `✖`, and `0 issues`.

- [ ] **Step 12: Commit**

```sh
cd ~/Developer/LRNZ09/consus
git add README.md INSTALL.md configs/claude/README.md docs/superpowers/specs
git commit -F - <<'EOF'
Record claude in the README, INSTALL.md and both designs

The link table, the fresh-machine steps, the per-machine settings, the linked
directory hazard and secret scanning gain claude and the work-term guard.
INSTALL.md gains the filter config, the map restore, the four links and two
traps. The 2026-08-21 design's out-of-scope line that kept ~/.claude out, and
its activation table, stop contradicting what the repo now does; the
2026-09-24 design is marked executed.
EOF
```

---

### Task 9: Publish

- [ ] **Step 1: STOP — push consus only after the human has read the full diff**

```sh
. ~/Backups/claude-consus.env
cd "$CLONE" && git log --stat origin/main..HEAD && git diff origin/main..HEAD
```

Show the human all of it, and say plainly that every line becomes public and
that the guard knows only mapped terms. A diff between commits shows the stored
blobs, so `settings.json` appears with placeholders, exactly as it will be
published. Ask: "Push these to LRNZ09/consus?" On yes:

```sh
cd ~/Developer/LRNZ09/consus && git push origin main
```

Expected: lefthook's `pre-push` script runs the guard and passes, then the
push; the gitleaks workflow runs on GitHub.

- [ ] **Step 2: STOP — archive dotclaude only on an explicit yes**

Ask: "Archive LRNZ09/dotclaude? It stays private and readable, and
`gh repo unarchive` reverses it." On yes (the GitHub MCP has no archive
operation, so this is the CLI fallback):

```sh
gh repo archive LRNZ09/dotclaude --yes
gh repo view LRNZ09/dotclaude --json isArchived,visibility -q '.visibility+" archived="+(.isArchived|tostring)'
```

Expected: `PRIVATE archived=true`.

- [ ] **Step 3: The private memory files**

After Step 2, so they describe what actually happened. These live in
`~/.claude/memory`, which no repo tracks. Rewrite
`project-dotclaude-placeholder-filter.md`, keeping its `name` so the
`[[project-dotclaude-placeholder-filter]]` links elsewhere still resolve:

```markdown
---
name: project-dotclaude-placeholder-filter
description: Since 2026-09-24 ~/.claude's record lives in public consus (configs/claude); bin/placeholders filters settings.json and guards every consus commit against work terms; dotclaude is archived
metadata:
  type: project
---

Since 2026-09-24 the hand-written part of ~/.claude — settings.json, AGENTS.md,
hooks/, scripts/ — lives in the PUBLIC repo LRNZ09/consus under configs/claude/,
reached through four links at Claude Code's own paths. LRNZ09/dotclaude
(private) is archived; its old checkout is in <BK from the state file>. There is
no ~/.claude/CLAUDE.md any more: AGENTS.md loads natively (2.1.277+) as a
project file through the upward walk.

Git stores placeholders in configs/claude/settings.json while the file on disk
keeps the real values, all under autoMode. consus's bin/placeholders is the
filter (per-clone git config) and, through lefthook, the pre-commit /
commit-msg / pre-push guard over the WHOLE consus repo. The real values sit only
in the untracked map ~/.claude/placeholders.tsv. How it works: consus
configs/claude/README.md, "Private values".

**Why:** consus is public and the user wants no employer traces in it, but
still needs the work auto-mode context in every session; the classifier reads
autoMode only from user settings, see [[reference-automode-config-scopes]].
**How to apply:**

- Before staging a new work value in settings.json, add a map row. Otherwise
  `git add` fails with "private term(s) found".
- consus commit messages must be neutral: no work names, no placeholders. Never
  bypass with `--no-verify` or `LEFTHOOK=0`.
- After Claude Code re-saves settings.json, `git diff` is empty but `git status`
  can list it until `git add`. Not a real change.
- No map, no consus commits. Keep an off-machine backup; see
  [[reference-machine-restore-checklist]].
- The terminal claude (stable cask, 2.1.273 on 2026-09-24) is below 2.1.277, so
  terminal sessions load no global instructions until stable catches up;
  consus bin/doctor fails its version test until then.
```

Fill `<BK from the state file>` with the literal `$BK` path. If Step 2 was
declined, say "not archived" instead, and drop "; dotclaude is archived" from
the `description` and "; dotclaude archived" from the MEMORY.md line below.

In `reference-machine-restore-checklist.md`, replace the bullet starting
`- **~/.claude placeholder filter**` with:

```markdown
- **~/.claude placeholder filter** ([[project-dotclaude-placeholder-filter]]):
  a consus clone has placeholders in `configs/claude/settings.json` and no
  filter config. Restore `~/.claude/placeholders.tsv` (the only copy of the
  real work values — keep an off-machine backup) and follow consus INSTALL.md
  step 2, which sets the filter and re-checks the file out.
```

In `reference-automode-config-scopes.md`, replace the text `which is why
~/.claude uses a placeholder filter` — one line in the file, a single space
before `placeholder` — with `which is why consus's configs/claude/settings.json
goes through a placeholder filter`.

In `feedback-prefer-mcp-over-cli.md`, replace `` `~/.claude/CLAUDE.md` only
imports it `` with `` since 2026-09-24 a link into consus configs/claude,
loaded natively (2.1.277+); there is no `~/.claude/CLAUDE.md` ``.

In `MEMORY.md`, replace the line starting `- [dotclaude placeholder filter]`
with:

```markdown
- [~/.claude record + placeholder filter](project-dotclaude-placeholder-filter.md) — since 2026-09-24 in public consus configs/claude via 4 links; bin/placeholders filters settings.json and guards every consus commit; dotclaude archived; map a new work value before `git add`, never --no-verify
```

No commit: these files are not in any repo.

- [ ] **Step 4: Keep the state file until the human discards it**

The state file and `$BK` are the rollback's only inputs. Do not remove them.

- [ ] **Step 5: Remove the raw copies the old filter left behind**

At the human's request. Before this migration, dotclaude's filter left a
`mktemp -d` directory in the user temp directory every time `clean` refused,
holding its unfiltered input — the live `settings.json`, private values
included. On 2026-09-24 there were 84. Task 6 retired that script and
`bin/placeholders` no longer leaks, so none can reappear. Only directories
that hold nothing but the old filter's `in`, `out` and `err` files are
removed; nothing is printed from inside them.

```sh
set -eu
T=$(getconf DARWIN_USER_TEMP_DIR)
[ -n "$T" ] && [ -d "$T" ] || { echo "✖ no user temp directory"; exit 1; }
n=0 kept=0
for d in "$T"tmp.*; do
	[ -d "$d" ] && [ -f "$d/in" ] || continue
	if [ -z "$(ls -A "$d" | grep -vxE 'in|out|err' || true)" ]; then
		rm -r -- "$d" && n=$((n + 1))
	else
		kept=$((kept + 1))
	fi
done
echo "removed $n, left $kept that hold anything else"
```

Expected: `removed` about 84, `left 0`. A nonzero `left` is a directory some
other tool made: leave it and say so.

---

## Rollback

Valid from Task 6 Step 3 onward. Every path is handled on its own: a link this
plan made is replaced or removed, a regular file that is there now is left
alone and reported, and nothing is moved over anything that exists.

```sh
set -u
. ~/Backups/claude-consus.env
: "${CH:?}" "${BK:?}"
# The two files: a link is replaced by the pre-migration copy in one rename,
# so the path is never missing. A regular file there is the live one — keep it.
for f in settings.json AGENTS.md; do
	if [ -L "$CH/$f" ] && [ -e "$BK/$f" ]; then
		cp -p "$BK/$f" "$CH/$f.rollback" && mv -f "$CH/$f.rollback" "$CH/$f"
	fi
done
[ ! -L "$CH/scripts" ] || rm "$CH/scripts"
# hooks is a link, or missing after a Task 6 Step 5 interrupted inside its gap.
if [ -d "$BK/hooks" ] && { [ -L "$CH/hooks" ] || [ ! -e "$CH/hooks" ]; }; then
	[ ! -L "$CH/hooks" ] || rm "$CH/hooks"
	mv "$BK/hooks" "$CH/hooks"
fi
for p in statusline-command.sh CLAUDE.md .gitignore README.md .git; do
	[ -e "$BK/$p" ] || continue
	if [ -e "$CH/$p" ]; then
		echo "✖ $CH/$p exists; left $BK/$p where it is"
	else
		mv "$BK/$p" "$CH/$p"
	fi
done
cd "$CH" && git status --short
```

Expected: `git status` lists `settings.json` as modified at most — the one
change it carried before the migration. **Never `git restore settings.json`
there**: that would throw the change away.

The restored `settings.json` is the pre-migration copy on purpose: the
record's copy points `statusLine` at `scripts/`, which the rollback removes.
Anything saved through the link after activation is in
`configs/claude/settings.json` (or `AGENTS.md`), uncommitted. Carry what is
wanted back by hand, then commit or `git restore` it there, before re-running
Task 6 from Step 3: Step 4 refuses to re-derive over it.

To undo the rest, each only if it happened and only on the human's yes: `gh repo
unarchive LRNZ09/dotclaude --yes`; `cd ~/.claude && git revert --no-edit HEAD
&& git push origin main` to undo the pointer commit; and put back the memory
files Task 9 Step 3 rewrote. consus's commits can stay: nothing reads them
without the links. Claude Code reads regular files exactly as it reads the
links, so the machine is whole once they are back.
