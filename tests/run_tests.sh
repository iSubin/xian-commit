#!/bin/sh
# tests/run_tests.sh - 运行所有 test_*.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=""

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [ -f "$test_file" ] || continue
    echo ""
    echo "=== Running $(basename "$test_file") ==="
    sh "$test_file" "$PROJECT_ROOT"
    if [ $? -eq 0 ]; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_FILES="$FAILED_FILES $(basename "$test_file")"
    fi
done

echo ""
echo "==================================="
echo "Test files: $((TOTAL_PASS + TOTAL_FAIL)) total, $TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo "Failed files:$FAILED_FILES"
    exit 1
fi
echo "All tests passed."
