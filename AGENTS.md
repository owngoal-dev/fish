# fish — Agent Notes

[fish](https://fishshell.com/) is packaged as a forkless interactive shell for
jailbroken iOS 15+, for both roothide and rootless bootstraps.

This is a packaging repository, not a fork. It fetches a pinned upstream
commit, applies `patches/`, and cross-compiles one arm64 binary per bootstrap
layout.

## Hard rules

- Pin `UPSTREAM_REF` to the full commit behind the newest stable upstream
  release. The daily workflow updates the pin, proves the patches apply, then
  tags and releases it.
- Keep upstream changes as small patches under `patches/`; never vendor source.
- The iOS binary must not import fork runtime symbols. `scripts/build-ios.sh`
  verifies that `_fork`, `_vfork`, and `_pthread_atfork` are absent and an
  exact `_posix_spawn` import is present after every build.
- `iphoneos-arm64` means rootless and compiles paths below `/var/jb`;
  `iphoneos-arm64e` means roothide and compiles unprefixed paths that its dpkg
  maps into the randomized jbroot. Both CPU slices are plain arm64.
- Never hardcode a randomized roothide container path. RootHide keeps `/usr`
  and `/etc` in the binary and redirects path-related imports with its pinned
  `symredirect` tool; rootless must not load `libvrootapi`.
- Preserve both `usr/share/fish` and `etc/fish`, even when empty, and verify
  `__fish_data_dir` and `__fish_sysconf_dir` on each bootstrap.
- Every deb must include upstream `COPYING` and `doc_src/license.rst`; the
  packaging repository's MIT license does not replace fish's GPL notices.
- Run `symredirect` before signing the RootHide binary and prove its
  `libvrootapi` load command exists. Prove the rootless binary lacks it.
- `configuration/version.txt` is the only package-version source.
- Patched source is intentionally dirty. iOS builds must derive
  `FISH_BUILD_VERSION` from Cargo's package version, not `git describe`, and
  device tests must require an exact clean `fish --version`.
- Because `wiki.qaq.fish` owns the same paths as the bootstrap's `fish`
  package, keep `Conflicts`, `Replaces`, and `Provides: fish` together.
- `CLAUDE.md` must remain a symlink to `AGENTS.md`.
- Test by installing a package, never by copying the binary to `/var/mobile`.
- Before any push or release, read the diff, staged package tree, and binary
  strings for credentials, private paths, device identifiers, hostnames, and
  addresses. Publish only through the Release workflow.

## Port

The port stays split by failure boundary so an upstream bump identifies what
needs rebasing:

- `0001-ios-forkless-exec.patch` forces iOS external commands through
  `posix_spawn` and compiles out the fork fallback.
- `0002-ios-spawn-job-control.patch` handles same-FD inheritance and starts a
  foreground process-group leader suspended until the parent transfers the TTY.
- `0003-ios-no-fork-runtime-hooks.patch` avoids Rust's spawning helper in the
  standalone help path and removes the unused iOS `pthread_atfork` registration.
- `0004-ios-reproducible-build-paths.patch` keeps Host build/source paths out of
  the iOS binary while leaving Host-side resource embedding on real paths.

Keep each downstream patch single-purpose and ordered by dependency. Patch
application is only a structural check; the final Mach-O symbol gate must also
prove that no dependency or newly reachable standard-library path restored a
fork import. Release builds must also remap Cargo and rustup roots and reject
any remaining Host home, workspace, or temporary path in the final binary.

Fish 4.x embeds its standard functions and completions. The build statically
links PCRE2 and disables translations and generated docs. Do not declare
userland utilities as package dependencies: fish starts without them, while
functions that invoke `ls`, `sed`, `awk`, or similar tools degrade only when
that specific external command is absent.

`cd` is a fish function over the `cd` builtin. `ls` is a fish function that
ultimately runs the external `ls`. `pwd`, `echo`, `printf`, `jobs`, `fg`, `bg`,
`wait`, `set`, `string`, `math`, and `path` are builtins; editors, SSH clients,
`cat`, and `sed` are external.

Fish is also a multicall executable for `fish_indent` and `fish_key_reader`.
Perform strip, RootHide import rewriting, and signing once, then make both
alternate names executable hard links to that final inode; package tests must
execute at least `fish_indent --version` instead of checking existence alone.

## Build and verify

```sh
make check
make source
make debs
make install
```

`make install` selects the package with `dpkg --print-architecture` and tests
builtins, external spawn, a pipeline, redirection, a background job, and wait.
Foreground TTY stop/resume still requires an attached-device interactive test.

The release contract is two assets ending in `iphoneos-arm64.deb` and
`iphoneos-arm64e.deb`, plus `SHA256SUMS`, on a stable `vX.Y.Z` GitHub Release.
