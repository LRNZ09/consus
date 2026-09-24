#!/usr/bin/env bats
# consus/bin/doctor.bats — the record's assertions, one per test. A report,
# never a repair: nothing here writes to the record or to the links.
#
# Link integrity is the one invariant git cannot express — the repo can be
# pristine while $XDG_CONFIG_HOME points somewhere else, and for git, fish and
# proto a severed link is completely silent. For agents a dangling one is
# worse than silent: see the agents link test. Since the links are now made by
# hand (INSTALL.md), the two things the old installer did quietly — the clone's
# mode and lefthook's hooks — are asserted here too.
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
	export REPO CONFIG_HOME RECORD PROTO_STORE AGENTS_ROOT
	echo "# repo: $REPO" >&3
	echo "# proto store: $PROTO_STORE" >&3
	echo "# agents root: $AGENTS_ROOT" >&3
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
	grep -q lefthook "$REPO/.git/hooks/pre-commit" 2>/dev/null || {
		echo "run: cd $REPO && lefthook install"
		echo "without them gitleaks does not see a commit until it is pushed"
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
	# configs/agents/ still present, every command — `trust list` included —
	# writes a default config through the link into this repo, and the next
	# install prunes every skill. git restore the record, then install.
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

# Advisories. Deliberately not assertions: neither is a broken machine, and the
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
	local queue
	queue=$(git -C "$REPO" status --porcelain 2>/dev/null || true)
	if [ -n "$queue" ]; then
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
}
