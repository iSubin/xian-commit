#!/bin/sh
# scripts/test/run.sh - targeted test entrypoint for formal verification
set -u

SUITE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

case "$SUITE" in
    sync-global)
        exec sh "$PROJECT_ROOT/tests/test_sync_global.sh" "$PROJECT_ROOT"
        ;;
    install)
        exec sh "$PROJECT_ROOT/tests/test_install.sh" "$PROJECT_ROOT"
        ;;
    *)
        echo "usage: sh scripts/test/run.sh <sync-global|install>" >&2
        exit 2
        ;;
esac
