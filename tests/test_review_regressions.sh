#!/bin/sh
PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP" || exit 1
mkdir .xian-harness
expect_contains "其他工具目录不是 policy" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "policy=absent"
expect_contains "其他工具目录不是 hook 安装证明" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "hooks=unverified"
sh "$PROJECT_ROOT/install.sh" skill >/dev/null
expect_contains "仅安装 skill 有 policy" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "policy=present"
expect_contains "仅安装 skill 不宣称 hooks 生效" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "hooks=unverified"
sh "$PROJECT_ROOT/install.sh" hooks >/dev/null
expect_contains "完整安装验证实际 hook 内容" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "hooks=current"
mkdir sub
cd sub || exit 1
expect_contains "子目录检查定位 Git 根目录" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "hooks=current"
cd .. || exit 1
mkdir custom-hooks
git config core.hooksPath custom-hooks
expect_contains "切换有效 hook 路径后不误报" "$(sh "$PROJECT_ROOT/references/check-project.sh")" "hooks=unverified"
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP" || exit 1
echo secret > old.env
git add old.env
git commit -qm initial
cp "$PROJECT_ROOT/hooks/pre-commit" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
git rm -q old.env
git commit -qm cleanup
expect_pass "可以提交删除已跟踪敏感文件" $?
echo key > private.pem
git add private.pem
git commit -qm blocked 2>/dev/null
expect_fail "PEM 私钥应被拦截" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT" commit-msg)
cd "$TMP" || exit 1
for emoji in '🇨🇳' '⭐' '‼' '1️⃣'; do
    printf 'fix: 修复问题 %s\n\n说明原因。\n' "$emoji" > message
    sh "$PROJECT_ROOT/hooks/commit-msg" message 2>/dev/null
    expect_fail "常见 emoji $emoji 被拦截" $?
done
echo base > base
git add base
git commit -qm "feat: 初始化

验证合并操作。"
git checkout -qb side
echo side > side
git add side
git commit -qm "feat: 侧分支

增加独立文件。"
SIDE=$(git rev-parse HEAD)
git checkout -q master
echo main > main
git add main
git commit -qm "feat: 主分支

建立合并分叉。"
git merge --no-edit side >/dev/null 2>&1
expect_pass "Git 默认 merge message 应通过" $?
git revert --no-edit "$SIDE" >/dev/null 2>&1
expect_pass "Git 默认 revert message 应通过" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT" pre-push post-commit)
cd "$TMP" || exit 1
git -c init.defaultBranch=master init --bare -q "$TMP/remote.git"
git remote add origin "$TMP/remote.git"
mkdir .xian-commit
printf 'push.mode=explicit-only\n' > .xian-commit/config
echo base > base
git add base .xian-commit/config
git commit -qm initial
git push -qu origin master
OTHER=$(printf 'remote collision\n' | git commit-tree HEAD^{tree} -p HEAD)
git push -q origin "$OTHER:refs/heads/foo/master" "$OTHER:refs/tags/master"
sh "$PROJECT_ROOT/hooks/pre-push" </dev/null 2>"$TMP/pre-push.err"
expect_pass "同名 tag 和末段同名分支不影响 pre-push" $?
printf 'push.mode=auto-safe\n' > .xian-commit/config
git add .xian-commit/config
git commit -qm "enable auto push" 2>"$TMP/post-commit.err"
expect_pass "存在同名远端 ref 时 commit 仍成功" $?
REMOTE=$(git ls-remote origin refs/heads/master | awk '{print $1}')
[ "$REMOTE" = "$(git rev-parse HEAD)" ]
expect_pass "auto-safe 只比较精确远端分支" $?
cleanup_repo "$TMP"
summary
