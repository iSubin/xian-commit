#!/bin/sh
# tests/test_commit_msg.sh
# 用法: sh test_commit_msg.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

VALID_MSG="feat: 加强 bridge 状态机与产物校验

bridge 在多 agent 协作时容易状态错乱,新增状态机校验避免中途状态丢失,
重构流式输出逻辑减少内存峰值,影响 bridge 模块及其下游调用方。"

# 用例 1: 完整规范的 message 应通过
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf '%s\n' "$VALID_MSG" | git commit -F - 2>/dev/null
expect_pass "完整规范 message 应通过" $?
cleanup_repo "$TMP"

# 用例 2: 缺正文应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "feat: 加强 bridge 状态机\n" | git commit -F - 2>/dev/null
expect_fail "缺正文应拦截" $?
cleanup_repo "$TMP"

# 用例 3: 缺 type 前缀应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "加强 bridge 状态机\n\n正文说明\n" | git commit -F - 2>/dev/null
expect_fail "缺 type 前缀应拦截" $?
cleanup_repo "$TMP"

# 用例 4: 重复 type 前缀应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "feat: feat 加强 bridge\n\n正文说明\n" | git commit -F - 2>/dev/null
expect_fail "重复 type 前缀应拦截" $?
cleanup_repo "$TMP"

# 用例 5: 含 emoji 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "feat: 加强 bridge 🚀\n\n正文说明\n" | git commit -F - 2>/dev/null
expect_fail "含 emoji 应拦截" $?
cleanup_repo "$TMP"

# 用例 6: 英文标题应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "feat: improve bridge state machine\n\nbody\n" | git commit -F - 2>/dev/null
expect_fail "英文标题应拦截" $?
cleanup_repo "$TMP"

# 用例 7: type 不在白名单应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "unknown: 加强 bridge\n\n正文\n" | git commit -F - 2>/dev/null
expect_fail "type 不在白名单应拦截" $?
cleanup_repo "$TMP"

# 用例 8: 标题非纯中文(英文为主)应拦截
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "fix: update bridge\n\n正文\n" | git commit -F - 2>/dev/null
expect_fail "标题非纯中文应拦截" $?
cleanup_repo "$TMP"

# 用例 9: 所有合法 type 应通过
for type in feat fix refactor docs test chore; do
    TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
    echo "x" > "$TMP/a.txt"
    cd "$TMP"
    git add a.txt
    printf "%s: 测试%s类型\n\n正文说明\n" "$type" "$type" | git commit -F - 2>/dev/null
    expect_pass "type=$type 应通过" $?
    cleanup_repo "$TMP"
done

# 用例 10: 标题包含数字/标点符号 + 中文应通过(允许混合)
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "fix: 修复 issue #123 的解析问题\n\n正文说明\n" | git commit -F - 2>/dev/null
expect_pass "中文标题含数字标点应通过" $?
cleanup_repo "$TMP"

# 用例 11: policy message 规则应允许自定义 type、英文标题、无正文
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
mkdir -p "$TMP/.xian-commit"
cat > "$TMP/.xian-commit/config" <<'EOF'
message.types=ci
message.title_language=any
message.body_required=false
EOF
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf "ci: update pipeline\n" | git commit -F - 2>/dev/null
expect_pass "policy message 规则应生效" $?
cleanup_repo "$TMP"

summary
