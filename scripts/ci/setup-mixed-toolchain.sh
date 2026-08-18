#!/usr/bin/env bash
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${THEOS:?THEOS must point to the RootHide Theos checkout}"

llvm_bin=${MIXED_LLVM_BIN:-}
if [[ -z "$llvm_bin" ]]; then
    clang_path=$(command -v clang || true)
    test -n "$clang_path" || { echo 'host clang is required' >&2; exit 1; }
    llvm_bin=$(dirname "$clang_path")
fi

clang_path="$llvm_bin/clang"
clangxx_path="$llvm_bin/clang++"
test -x "$clang_path" || { echo "missing host compiler: $clang_path" >&2; exit 1; }
test -x "$clangxx_path" || { echo "missing host compiler: $clangxx_path" >&2; exit 1; }

mixed_ld=${MIXED_LD:-}
if [[ -z "$mixed_ld" && -d "$THEOS/toolchain" ]]; then
    mixed_ld=$(find -L "$THEOS/toolchain" -type f -path '*/iphone/bin/ld' -perm -111 -print -quit || true)
fi
# RootHide Theos ships a downloaded Linux linker in the local mixed setup.
# macOS runners use Xcode's native Mach-O linker instead; the cloned Theos
# checkout intentionally does not contain a platform toolchain.
if [[ -z "$mixed_ld" ]] && command -v xcrun >/dev/null 2>&1; then
    mixed_ld=$(xcrun --sdk iphoneos --find ld 2>/dev/null || true)
fi
if [[ -z "$mixed_ld" ]]; then
    mixed_ld=$(command -v ld || true)
fi
test -n "$mixed_ld" && test -x "$mixed_ld" || {
    echo "missing a usable Mach-O linker" >&2
    exit 1
}

if [[ -n "${MIXED_LLVM_VERSION:-}" ]]; then
    version=$($clang_path --version | head -n 1)
    case "$version" in
        *"$MIXED_LLVM_VERSION"*) ;;
        *)
            echo "expected host LLVM $MIXED_LLVM_VERSION, got: $version" >&2
            exit 1
            ;;
    esac
fi

printf 'MIXED_CLANG=%s\n' "$clang_path"
printf 'MIXED_CLANGXX=%s\n' "$clangxx_path"
printf 'MIXED_LD=%s\n' "$mixed_ld"
printf 'TARGET_CC=%s\n' "$project_root/scripts/ci/cc-mixed.sh"
printf 'TARGET_CXX=%s\n' "$project_root/scripts/ci/cxx-mixed.sh"
printf 'TARGET_LD=%s\n' "$project_root/scripts/ci/cxx-mixed.sh"
