#!/usr/bin/env bats
# consus/bin/doctor.bats — the record's assertions, one per test. A report,
# never a repair: nothing here writes to the record or to the links.
#
# Link integrity is the one invariant git cannot express — the repo can be
# pristine while $XDG_CONFIG_HOME points somewhere else, and for git, fish and
# proto a severed link is completely silent. For agents and for claude's
# settings.json a dangling one is worse than silent: see their link tests.
# Since the links are now made by hand (INSTALL.md), the two things the old
# installer did quietly — the clone's mode and lefthook's hooks — are asserted
# here too, and so is the placeholders filter, which is per-clone git config.
#
# Run it as bin/doctor. The one side effect is the fish probe: `fish -c`
# sources conf.d/proto.fish, which runs `proto activate`, and that materialises
# the proto store directory when it is missing.

setup_file() {
	REPO=$(cd -- "$(dirname -- "$BATS_TEST_FILENAME")/.." && pwd -P)
	CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
	RECORD="$REPO/configs"
	# proto's store, in proto's own precedence order. proto never reads
	# XDG_CONFIG_HOME, so its record is not under $CONFIG_HOME — nor is the
	# agents record below — and it is a single file, because PROTO_HOME
	# relocates the whole 2.3 GB store and cannot separate the record from it.
	if [ -n "${PROTO_HOME:-}" ]; then
		PROTO_STORE="$PROTO_HOME"
	elif [ -n "${XDG_DATA_HOME:-}" ]; then
		PROTO_STORE="$XDG_DATA_HOME/proto"
	else
		PROTO_STORE="$HOME/.proto"
	fi
	# dotagents' own root lookup. Its record is a single file for the same
	# reason as proto's: DOTAGENTS_HOME relocates skills/ along with it.
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
}

# assert_link <path> <target> — the whole health of a link, in one place. The
# dangling test is the load-bearing one: a link whose target is gone still
# reads back correctly, so readlink alone calls it healthy, and that is exactly
# the state worth catching — proto then reads nothing and reverts to its
# built-in defaults, telemetry included.
assert_link() {
	local path="$1" target="$2" current
	[ -L "$path" ] || {
		echo "$path is not a symlink (expected -> $target)"
		return 1
	}
	current=$(readlink -- "$path")
	[ "$current" = "$target" ] || {
		echo "$path -> $current (expected -> $target)"
		return 1
	}
	[ -e "$path" ] || {
		echo "$path -> $target, but the target does not exist"
		return 1
	}
}

# require_link <path> <target> — skip rather than fail when a check downstream
# of a link cannot mean anything without it.
require_link() {
	assert_link "$1" "$2" >/dev/null 2>&1 || skip "$1 is not the expected link"
}

@test "~/.config/git links into this clone" {
	assert_link "$CONFIG_HOME/git" "$RECORD/git"
}

@test "~/.config/fish links into this clone" {
	assert_link "$CONFIG_HOME/fish" "$RECORD/fish"
}

@test "proto's record links into this clone" {
	assert_link "$PROTO_STORE/.prototools" "$RECORD/proto/.prototools"
}

@test "the clone is mode 700" {
	# $CONFIG_HOME is 700 and the links lead here, so this directory is read
	# through them; a fresh clone under ~/Developer is 755.
	local mode
	mode=$(stat -f %Lp -- "$REPO")
	[ "$mode" = 700 ] || {
		echo "$REPO is mode $mode, expected 700 — run: chmod 700 $REPO"
		return 1
	}
}

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

@test "the ghostty include names this clone" {
	# Not redundant with +validate-config below: that exits 1 when the stub
	# names a missing target, but 0 when the stub is absent altogether —
	# ghostty falls back to Application Support and reports success.
	local stub="$CONFIG_HOME/ghostty/config.ghostty"
	local want="config-file = $RECORD/ghostty/config.ghostty"
	[ -f "$stub" ] || {
		echo "$stub is missing — ghostty falls back to Application Support in silence"
		return 1
	}
	[ "$(cat -- "$stub")" = "$want" ] || {
		echo "$stub does not name this clone; expected exactly:"
		echo "  $want"
		return 1
	}
}

@test "ghostty accepts the configuration it will load" {
	command -v ghostty >/dev/null 2>&1 || skip "ghostty is not installed"
	ghostty +validate-config >/dev/null 2>&1 || {
		echo "ghostty +validate-config failed — run it directly for the reason"
		return 1
	}
}

