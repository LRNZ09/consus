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
while read -r _ sha _ _; do
	# A deletion publishes nothing.
	case $sha in *[!0]*) ;; *) continue ;; esac
	command -v gitleaks >/dev/null || { echo "✖ gitleaks not installed — brew install gitleaks"; exit 1; }
	# gitleaks scans nothing and passes when its git log fails, so what is not
	# a commit, or a tag of one, is refused here.
	git rev-parse -q --verify "$sha^{commit}" >/dev/null ||
		{ echo "✖ $sha is not a commit, and gitleaks scans only commits"; exit 1; }
	gitleaks git --no-banner --redact -v --config .gitleaks.toml \
		--log-opts="--no-color --no-ext-diff --no-textconv --root --diff-merges=first-parent $sha --not --remotes=$1" ||
		exit 1
done
