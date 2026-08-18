#!/usr/bin/env bash
set -euo pipefail

: "${MIXED_CLANGXX:?MIXED_CLANGXX must point to the host Clang++ executable}"
: "${MIXED_LD:?MIXED_LD must point to the Theos Mach-O linker}"
exec "$MIXED_CLANGXX" -fuse-ld="$MIXED_LD" "$@"
