#!/bin/sh
# tests/lib.sh - 测试辅助函数库,被各 test_*.sh 文件 source

PASS_COUNT=0
FAIL_COUNT=0

# expect_pass <desc> <exit_code>
# 期望 exit_code 为 0(命令应成功)
expect_pass() {
    desc="$1"
    result="$2"
    if [ "$result" -eq 0 ]; then
        echo "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $desc (expected pass, got exit $result)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# expect_fail <desc> <exit_code>
# 期望 exit_code 非 0(命令应被拒绝)
expect_fail() {
    desc="$1"
    result="$2"
    if [ "$result" -ne 0 ]; then
        echo "  PASS: $desc (correctly rejected)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $desc (should have been rejected)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# expect_contains <desc> <haystack> <needle>
# 期望 haystack 包含 needle 字符串
expect_contains() {
    desc="$1"
    haystack="$2"
    needle="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $desc (expected '$needle' in output)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# setup_repo <project_root> <hook_name...>
# 创建临时 git repo 并装指定 hook
# 用 echo 返回临时 repo 路径
setup_repo() {
    project_root="$1"
    shift
    tmp=$(mktemp -d 2>/dev/null || mktemp -d -t xian)
    cd "$tmp" || return 1
    git init -q
    git config user.email "test@xian-commit.test"
    git config user.name "xian-commit-test"
    git config commit.gpgsign false
    for hook_name in "$@"; do
        if [ -f "$project_root/hooks/$hook_name" ]; then
            cp "$project_root/hooks/$hook_name" ".git/hooks/$hook_name"
            chmod +x ".git/hooks/$hook_name"
        fi
    done
    echo "$tmp"
}

# cleanup_repo <tmp_path>
cleanup_repo() {
    cd /tmp || true
    rm -rf "$1" 2>/dev/null || true
}

# summary - 打印并返回测试结果(0=全过)
summary() {
    echo "  Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
    [ "$FAIL_COUNT" -eq 0 ]
}
