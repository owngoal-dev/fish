[fish](https://fishshell.com/) — the friendly interactive shell — built for jailbroken iOS without a fork execution path.

## Which one do I download?

Both packages use the same source and patches. The architecture names the bootstrap layout, not the CPU; RootHide additionally redirects path-related imports through `libvrootapi`.

| bootstrap | download |
| --- | --- |
| rootless (fixed `/var/jb`) | `@PACKAGE_ID@_@VERSION@_iphoneos-arm64.deb` |
| roothide (randomized jbroot) | `@PACKAGE_ID@_@VERSION@_iphoneos-arm64e.deb` |

Run `dpkg --print-architecture` if unsure. Requires iOS @MIN_IOS_MAJOR@ or later.

## Usage

Run `fish`. `cd` is a function over the `cd` builtin; `ls` is a function over the external `ls`. Other external commands are launched through `posix_spawn`.

User configuration lives in `~/.config/fish`. Each package compiles its bootstrap's correct `etc/fish` and `usr/share/fish` paths.

## About this build

Upstream [`fish-shell/fish-shell@@UPSTREAM_SHORT@`](https://github.com/fish-shell/fish-shell/commit/@UPSTREAM_REF@), plus the single-purpose iOS forkless patches in [`patches/`](https://github.com/owngoal-dev/fish/tree/@TAG@/patches). PCRE2 is linked statically; RootHide adds its bootstrap-provided `libvrootapi` dependency.

Verify downloads against `SHA256SUMS`.

**Full changelog**: https://github.com/owngoal-dev/fish/commits/@TAG@
