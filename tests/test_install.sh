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

summary
