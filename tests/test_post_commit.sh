#!/bin/sh
# tests/test_post_commit.sh
# 用法: sh test_post_commit.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

remote_head() {
    git ls-remote "$1" refs/heads/master 2>/dev/null | awk '{print $1}'
}

remote_branch_head() {
    remote="$1"
    branch="$2"
    git ls-remote "$remote" "refs/heads/$branch" 2>/dev/null | awk '{print $1}'
}

setup_auto_push_repo() {
    mode="$1"
    protected="$2"
    tmp=$(mktemp -d 2>/dev/null || mktemp -d -t xian-post-commit)
    remote="$tmp/remote.git"
    work="$tmp/work"
    git init -q "$remote" --bare
    git init -q "$work"
    cd "$work" || return 1
    git config user.email "test@xian-commit.test"
    git config user.name "xian-commit-test"
    git config commit.gpgsign false
    cp "$PROJECT_ROOT/hooks/pre-commit" ".git/hooks/pre-commit"
    cp "$PROJECT_ROOT/hooks/commit-msg" ".git/hooks/commit-msg"
    if [ -f "$PROJECT_ROOT/hooks/post-commit" ]; then
        cp "$PROJECT_ROOT/hooks/post-commit" ".git/hooks/post-commit"
        chmod +x ".git/hooks/post-commit"
    fi
    cp "$PROJECT_ROOT/hooks/pre-push" ".git/hooks/pre-push"
    chmod +x ".git/hooks/pre-commit" ".git/hooks/commit-msg" ".git/hooks/pre-push"
    if [ "$mode" != "__no_config__" ]; then
        mkdir -p .xian-commit
        {
            printf "push.mode=%s\n" "$mode"
            if [ -n "$protected" ]; then
                printf "branch.protected=%s\n" "$protected"
            fi
        } > .xian-commit/config
    fi
    git remote add origin "$remote"
    echo "base" > base.txt
    git add base.txt
    if [ "$mode" != "__no_config__" ]; then
        git add .xian-commit/config
    fi
    git commit -q -m "feat: 初始化测试仓库

用于建立 post-commit auto-safe 测试的 upstream。"
    git push -q -u origin master >/dev/null 2>&1
    printf "%s\n%s\n" "$work" "$tmp"
}

make_commit() {
    file="$1"
    text="$2"
    echo "$text" > "$file"
    git add "$file"
    git commit -q -m "feat: $text

用于验证 post-commit auto-safe push 行为。"
}

