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
if [[ -z "$mixed_ld" ]]; then
    mixed_ld=$(find -L "$THEOS/toolchain" -type f -path '*/iphone/bin/ld' -perm -111 -print -quit)
fi
test -n "$mixed_ld" && test -x "$mixed_ld" || {
    echo "missing Theos Mach-O linker under $THEOS/toolchain" >&2
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
