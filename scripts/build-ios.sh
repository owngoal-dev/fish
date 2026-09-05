#!/usr/bin/env bash
# Cross-compile fish for iOS and print the assembled payload directory.

set -Eeuo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "usage: $0 <src-dir> <scratch-dir> <install-prefix>" >&2
    echo "note: install-prefix is empty for roothide and /var/jb for rootless" >&2
    exit 64
fi

src_dir="$1"
scratch_dir="$2"
install_prefix="$3"
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source=../configuration/upstream.env
source "$repository_root/configuration/upstream.env"
: "${PROGRAM:?}" "${MIN_IOS:?}" "${ARCH:?}" "${RUST_TOOLCHAIN:?}"

[[ -z "$install_prefix" || "$install_prefix" == /var/jb ]] || {
    echo "error: install prefix must be empty or /var/jb" >&2
    exit 64
}
runtime_prefix="$install_prefix/usr"
runtime_sysconf="$install_prefix/etc"

[[ -f "$src_dir/Cargo.toml" && -f "$src_dir/CMakeLists.txt" ]] || {
    echo "error: $src_dir is not a prepared fish source tree" >&2
    exit 66
}
for tool in cargo cmake ninja rustup; do
    command -v "$tool" >/dev/null || { echo "error: $tool is not installed" >&2; exit 69; }
done

ios_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
clang="$(xcrun --sdk iphoneos --find clang)"
target="aarch64-apple-ios"
rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal --target "$target" >/dev/null
rustc="$(rustup which --toolchain "$RUST_TOOLCHAIN" rustc)"
cargo="$(rustup which --toolchain "$RUST_TOOLCHAIN" cargo)"

mkdir -p "$scratch_dir"
build_dir="$scratch_dir/build"
payload="$scratch_dir/payload"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
rustup_home="$(rustup show home)"
remap="--remap-path-prefix=$src_dir=/src --remap-path-prefix=$scratch_dir=/build --remap-path-prefix=$cargo_home=/cargo --remap-path-prefix=$rustup_home=/rustup"

export SDKROOT="$ios_sdk"
export IPHONEOS_DEPLOYMENT_TARGET="$MIN_IOS"
export CC="$clang"
export CARGO_TARGET_AARCH64_APPLE_IOS_LINKER="$clang"
export RUSTFLAGS="$remap"

echo "building $PROGRAM for iOS $MIN_IOS ($ARCH, rustc $RUST_TOOLCHAIN)" >&2
cmake -S "$src_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_MACOSX_BUNDLE=OFF \
    -DCMAKE_INSTALL_PREFIX="$runtime_prefix" \
    -DCMAKE_INSTALL_SYSCONFDIR="$runtime_sysconf" \
    -DRust_COMPILER="$rustc" \
    -DRust_CARGO="$cargo" \
    -DRust_CARGO_TARGET="$target" \
    -DFISH_USE_SYSTEM_PCRE2=OFF \
    -DWITH_MESSAGE_LOCALIZATION=OFF \
    -DWITH_DOCS=OFF \
    >&2
cmake --build "$build_dir" >&2

executable="$build_dir/$PROGRAM"
[[ -f "$executable" ]] || { echo "error: build produced no $executable" >&2; exit 65; }
vtool -show-build "$executable" 2>/dev/null | grep -qE '^ *platform (IOS|2)$' || {
    echo "error: $executable is not an iOS binary" >&2
    exit 65
}
[[ "$(lipo -archs "$executable")" == "$ARCH" ]] || {
    echo "error: $executable is not a single $ARCH binary" >&2
    exit 65
}

while read -r dependency; do
    case "$dependency" in
    /usr/lib/* | /System/Library/Frameworks/*) ;;
    *) echo "error: iOS does not provide dependency $dependency" >&2; exit 65 ;;
    esac
done < <(otool -L "$executable" | tail -n +2 | awk '{print $1}')

# The iOS build must not retain a fork path, even through Rust's process helpers.
process_symbols="$(nm -m "$executable")"
if grep -Eq 'external _(fork|vfork|pthread_atfork)( |$)' <<<"$process_symbols"; then
    echo "error: $executable still imports a fork runtime symbol" >&2
    grep -E 'external _(fork|vfork|pthread_atfork)( |$)' <<<"$process_symbols" >&2
    exit 65
fi
grep -qE 'external _posix_spawn( |$)' <<<"$process_symbols" || {
    echo "error: $executable does not import posix_spawn" >&2
    exit 65
}

rm -rf -- "$payload"
DESTDIR="$payload" cmake --install "$build_dir" >&2
payload_root="$payload$install_prefix"
install -m 0644 "$src_dir/COPYING" "$payload_root/usr/share/doc/fish/COPYING"
install -m 0644 "$src_dir/doc_src/license.rst" "$payload_root/usr/share/doc/fish/license.rst"
for path in \
    usr/bin/fish \
    usr/bin/fish_indent \
    usr/bin/fish_key_reader \
    usr/share/fish \
    etc/fish \
    usr/share/doc/fish/COPYING \
    usr/share/doc/fish/license.rst; do
    [[ -e "$payload_root/$path" ]] || { echo "error: install produced no $path" >&2; exit 65; }
done

xcrun --sdk iphoneos strip -xS "$payload_root/usr/bin/$PROGRAM"
for alias in fish_indent fish_key_reader; do
    ln -f "$payload_root/usr/bin/$PROGRAM" "$payload_root/usr/bin/$alias"
done
vtool -show-build "$payload_root/usr/bin/$PROGRAM" 2>/dev/null | grep -qE '^ *platform (IOS|2)$' || {
    echo "error: stripped $PROGRAM is no longer an iOS binary" >&2
    exit 65
}
for host_path in "$repository_root" "$scratch_dir" "$cargo_home" "$rustup_home" "$HOME"; do
    if strings "$payload_root/usr/bin/$PROGRAM" | grep -F "$host_path" >/dev/null; then
        echo "error: final $PROGRAM embeds Host path $host_path" >&2
        exit 65
    fi
done

{
    echo "built $PROGRAM: $ARCH, iOS $MIN_IOS minimum, runtime root '${install_prefix:-/}', $(du -h "$payload_root/usr/bin/$PROGRAM" | cut -f1 | tr -d ' ')"
    echo "system dependencies:"
    otool -L "$payload_root/usr/bin/$PROGRAM" | tail -n +2 | awk '{print "  " $1}'
    echo "weak imports:"
    nm -m "$payload_root/usr/bin/$PROGRAM" | grep 'weak external' | sed 's/^ */  /' || echo "  (none)"
} >&2

printf '%s\n' "$payload"
