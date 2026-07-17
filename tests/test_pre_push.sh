#!/bin/sh
# tests/test_pre_push.sh
# 用法: sh test_pre_push.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

REMOTE_REPO=$(mktemp -d)
git init -q "$REMOTE_REPO.git" --bare

# 用例 1: 首次 push 应通过
TMP=$(mktemp -d)
cd "$TMP"
git init -q
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
cp "$PROJECT_ROOT/hooks/pre-push" ".git/hooks/pre-push"
chmod +x ".git/hooks/pre-push"
git remote add origin "$REMOTE_REPO.git"
echo "x" > a.txt
git add a.txt
git commit -q -m "feat: 初始提交

正文。"
git push -q origin master 2>/dev/null
expect_pass "首次 push 应通过" $?
cd /tmp || true
rm -rf "$TMP"

# 用例 2: ahead 远端(再 push 一个 commit)应通过
TMP=$(mktemp -d)
cd "$TMP"
git clone -q "$REMOTE_REPO.git" .
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
cp "$PROJECT_ROOT/hooks/pre-push" ".git/hooks/pre-push"
chmod +x ".git/hooks/pre-push"
echo "y" > b.txt
git add b.txt
git commit -q -m "feat: 第二个提交

正文。"
git push -q origin master 2>/dev/null
expect_pass "ahead 远端应通过" $?
cd /tmp || true
rm -rf "$TMP"

# 用例 3: behind 远端应拦截
# 在 TMP1 加新 commit 推到 remote,然后 TMP2(原 local)有本地 commit,尝试 push 应被 behind 拦
TMP1=$(mktemp -d)
cd "$TMP1"
git clone -q "$REMOTE_REPO.git" .
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
echo "z" > c.txt
git add c.txt
git commit -q -m "feat: 在 clone 上加 commit

正文。"
git push -q origin master 2>/dev/null
cd /tmp || true

# 回到原 remote 状态,创建一个落后于 remote 的 local repo
TMP2=$(mktemp -d)
cd "$TMP2"
git clone -q "$REMOTE_REPO.git" .
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
git reset -q --hard HEAD~1 2>/dev/null
cp "$PROJECT_ROOT/hooks/pre-push" ".git/hooks/pre-push"
chmod +x ".git/hooks/pre-push"
echo "w" > d.txt
git add d.txt
git commit -q -m "feat: 在 local 加 commit

正文。"
git push origin master 2>err.log
expect_fail "behind 远端应拦截" $?
expect_contains "错误提示提到 pull --rebase" "$(cat err.log 2>/dev/null)" "pull --rebase"
cd /tmp || true
rm -rf "$TMP1" "$TMP2"

# 用例 4: policy protected branch 应拦截
TMP=$(mktemp -d)
cd "$TMP"
git clone -q "$REMOTE_REPO.git" .
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
cp "$PROJECT_ROOT/hooks/pre-push" ".git/hooks/pre-push"
chmod +x ".git/hooks/pre-push"
mkdir -p .xian-commit
printf "branch.protected=master\n" > .xian-commit/config
echo "protected" > protected.txt
git add protected.txt
git commit -q -m "feat: 测试 protected branch

正文。"
git push origin master 2>err.log
expect_fail "policy protected branch 应拦截" $?
expect_contains "错误提示提到 protected branch" "$(cat err.log 2>/dev/null)" "protected branch"
cd /tmp || true
rm -rf "$TMP"

rm -rf "$REMOTE_REPO"

summary