@test "every plugin in fish_plugins is installed" {
	command -v fish >/dev/null 2>&1 || skip "fish is not installed"
	# Gated on the link, and not merely for tidiness: fish CREATES
	# $XDG_CONFIG_HOME/fish when it is missing, so querying fisher through a
	# severed link would plant a real directory where the link belongs.
	require_link "$CONFIG_HOME/fish" "$RECORD/fish"

	# `fish -c` is safe here: measured, reading a universal variable leaves
	# fish_variables untouched. conf.d noise goes to stderr.
	local installed names missing=0 declared
	installed=$(fish -c 'string join \n -- $_fisher_plugins' 2>/dev/null || true)
	[ -n "$installed" ] || skip "fisher never ran here (_fisher_plugins is unset) — see INSTALL.md step 5"

	# Pins are stripped from both sides: the declaration carries pins the
	# installed record does not, and this asks whether a plugin is present, not
	# which tag it came from.
	names=$(printf '%s\n' "$installed" | sed 's|@.*||')
	while IFS= read -r declared; do
		[ -n "$declared" ] || continue
		printf '%s\n' "$names" | grep -qxF "${declared%%@*}" || {
			echo "declared but not installed: $declared"
			missing=$((missing + 1))
		}
	done < "$RECORD/fish/fish_plugins"
	[ "$missing" -eq 0 ] || {
		echo "$missing missing — run: fisher update (needs network)"
		return 1
	}
}

@test "every pin in .prototools is installed" {
	command -v jq >/dev/null 2>&1 || skip "jq is not installed"
	# Gated on the link: a record read through a severed link is proto's
	# built-in defaults rather than this repo's, and asserting against those
	# would mean nothing.
	require_link "$PROTO_STORE/.prototools" "$RECORD/proto/.prototools"

	# Top-level keys only: in TOML everything before the first table belongs to
	# the root. A trailing comment is stripped first, or `node = "26.5.0" # keep`
	# yields a version of 26.5.0#keep. No version string contains a #.
	local pins tool ver manifest missing=0 checked=0
	pins=$(awk '/^\[/ { exit }
	            /^[A-Za-z]/ && /=/ { sub(/#.*/, ""); gsub(/["[:space:]]/, "")
	                                 n = index($0, "=")
	                                 if (n > 1 && length($0) > n)
	                                     print substr($0, 1, n - 1), substr($0, n + 1) }' \
		"$RECORD/proto/.prototools")

	while read -r tool ver; do
		[ -n "$tool" ] || continue
		# bundled, latest and every alias resolve at call time; only a concrete
		# version can be looked for in a manifest.
		case "$ver" in [0-9]*) ;; *) continue ;; esac
		checked=$((checked + 1))
		# manifest.json rather than tools/<tool>/<version>/: measured, tools/rust
		# holds only manifests, because proto's rust support defers to ~/.rustup.
		manifest="$PROTO_STORE/tools/$tool/manifest.json"
		# A pin may be a prefix: `proto pin node 22` writes "22" while the
		# manifest records "22.23.1". Matching on "$ver." rather than a bare
		# prefix keeps 2 from matching 22.23.1. jq, not grep: the manifest
		# carries a `versions` list of what is AVAILABLE beside
		# `installed_versions`, and grep cannot tell the two apart.
		if [ ! -f "$manifest" ] ||
			! jq -e --arg v "$ver" \
				'.installed_versions // [] | any(. == $v or startswith($v + "."))' \
				"$manifest" >/dev/null 2>&1; then
			echo "declared but not installed: $tool $ver"
			missing=$((missing + 1))
		fi
	done <<-EOF
		$pins
	EOF

	# What stops "checked nothing" reading as "everything is fine": a record
	# whose first line is a table yields no pins at all.
	[ "$checked" -gt 0 ] || {
		echo "no pins found in configs/proto/.prototools — the record is empty or malformed"
		return 1
	}
	[ "$missing" -eq 0 ] || {
		echo "$missing missing — run: proto install --config-mode global (needs network)"
		return 1
	}
}

@test "~/.agents/agents.toml links into this clone" {
	# The dangling case is worse here than proto's. dotagents does not fall back
	# to defaults in memory: measured on 3.1.0, with the target gone but
	# configs/agents/ still present, every command but doctor — `trust list`
	# included — writes a default config through the link into this repo, and
	# the next install prunes every skill. git restore the record, then install.
	assert_link "$AGENTS_ROOT/agents.toml" "$RECORD/agents/agents.toml"
}

@test "every skill in agents.lock is installed" {
	# Gated on the link: a lock written from some other agents.toml says
	# nothing about this record.
	require_link "$AGENTS_ROOT/agents.toml" "$RECORD/agents/agents.toml"

	# The lock is dotagents' machine state, not the record, and install writes
	# it after installing — so this asks whether something installed has since
	# gone missing. skills/<name>/ is dotagents' own rule. Directories no lock
	# entry names — twg's twg* and Claude Code's synced/ — belong there too and
	# are deliberately not reported.
	local lock="$AGENTS_ROOT/agents.lock" names name missing=0 checked=0
	[ -f "$lock" ] || {
		echo "$lock is missing — run: npx @sentry/dotagents --user install (needs network)"
		return 1
	}
	# A name with a dot is written quoted: [skills."a.b"].
	names=$(sed -n 's/^\[skills\.\(.*\)\]$/\1/p' "$lock" | sed 's/^"\(.*\)"$/\1/')

	while IFS= read -r name; do
		[ -n "$name" ] || continue
		checked=$((checked + 1))
		[ -d "$AGENTS_ROOT/skills/$name" ] || {
			echo "locked but not installed: $name"
			missing=$((missing + 1))
		}
	done <<-EOF
		$names
	EOF

	[ "$checked" -gt 0 ] || {
		echo "no [skills.*] entries in $lock — run: npx @sentry/dotagents --user install (needs network)"
		return 1
	}
	[ "$missing" -eq 0 ] || {
		echo "$missing missing — run: npx @sentry/dotagents --user install (needs network)"
		return 1
	}
}

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
		echo "run the three git config filter.placeholders lines of INSTALL.md step 2;"
		echo "the step's last line is guarded and safe to re-run"
		return 1
	}
}

