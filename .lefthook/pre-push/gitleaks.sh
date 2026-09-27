#!/bin/sh
# gitleaks over every commit being pushed that the remote lacks: pre-commit's
# scan never sees a commit made with the hooks off, and cherry-pick, rebase, am
# and merge run no pre-commit. lefthook passes the remote as $1 and git's ref
# lines on stdin. A lefthook script rather than a command: see lefthook.yml.
#
# --log-opts goes to gitleaks' own git log -p, and its flags keep user config
# from hiding a line, as bin/placeholders' check-push does. Measured on
# gitleaks 8.30.1, each of these let an address through without them: color.ui
# or color.diff set to always, a textconv driver, log.showRoot=false on a root
# commit, and a merge's own changes.
#
# gitleaks splits --log-opts at spaces, and when its git log fails it scans
# nothing and passes. $1 is the remote's name, or on a push to a URL or path
# the URL or path itself, and one with a space in it made that git log fail:
# measured by running this script on its own, since lefthook 2.1.14 splits its
# arguments at spaces first. So the commits the remote-tracking refs hold are
# left out only when $1 names one of this clone's remotes and holds no
# whitespace and no glob character (* ? [ ] or a backslash); any other push
# scans each commit's whole history. git remote add refuses a name with a
# space, *, ? or [, but git config can make one, and grep -x would read a
# newline in $1 as two names. --remotes= takes its value as a glob, so a
# remote named * left out every commit any remote's tracking refs hold.
not=
case $1 in
'' | *[[:space:]]* | *[][*?\\]*) ;;
*) if git remote | command grep -qxF -- "$1"; then not=" --not --remotes=$1"; fi ;;
esac
while read -r _ sha _ _; do
	# A deletion publishes nothing.
	case $sha in *[!0]*) ;; *) continue ;; esac
	command -v gitleaks >/dev/null || { echo "✖ gitleaks not installed — brew install gitleaks"; exit 1; }
	# gitleaks scans nothing and passes when its git log fails, so what is not
	# a commit, or a tag of one, is refused here.
	git rev-parse -q --verify "$sha^{commit}" >/dev/null ||
		{ echo "✖ $sha is not a commit, and gitleaks scans only commits"; exit 1; }
	gitleaks git --no-banner --redact -v --config .gitleaks.toml \
		--log-opts="--no-color --no-ext-diff --no-textconv --root --diff-merges=first-parent $sha$not" ||
		exit 1
done
