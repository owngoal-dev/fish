# fish for jailbroken iOS

Forkless [fish](https://fishshell.com/) for iOS 15+, built for both bootstrap
layouts from one pinned source and patch set.

| bootstrap | package architecture | package paths | process view |
| --- | --- | --- | --- |
| rootless | `iphoneos-arm64` | prefixed with `/var/jb` | jailbreak files remain under `/var/jb` |
| roothide | `iphoneos-arm64e` | unprefixed | randomized jbroot is presented as `/`; iOS root is `/rootfs` |

Both packages contain arm64 Mach-O executables; the architecture field selects
the bootstrap layout, not the CPU slice. Rootless compiles paths below
`/var/jb`; RootHide keeps `/usr` and `/etc` and redirects path-related imports
through `libvrootapi`. Check a device with `dpkg --print-architecture`. See
[RootHide's filesystem model](https://github.com/RootHide/Developer/blob/main/roothide.md).

This packaging repository keeps no fish source. Every day it checks the newest
stable fish release, pins its full upstream commit, applies the iOS patches,
and publishes both packages through GitHub Actions.

```sh
make check
make debs
make install
```

`cd` and `ls` are fish functions: `cd` delegates to the `cd` builtin, while
`ls` delegates to the external `ls`. `pwd`, `echo`, `printf`, `jobs`, `fg`,
`bg`, `wait`, `set`, `string`, `math`, and `path` are builtins. External
programs launch through `posix_spawn`.

The fish Mach-O links only iOS `libSystem` and `libiconv`; PCRE2 is static.
The package has no userland utility dependencies. Fish itself works alone;
install external commands such as `ls`, `sed`, and `awk` only when needed.