@test "the placeholder map is readable" {
	# Without it every guard fails closed and nothing can be committed; this
	# names the file before a commit does. It is untracked and exists nowhere
	# else on this machine. Exactly one guard row: the guards refuse a second
	# one, which used to replace the first in silence.
	local rows
	[ -r "$PLACEHOLDER_MAP" ] || {
		echo "$PLACEHOLDER_MAP is missing or unreadable — restore it from backup"
		return 1
	}
	rows=$(grep -c "^guard$(printf '\t')" "$PLACEHOLDER_MAP" || true)
	[ "$rows" -gt 0 ] || {
		echo "$PLACEHOLDER_MAP has no guard row, so every guard refuses everything"
		return 1
	}
	[ "$rows" -eq 1 ] || {
		echo "$PLACEHOLDER_MAP has $rows guard rows, so every guard refuses everything;"
		echo "join them with | into one"
		return 1
	}
}

@test "the live settings.json holds real values, not placeholders" {
	# smudge never fails, so a checkout that cannot resolve a token — the map
	# missing or short of a row another machine added, a conflicted merge,
	# INSTALL.md step 2 run before the map is back — leaves it in the live file
	# in silence, and autoMode then describes a token, not the host. Once the
	# map is back, git status and git add fail with a misleading message. No
	# token git stores may appear in the live file. Prints token names only:
	# they are public, the values are not.
	local live="$RECORD/claude/settings.json" tokens token found=
	[ -r "$PLACEHOLDER_MAP" ] || skip "the map is unreadable — see the map test"
	[ -f "$live" ] || skip "$live is missing — see its link test"
	tokens=$(git -C "$REPO" show :configs/claude/settings.json 2>/dev/null |
		grep -o '<[a-z0-9][a-z0-9-]*>' | sort -u || true)
	for token in $tokens; do
		if grep -qF -- "$token" "$live"; then
			found="$found $token"
		fi
	done
	[ -z "$found" ] || {
		echo "configs/claude/settings.json holds placeholders, not real values:$found"
		echo "with the map restored, run in $REPO:"
		echo "  bin/placeholders smudge < configs/claude/settings.json > configs/claude/settings.json.tmp.fix && mv configs/claude/settings.json.tmp.fix configs/claude/settings.json"
		return 1
	}
}

# Advisories. Deliberately not assertions: none is a broken machine, and the
# run must not fail on them. They print, and that is all.
teardown_file() {
	# A self-installed proto in the store shadows Homebrew's, because activation
	# prepends the store's bin. Never assert a version here: which binary answers
	# depends on which shell ran this.
	if [ -e "$PROTO_STORE/bin/proto" ]; then
		echo "# note: $PROTO_STORE/bin/proto shadows Homebrew's on PATH;" >&3
		echo "#       brew upgrade proto cannot reach it." >&3
	fi
	# The tools read the working tree, so the machine and the working tree agree
	# by construction. A dirty tree means the *committed* record has not caught
	# up, and the design wants that visible rather than hidden.
	# git status fails outright when the filter refuses settings.json, and
	# its own message then misleads: say so rather than swallow it.
	local queue
	if ! queue=$(git -C "$REPO" status --porcelain 2>/dev/null); then
		echo "# note: git status failed — usually a private value in settings.json" >&3
		echo "#       the map does not cover (see configs/claude/README.md)." >&3
	elif [ -n "$queue" ]; then
		echo "# note: uncommitted changes — git restore <path> if the record was" >&3
		echo "#       right, git commit if the machine was:" >&3
		printf '%s\n' "$queue" | sed 's|^|#         |' >&3
	fi
	# A leftover checkout claims agents.toml: any checkout, switch or pull
	# there restores a regular file over the link.
	if [ -e "$AGENTS_ROOT/.git" ]; then
		echo "# note: $AGENTS_ROOT/.git exists — a checkout there restores a" >&3
		echo "#       regular agents.toml over the link." >&3
	fi
	# The same for the retired dotclaude checkout, which still tracks
	# settings.json, AGENTS.md and hooks/ at the paths the links now occupy.
	if [ -e "$CLAUDE_HOME/.git" ]; then
		echo "# note: $CLAUDE_HOME/.git exists — a checkout there restores" >&3
		echo "#       regular files over three of the four links." >&3
	fi
}
