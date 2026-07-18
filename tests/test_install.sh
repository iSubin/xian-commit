#!/bin/sh
# tests/test_install.sh
# 用法: sh test_install.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
sh "$PROJECT_ROOT/install.sh" >/tmp/xian-install.log 2>&1
expect_pass "默认 install 应通过" $?
test -f "$TMP/.codex/skills/xian-commit/SKILL.md"
expect_pass "默认 install 应安装 Codex SKILL.md" $?
test -f "$TMP/.codex/skills/xian-commit/prompts/commit-message.md"
expect_pass "默认 install 应安装 Codex prompt" $?
test -f "$TMP/.codex/skills/xian-commit/references/install-lifecycle-template.sh"
expect_pass "默认 install 应安装 Codex reference template" $?
test -f "$TMP/.claude/skills/xian-commit/SKILL.md"
expect_pass "默认 install 应安装 Claude Code SKILL.md" $?
test -f "$TMP/.claude/skills/xian-commit/prompts/commit-message.md"
expect_pass "默认 install 应安装 Claude Code prompt" $?
test -f "$TMP/.claude/skills/xian-commit/references/install-lifecycle-template.sh"
expect_pass "默认 install 应安装 Claude Code reference template" $?
test -f "$TMP/.xian-commit/config"
expect_pass "默认 install 应创建 policy config" $?
expect_contains "默认 config 应启用 auto-safe" "$(cat "$TMP/.xian-commit/config")" "push.mode=auto-safe"
test -x "$TMP/.git/hooks/pre-commit"
expect_pass "默认 install 应安装 pre-commit" $?
test -x "$TMP/.git/hooks/commit-msg"
expect_pass "默认 install 应安装 commit-msg" $?
test -x "$TMP/.git/hooks/post-commit"
expect_pass "默认 install 应安装 post-commit" $?
test -x "$TMP/.git/hooks/pre-push"
expect_pass "默认 install 应安装 pre-push" $?
sh "$PROJECT_ROOT/install.sh" verify >/tmp/xian-install-verify.log 2>&1
expect_pass "verify 应通过完整安装自检" $?
sh "$PROJECT_ROOT/install.sh" status >/tmp/xian-install-status.log 2>&1
expect_pass "status 应通过只读检查" $?
expect_contains "status 应显示 Codex skill current" "$(cat /tmp/xian-install-status.log)" "current: codex skill"
expect_contains "status 应显示 Claude Code skill current" "$(cat /tmp/xian-install-status.log)" "current: claude skill"
expect_contains "status 应显示 current hook" "$(cat /tmp/xian-install-status.log)" "current: hook pre-commit"
rm -f "$TMP/.claude/skills/xian-commit/SKILL.md"
sh "$PROJECT_ROOT/install.sh" verify >/tmp/xian-install-verify-missing-claude.log 2>&1
expect_fail "verify 应发现 Claude Code skill 缺失" $?
sh "$PROJECT_ROOT/install.sh" update >/tmp/xian-install-update.log 2>&1
expect_pass "update 应通过" $?
test -f "$TMP/.codex/skills/xian-commit/SKILL.md"
expect_pass "update 应保留 Codex SKILL.md" $?
test -f "$TMP/.claude/skills/xian-commit/SKILL.md"
expect_pass "update 应恢复 Claude Code SKILL.md" $?
sh "$PROJECT_ROOT/install.sh" uninstall >/tmp/xian-install-uninstall.log 2>&1
expect_pass "uninstall 应通过" $?
test ! -d "$TMP/.codex/skills/xian-commit"
expect_pass "uninstall 应删除 Codex skill 目录" $?
test ! -d "$TMP/.claude/skills/xian-commit"
expect_pass "uninstall 应删除 Claude Code skill 目录" $?
test ! -f "$TMP/.xian-commit/policy.example.conf"
expect_pass "uninstall 应删除 policy.example" $?
test -f "$TMP/.xian-commit/config"
expect_pass "uninstall 应保留用户 config" $?
test ! -f "$TMP/.git/hooks/pre-commit"
expect_pass "uninstall 应删除自身 hook" $?
test ! -f "$TMP/.git/hooks/post-commit"
expect_pass "uninstall 应删除 post-commit" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
printf '#!/bin/sh\n# original project hook\nexit 0\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
sh "$PROJECT_ROOT/install.sh" hooks >"$TMP/install-hooks-first.log" 2>&1
expect_pass "首次 hooks 安装应通过" $?
expect_contains "首次安装应备份原始 hook" "$(cat .git/hooks/pre-commit.pre-xian-commit.bak)" "original project hook"
printf '#!/bin/sh\n# intermediate hook\nexit 0\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
sh "$PROJECT_ROOT/install.sh" update >"$TMP/install-hooks-update.log" 2>&1
expect_pass "重复 update 应通过" $?
expect_contains "重复更新不应覆盖首份原始 hook 备份" "$(cat .git/hooks/pre-commit.pre-xian-commit.bak)" "original project hook"
diff -q "$PROJECT_ROOT/hooks/pre-commit" .git/hooks/pre-commit >/dev/null 2>&1
expect_pass "重复更新仍应安装当前 pre-commit" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
sh "$PROJECT_ROOT/install.sh" >"$TMP/install-custom-types.log" 2>&1
expect_pass "自定义类型前的完整安装应通过" $?
cat > .xian-commit/config <<'EOF'
push.mode=explicit-only
message.types=ci
message.title_language=any
message.body_required=false
EOF
sh "$PROJECT_ROOT/install.sh" verify >"$TMP/verify-custom-types.log" 2>&1
expect_pass "verify 不应依赖项目允许 docs 类型" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
mkdir -p .xian-commit
printf "push.mode=auto-safe\n" > .xian-commit/config
sh "$PROJECT_ROOT/install.sh" skill >/tmp/xian-install-skill.log 2>&1
expect_pass "skill install 应通过" $?
expect_contains "已有 policy 不应被覆盖" "$(cat "$TMP/.xian-commit/config")" "push.mode=auto-safe"
test -f "$TMP/.codex/skills/xian-commit/SKILL.md"
expect_pass "skill install 应安装 Codex skill" $?
test -f "$TMP/.claude/skills/xian-commit/SKILL.md"
expect_pass "skill install 应安装 Claude Code skill" $?
test ! -f "$TMP/.git/hooks/pre-commit"
expect_pass "skill install 不应安装 hooks" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
echo "base" > "$TMP/base.txt"
git -C "$TMP" add base.txt
git -C "$TMP" commit -qm "initial commit"
WORKTREE_PARENT=$(mktemp -d 2>/dev/null || mktemp -d -t xian-worktree)
WORKTREE="$WORKTREE_PARENT/linked"
git -C "$TMP" worktree add -q -b linked "$WORKTREE"
(cd "$WORKTREE" && sh "$PROJECT_ROOT/install.sh" >"$WORKTREE/install.log" 2>&1)
expect_pass "linked worktree 中完整安装应通过" $?
test -x "$TMP/.git/hooks/pre-commit"
expect_pass "linked worktree 应安装到共享 hooks 目录" $?
WORKTREE_GIT_DIR=$(git -C "$WORKTREE" rev-parse --git-dir)
test ! -f "$WORKTREE_GIT_DIR/hooks/pre-commit"
expect_pass "linked worktree 私有 git-dir 下不应写入 hooks" $?
(cd "$WORKTREE" && sh "$PROJECT_ROOT/install.sh" verify >"$WORKTREE/verify.log" 2>&1)
expect_pass "linked worktree verify 应检查实际生效的 hooks" $?
echo "bad" > "$WORKTREE/bad.txt"
git -C "$WORKTREE" add bad.txt
git -C "$WORKTREE" commit -m "bad" 2>"$WORKTREE/commit.err"
expect_fail "linked worktree 实际提交应触发已安装 hook" $?
git -C "$TMP" worktree remove --force "$WORKTREE"
cleanup_repo "$WORKTREE_PARENT"
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
mkdir -p .husky
printf '#!/bin/sh\n# existing husky hook\nexit 0\n' > .husky/pre-commit
chmod +x .husky/pre-commit
git config core.hooksPath .husky
sh "$PROJECT_ROOT/install.sh" >"$TMP/custom-hooks-install.log" 2>&1
expect_fail "core.hooksPath 场景下默认安装应明确拒绝" $?
expect_contains "hooks 安装拒绝应提到 core.hooksPath" "$(cat "$TMP/custom-hooks-install.log")" "core.hooksPath"
expect_contains "现有自定义 hook 不应被覆盖" "$(cat .husky/pre-commit)" "existing husky hook"
test ! -f "$TMP/.git/hooks/pre-commit"
expect_pass "core.hooksPath 安装失败时不应写入默认 hooks" $?
test ! -d "$TMP/.codex/skills/xian-commit"
expect_pass "core.hooksPath 安装失败时不应部分写入 Skill" $?
cleanup_repo "$TMP"

TMP=$(setup_repo "$PROJECT_ROOT")
cd "$TMP"
sh "$PROJECT_ROOT/install.sh" >"$TMP/install-before-custom-hooks.log" 2>&1
expect_pass "设置 core.hooksPath 前的完整安装应通过" $?
mkdir -p .husky
git config core.hooksPath .husky
sh "$PROJECT_ROOT/install.sh" verify >"$TMP/custom-hooks-verify.log" 2>&1
expect_fail "core.hooksPath 启用后 verify 应拒绝假阳性" $?
expect_contains "verify 拒绝应提到 core.hooksPath" "$(cat "$TMP/custom-hooks-verify.log")" "core.hooksPath"
cleanup_repo "$TMP"

summary
