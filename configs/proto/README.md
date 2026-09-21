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