# 用例 1: 配置 explicit-only 时不自动 push
paths=$(setup_auto_push_repo explicit-only "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
before=$(remote_head origin)
make_commit explicit.txt "测试默认不自动推送"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "配置 explicit-only 不应自动 push" $?
cleanup_repo "$TMP"

# 用例 2: 缺失 config 时按 explicit-only 保守处理
paths=$(setup_auto_push_repo __no_config__ "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
before=$(remote_head origin)
make_commit no-config.txt "测试缺失配置不自动推送"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "缺失 config 时不应自动 push" $?
cleanup_repo "$TMP"

# 用例 3: auto-safe 条件满足时自动普通 push
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
make_commit auto-safe.txt "测试自动安全推送"
local_head=$(git rev-parse HEAD)
remote_after=$(remote_head origin)
[ "$local_head" = "$remote_after" ]
expect_pass "auto-safe 满足条件时应自动 push" $?
cleanup_repo "$TMP"

# 用例 4: 没有 upstream 时不自动 push
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t xian-post-commit-no-upstream)
REMOTE="$TMP/remote.git"
WORK="$TMP/work"
git init -q "$REMOTE" --bare
git init -q "$WORK"
cd "$WORK"
git init -q
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
cp "$PROJECT_ROOT/hooks/pre-commit" ".git/hooks/pre-commit"
cp "$PROJECT_ROOT/hooks/commit-msg" ".git/hooks/commit-msg"
if [ -f "$PROJECT_ROOT/hooks/post-commit" ]; then
    cp "$PROJECT_ROOT/hooks/post-commit" ".git/hooks/post-commit"
    chmod +x ".git/hooks/post-commit"
fi
chmod +x ".git/hooks/pre-commit" ".git/hooks/commit-msg"
mkdir -p .xian-commit
printf "push.mode=auto-safe\n" > .xian-commit/config
git remote add origin "$REMOTE"
echo "base" > base.txt
git add base.txt .xian-commit/config
git commit -q -m "feat: 初始化无 upstream 仓库

用于验证 post-commit 在没有 upstream 时跳过。"
git push -q origin master
before=$(remote_head origin)
echo "no upstream" > no-upstream.txt
git add no-upstream.txt
ERR="$TMP/no-upstream.err"
git commit -q -m "feat: 测试无 upstream

没有 upstream 时 auto-safe 不应尝试发布。" 2>"$ERR"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "no upstream 时不应自动 push" $?
expect_contains "no upstream 提示" "$(cat "$ERR" 2>/dev/null)" "没有 upstream"
cleanup_repo "$TMP"

# 用例 5: 只有 untracked 文件时仍可自动 push
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
echo "dirty" > dirty-untracked.txt
make_commit untracked.txt "测试未跟踪文件不阻断"
local_head=$(git rev-parse HEAD)
remote_after=$(remote_head origin)
[ "$local_head" = "$remote_after" ]
expect_pass "untracked 文件不应阻断 auto-safe push" $?
cleanup_repo "$TMP"

# 用例 6: tracked dirty worktree 时不自动 push
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
before=$(remote_head origin)
echo "tracked dirty" >> base.txt
make_commit tracked-dirty.txt "测试 tracked dirty 时不推送"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "tracked dirty worktree 时不应自动 push" $?
cleanup_repo "$TMP"

# 用例 7: behind / diverged 时不自动 push
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
OTHER="$TMP/other"
git clone -q "$TMP/remote.git" "$OTHER"
cd "$OTHER"
git config user.email "test@xian-commit.test"
git config user.name "xian-commit-test"
git config commit.gpgsign false
echo "remote" > remote.txt
git add remote.txt
git commit -q -m "feat: 推进远端

让本地仓库相对 upstream 落后。"
git push -q origin master
remote_before=$(remote_head "$TMP/remote.git")
cd "$WORK"
make_commit diverged.txt "测试分叉时不推送"
remote_after=$(remote_head origin)
[ "$remote_before" = "$remote_after" ]
expect_pass "behind/diverged 时不应自动 push" $?
cleanup_repo "$TMP"

# 用例 8: protected branch 时不自动 push
paths=$(setup_auto_push_repo auto-safe master)
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
before=$(remote_head origin)
make_commit protected.txt "测试保护分支不推送"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "protected branch 时不应自动 push" $?
cleanup_repo "$TMP"

# 用例 9: push.default=matching 时只推当前分支
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
mv .git/hooks/post-commit .git/hooks/post-commit.off
git checkout -q -b side
echo "side" > side.txt
git add side.txt
git commit -q -m "feat: 初始化 side 分支

用于验证 auto-safe 不推其他 matching 分支。"
git push -q -u origin side
echo "side local ahead" >> side.txt
git add side.txt
git commit -q -m "feat: 推进 side 本地分支

side 分支本地 ahead,不应被 master 的 auto-safe push 推送。"
side_before=$(remote_branch_head origin side)
git checkout -q master
git config push.default matching
mv .git/hooks/post-commit.off .git/hooks/post-commit
make_commit matching.txt "测试 matching 不误推"
side_after=$(remote_branch_head origin side)
[ "$side_before" = "$side_after" ]
expect_pass "auto-safe 不应受 push.default=matching 影响推送其他分支" $?
cleanup_repo "$TMP"

# 用例 10: ahead_count 非数字时不自动 push
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
mv .git/hooks/post-commit .git/hooks/post-commit.off
make_commit fake-count.txt "测试 ahead 计数异常"
before=$(remote_head origin)
mv .git/hooks/post-commit.off .git/hooks/post-commit
FAKE_BIN="$TMP/fake-bin"
mkdir -p "$FAKE_BIN"
GIT_BIN=$(command -v git)
cat > "$FAKE_BIN/git" <<EOF
#!/bin/sh
if [ "\$1" = "rev-list" ] && [ "\$2" = "--count" ]; then
    echo "not-a-number"
    exit 0
fi
exec "$GIT_BIN" "\$@"
EOF
chmod +x "$FAKE_BIN/git"
ERR="$TMP/fake-count.err"
PATH="$FAKE_BIN:$PATH" .git/hooks/post-commit 2>"$ERR"
after=$(remote_head origin)
[ "$before" = "$after" ]
expect_pass "ahead_count 非数字时不应自动 push" $?
expect_contains "ahead_count 异常提示" "$(cat "$ERR" 2>/dev/null)" "没有 ahead commit"
cleanup_repo "$TMP"

# 用例 11: pre-push 失败时给出 auto-safe push 失败提示但 commit 成功
paths=$(setup_auto_push_repo auto-safe "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
cat > .git/hooks/pre-push <<'EOF'
#!/bin/sh
echo "forced pre-push failure" >&2
exit 1
EOF
chmod +x .git/hooks/pre-push
echo "pre push fail" > pre-push-fail.txt
git add pre-push-fail.txt
ERR="$TMP/pre-push-fail.err"
git commit -q -m "feat: 测试 pre-push 失败

post-commit 应提示 auto-safe push 失败,但本地 commit 已完成。" 2>"$ERR"
commit_status=$?
expect_pass "pre-push 失败时 commit 仍应成功" $commit_status
expect_contains "auto-safe push 失败提示" "$(cat "$ERR" 2>/dev/null)" "auto-safe push 失败"
cleanup_repo "$TMP"

# 用例 12: never policy 阻断普通 push
paths=$(setup_auto_push_repo never "")
TMP=$(printf "%s" "$paths" | sed -n '2p')
WORK=$(printf "%s" "$paths" | sed -n '1p')
cd "$WORK"
make_commit never.txt "测试 never 策略"
git push origin master 2>err.log
expect_fail "push.mode=never 应阻断普通 push" $?
expect_contains "never 提示" "$(cat err.log 2>/dev/null)" "push.mode=never"
cleanup_repo "$TMP"

summary
