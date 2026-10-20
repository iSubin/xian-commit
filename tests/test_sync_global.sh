#!/bin/sh
# tests/test_sync_global.sh
# 用法: sh test_sync_global.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

expect_not_contains() {
    desc="$1"
    haystack="$2"
    needle="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        echo "  FAIL: $desc (unexpected '$needle' in output)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
}

expect_contains "SKILL.md 应包含全局守卫标记" "$(cat "$PROJECT_ROOT/SKILL.md")" "xian-commit:global-guard"
expect_contains "全局守卫应说明无工程资产时降级" "$(cat "$PROJECT_ROOT/SKILL.md")" "只应用通用提交纪律"
expect_contains "中文 README 应说明用户级安装" "$(cat "$PROJECT_ROOT/README.md")" "用户级"
expect_contains "英文 README 应说明 user-level 安装" "$(cat "$PROJECT_ROOT/README_EN.md")" "user-level"

TMP_HOME=$(mktemp -d 2>/dev/null || mktemp -d -t xian-global)
HOME="$TMP_HOME" sh "$PROJECT_ROOT/sync-global.sh" install >"$TMP_HOME/install.log" 2>&1
expect_pass "用户级同步安装应通过" $?
test -f "$TMP_HOME/.agents/skills/xian-commit/SKILL.md"
expect_pass "应创建 xian-commit SKILL.md" $?
test -L "$TMP_HOME/.agents/skills/xian-commit/SKILL.md"
expect_pass "xian-commit SKILL.md 应为软链" $?
test -x "$TMP_HOME/.agents/skills/xian-commit/install.sh"
expect_pass "应链接可执行的 install.sh" $?
test -f "$TMP_HOME/.agents/skills/xian-commit/hooks/pre-commit"
expect_pass "应链接工程级 hooks 源目录" $?
test -f "$TMP_HOME/.agents/skills/xian-open/SKILL.md"
expect_pass "应注册 xian-open" $?
test -L "$TMP_HOME/.qoder-cn/skills/xian-commit"
expect_pass "应在 Qoder 全局目录注册 xian-commit" $?
test -L "$TMP_HOME/.codex/skills/xian-open"
expect_pass "应在 Codex 全局目录注册 xian-open" $?
test -L "$TMP_HOME/.claude/skills/xian-spec"
expect_pass "应在 Claude Code 全局目录注册 xian-spec" $?
test ! -e "$TMP_HOME/.agents/skills/lark-base"
expect_pass "不应触碰非 xian skill" $?

HOME="$TMP_HOME" sh "$PROJECT_ROOT/sync-global.sh" status >"$TMP_HOME/status.log" 2>&1
expect_pass "status 应只读通过" $?
expect_contains "status 应显示 current" "$(cat "$TMP_HOME/status.log")" "current:"
HOME="$TMP_HOME" sh "$PROJECT_ROOT/sync-global.sh" verify >"$TMP_HOME/verify.log" 2>&1
expect_pass "verify 应通过" $?
expect_contains "verify 应确认守卫" "$(cat "$TMP_HOME/verify.log")" "ok: xian-commit global guard"

HOME="$TMP_HOME" sh "$PROJECT_ROOT/sync-global.sh" install >"$TMP_HOME/install-second.log" 2>&1
expect_pass "重复安装应通过" $?
expect_not_contains "重复安装不应产生冲突" "$(cat "$TMP_HOME/install-second.log")" "conflict:"

DRY_HOME=$(mktemp -d 2>/dev/null || mktemp -d -t xian-global-dry)
HOME="$DRY_HOME" sh "$PROJECT_ROOT/sync-global.sh" install --dry-run >"$DRY_HOME/dry.log" 2>&1
expect_pass "dry-run 应通过" $?
test ! -e "$DRY_HOME/.agents"
expect_pass "dry-run 不应创建 hub" $?
test ! -e "$DRY_HOME/.qoder-cn"
expect_pass "dry-run 不应创建产品目录" $?
cleanup_repo "$DRY_HOME"

CONFLICT_HOME=$(mktemp -d 2>/dev/null || mktemp -d -t xian-global-conflict)
mkdir -p "$CONFLICT_HOME/.qoder-cn/skills/xian-open"
printf 'foreign\n' > "$CONFLICT_HOME/.qoder-cn/skills/xian-open/keep.txt"
HOME="$CONFLICT_HOME" sh "$PROJECT_ROOT/sync-global.sh" install >"$CONFLICT_HOME/conflict.log" 2>&1
expect_fail "外部同名目录应阻断安装" $?
expect_contains "冲突应明确报告" "$(cat "$CONFLICT_HOME/conflict.log")" "conflict:"
expect_contains "冲突应说明未写入" "$(cat "$CONFLICT_HOME/conflict.log")" "未写入任何文件"
test -f "$CONFLICT_HOME/.qoder-cn/skills/xian-open/keep.txt"
expect_pass "冲突路径内容不应被覆盖" $?
test ! -e "$CONFLICT_HOME/.agents/skills/xian-commit"
expect_pass "冲突时不应部分写入 hub" $?
cleanup_repo "$CONFLICT_HOME"

UNINSTALL_HOME=$(mktemp -d 2>/dev/null || mktemp -d -t xian-global-uninstall)
HOME="$UNINSTALL_HOME" sh "$PROJECT_ROOT/sync-global.sh" install >"$UNINSTALL_HOME/install.log" 2>&1
expect_pass "卸载前安装应通过" $?
rm -f "$UNINSTALL_HOME/.qoder-cn/skills/xian-open"
mkdir -p "$UNINSTALL_HOME/.qoder-cn/skills/xian-open"
printf 'foreign\n' > "$UNINSTALL_HOME/.qoder-cn/skills/xian-open/keep.txt"
HOME="$UNINSTALL_HOME" sh "$PROJECT_ROOT/sync-global.sh" uninstall >"$UNINSTALL_HOME/uninstall.log" 2>&1
expect_pass "uninstall 应通过" $?
test -f "$UNINSTALL_HOME/.qoder-cn/skills/xian-open/keep.txt"
expect_pass "uninstall 应保留外部目录" $?
test ! -e "$UNINSTALL_HOME/.codex/skills/xian-commit"
expect_pass "uninstall 应移除产品级受管链接" $?
test ! -e "$UNINSTALL_HOME/.agents/skills/xian-open"
expect_pass "uninstall 应移除 hub 受管链接" $?
test ! -e "$UNINSTALL_HOME/.agents/skills/xian-commit"
expect_pass "uninstall 应移除 xian-commit hub" $?
cleanup_repo "$UNINSTALL_HOME"

ALT_HOME=$(mktemp -d 2>/dev/null || mktemp -d -t xian-global-alt)
sh "$PROJECT_ROOT/sync-global.sh" install --home "$ALT_HOME" >"$ALT_HOME/install.log" 2>&1
expect_pass "--home 应支持隔离安装" $?
test -L "$ALT_HOME/.qoder-cn/skills/xian-commit"
expect_pass "--home 应写入指定目录" $?
cleanup_repo "$ALT_HOME"

cleanup_repo "$TMP_HOME"

summary
