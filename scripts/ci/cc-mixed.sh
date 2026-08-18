#!/usr/bin/env bash
set -euo pipefail

: "${MIXED_CLANG:?MIXED_CLANG must point to the host Clang executable}"
exec "$MIXED_CLANG" "$@"
