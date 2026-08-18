#!/usr/bin/env bash
# Build the local package with the persistent mixed Theos toolchain.
# Usage: scripts/build.sh [rootless|roothide]
# Override PACKAGE_VERSION, THEOS, TARGET_CC, TARGET_CXX, or TARGET_LD
# through the environment if needed; defaults target this machine.
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

scheme=${1:-rootless}
case "$scheme" in
    rootless|roothide) ;;
    *) echo "usage: $0 [rootless|roothide]" >&2; exit 1 ;;
esac

: "${PACKAGE_VERSION:=$(awk '$1 == "Version:" && NF == 2 { print $2 }' control)}"

export THEOS=${THEOS:-/home/nick/roothide-theos}

# The host compiler supplies the arm64e/PAC00 ABI; Theos supplies the iOS
# SDK and Mach-O linker. Callers may still override any TARGET_* variable.
if [[ -z "${TARGET_CC:-}" || -z "${TARGET_CXX:-}" || -z "${TARGET_LD:-}" ]]; then
    export MIXED_CLANG=${MIXED_CLANG:-$(command -v clang)}
    export MIXED_CLANGXX=${MIXED_CLANGXX:-$(command -v clang++)}
    export MIXED_LD=${MIXED_LD:-$(find -L "$THEOS/toolchain" -type f -path '*/iphone/bin/ld' -perm -111 -print -quit)}
    test -n "$MIXED_CLANG" -a -x "$MIXED_CLANG"
    test -n "$MIXED_CLANGXX" -a -x "$MIXED_CLANGXX"
    test -n "$MIXED_LD" -a -x "$MIXED_LD"
fi

export TARGET_CC=${TARGET_CC:-"$project_root/scripts/ci/cc-mixed.sh"}
export TARGET_CXX=${TARGET_CXX:-"$project_root/scripts/ci/cxx-mixed.sh"}
export TARGET_LD=${TARGET_LD:-"$project_root/scripts/ci/cxx-mixed.sh"}
export THEOS_PACKAGE_SCHEME=$scheme

# ARCHS carries both slices for every scheme: A11 devices (iPhone 8/X)
# execute arm64 only and reject arm64e-only Mach-Os.
make clean package FINALPACKAGE=1 DEBUG=0 \
    ARCHS='arm64 arm64e' \
    ABI_SUFFIX= \
    PACKAGE_VERSION="$PACKAGE_VERSION"
