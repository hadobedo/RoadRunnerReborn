#!/usr/bin/env bash
# Build the local package with the persistent mixed Theos toolchain.
# Usage: scripts/build.sh [rootless|roothide]
# Override PACKAGE_VERSION, THEOS, TARGET_CC, TARGET_CXX, or TARGET_LD
# through the environment if needed; defaults target this machine.
set -euo pipefail

cd "$(dirname "$0")/.."

scheme=${1:-rootless}
case "$scheme" in
    rootless|roothide) ;;
    *) echo "usage: $0 [rootless|roothide]" >&2; exit 1 ;;
esac

: "${PACKAGE_VERSION:=$(awk '$1 == "Version:" && NF == 2 { print $2 }' control)}"

export TARGET_CC=${TARGET_CC:-/home/nick/Documents/iOS/cc-mixed}
export TARGET_CXX=${TARGET_CXX:-/home/nick/Documents/iOS/cxx-mixed}
export TARGET_LD=${TARGET_LD:-/home/nick/Documents/iOS/cxx-mixed}
export THEOS=${THEOS:-/home/nick/roothide-theos}
export THEOS_PACKAGE_SCHEME=$scheme

# ARCHS carries both slices for every scheme: A11 devices (iPhone 8/X)
# execute arm64 only and reject arm64e-only Mach-Os.
make clean package FINALPACKAGE=1 DEBUG=0 \
    ARCHS='arm64 arm64e' \
    ABI_SUFFIX= \
    PACKAGE_VERSION="$PACKAGE_VERSION"
