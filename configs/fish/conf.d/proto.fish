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
# PROTO_REPORTER is kept as insurance, not as an active fix here. proto 0.58.2
# emitted NDJSON in agent environments, which `source` could not parse,
# producing errors on every shell start. proto 0.62.2 does not — verified
# against both binaries on 2026-09-22 with AI_AGENT set. The setting stays for
# a machine that ends up running an older proto again, not because this one
# needs it. It still has to be `set -gx` rather than a one-shot prefix:
# activation re-runs through a fish hook whose body shells out to
# `proto activate fish --export`, and only an exported variable reaches that
# inner call.
if type -q proto
    set -gx PROTO_REPORTER text
    proto activate fish | source
end
