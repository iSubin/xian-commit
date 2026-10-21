#!/bin/sh
# tests/test_commit_msg.sh
# 用法: sh test_commit_msg.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

VALID_MSG="feat: 加强 bridge 状态机与产物校验

bridge 在多 agent 协作时容易状态错乱,新增状态机校验避免中途状态丢失,
重构流式输出逻辑减少内存峰值,影响 bridge 模块及其下游调用方。"

# 已完成的 merge/revert 不再有操作状态；amend 必须使用合规消息。
check_generated_amend() {
    operation=$1
    original_head=$(git rev-parse HEAD)
    original_parents=$(git log -1 --format=%P)
    test ! -e "$(git rev-parse --git-path MERGE_HEAD)" && test ! -e "$(git rev-parse --git-path REVERT_HEAD)"
    expect_pass "$operation 完成后无进行中的操作状态" $?
    echo amendment > amend-file
    git add amend-file
    git commit --amend --no-edit >amend-output 2>&1
    expect_fail "$operation 保留默认消息的 amend 被拒绝" $?
    expect_contains "$operation amend 由 message hook 拒绝" "$(cat amend-output)" "xian-commit commit-msg: commit message 不符合规范"
    test "$(git rev-parse HEAD)" = "$original_head" && git diff --cached --name-only | grep -qx amend-file
    expect_pass "$operation amend 被拒后 HEAD 不变且保留暂存内容" $?
    git commit --amend -qm "chore: 补充提交说明

维护已完成的 $operation 提交，改用合规消息并保留原有父提交。" 2>/dev/null
    expect_pass "$operation 改用合规消息后可以 amend" $?
    test "$(git log -1 --format=%P)" = "$original_parents" && git cat-file -e HEAD:amend-file
    expect_pass "$operation amend 保留父提交并纳入暂存内容" $?
}

# 用例 1: 完整规范的 message 应通过
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
echo "x" > "$TMP/a.txt"
cd "$TMP"
git add a.txt
printf '%s\n' "$VALID_MSG" | git commit -F - 2>/dev/null
expect_pass "完整规范 message 应通过" $?
git commit --amend --no-edit >/dev/null 2>&1
expect_pass "普通合规消息的 amend --no-edit 不受影响" $?
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

# 用例 12: 普通提交不能靠伪造 Merge/Revert 标题绕过校验。
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
cd "$TMP" || exit 1
for message in 'Merge nonsense' "Merge branch 'side'" "Merge remote-tracking branch 'origin/main'" 'Revert "not a real revert"'; do
    git commit --allow-empty -qm "$message" 2>/dev/null
    expect_fail "普通提交拒绝伪造标题: $message" $?
done
git commit --allow-empty -qm "$VALID_MSG"
BASE=$(git rev-parse HEAD)
git branch MERGE_HEAD
git branch REVERT_HEAD
printf 'Revert "feat: 初始化"\n\nThis reverts commit %s.\n' "$BASE" > message
git commit --allow-empty -qF message 2>/dev/null
expect_fail "完整回退模板和同名分支不能冒充 REVERT_HEAD 状态" $?
git commit --allow-empty -qm "Merge branch 'side'" 2>/dev/null
expect_fail "同名分支不能冒充 MERGE_HEAD 状态" $?
cleanup_repo "$TMP"

# 用例 13: linked worktree 的真实合并状态也能识别，且两种豁免不可混用。
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
cd "$TMP" || exit 1
git commit --allow-empty -qm "$VALID_MSG"
git checkout -qb side
echo side > side
git add side
git commit -qm "$VALID_MSG"
git worktree add -q "$TMP/linked" master
cd "$TMP/linked" || exit 1
git merge --no-ff --no-commit side >/dev/null 2>&1
expect_pass "linked worktree 准备真实合并" $?
git commit -qm 'Revert "not a real revert"' 2>/dev/null
expect_fail "合并状态不能触发 Revert 豁免" $?
git commit --no-edit >/dev/null 2>&1
expect_pass "linked worktree 的默认合并消息应通过" $?
test "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ')" = 3
expect_pass "放行后生成真实双亲合并提交" $?
check_generated_amend merge
cleanup_repo "$TMP"

# 用例 14: 回退冲突解决后，git commit 仍能使用 Git 的默认消息。
TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
cd "$TMP" || exit 1
echo base > file
git add file
git commit -qm "$VALID_MSG"
echo side > file
git add file
git commit -qm "$VALID_MSG"
REVERT_TARGET=$(git rev-parse HEAD)
REVERT_TITLE=$(git log -1 --format=%s)
echo later > file
git add file
git commit -qm "$VALID_MSG"
git revert --no-edit "$REVERT_TARGET" >/dev/null 2>&1
expect_fail "回退冲突进入待解决状态" $?
test -s "$(git rev-parse --git-path REVERT_HEAD)"
expect_pass "真实回退保存 REVERT_HEAD" $?
echo base > file
git add file
git commit -qm "Merge branch 'side'" 2>/dev/null
expect_fail "回退状态不能触发 Merge 豁免" $?
git commit --no-edit >/dev/null 2>&1
expect_pass "冲突解决后的默认回退消息应通过" $?
test "$(git log -1 --format=%s)" = "Revert \"$REVERT_TITLE\""
expect_pass "回退提交保留 Git 生成标题" $?
check_generated_amend revert
cleanup_repo "$TMP"

summary
