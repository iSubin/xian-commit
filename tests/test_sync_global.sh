#!/bin/sh
PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"
TMP=$(mktemp -d)
TARGET="$TMP/home with spaces"
mkdir "$TARGET"
SYNC="$PROJECT_ROOT/sync-global.sh"
run() { sh "$SYNC" "$@" --home "$TARGET" >"$TMP/output" 2>&1; }
run install --dry-run
expect_pass "dry-run 可通过" $?
test ! -e "$TARGET/.agents"
expect_pass "dry-run 不写用户目录" $?
run install
expect_pass "全局安装通过" $?
test -L "$TARGET/.agents/skills/xian-commit"
expect_pass "hub 使用目录软链而不是 SKILL.md 文件软链" $?
test ! -L "$TARGET/.agents/skills/xian-commit/SKILL.md"
expect_pass "发现器读取的 SKILL.md 是真实文件" $?
for product in codex claude qoder-cn qoder qoderwork; do
    test -f "$TARGET/.$product/skills/xian-commit/SKILL.md"
    expect_pass "$product 入口可解析 Skill" $?
done
test ! -e "$TARGET/.agents/skills/xian-open"
expect_pass "不导出工程中其他治理 Skills" $?
test -f "$TARGET/.agents/xian-commit-sync.tsv"
expect_pass "安装记录持久归属清单" $?
run install
expect_pass "重复安装幂等" $?
run verify
expect_pass "链接校验通过" $?
expect_contains "不把链接校验等同运行时发现" "$(cat "$TMP/output")" "runtime discovery is NOT checked"
run uninstall --dry-run
expect_pass "卸载预演通过" $?
test -f "$TARGET/.agents/skills/xian-commit/SKILL.md"
expect_pass "卸载预演保留文件" $?
run uninstall
expect_pass "卸载通过" $?
test ! -e "$TARGET/.agents/skills/xian-commit"
expect_pass "卸载移除受管 hub" $?

# 有冲突时不留下部分安装。
mkdir -p "$TARGET/.claude/skills/xian-commit"
printf keep > "$TARGET/.claude/skills/xian-commit/user-file"
run install
expect_fail "真实外部目录阻止安装" $?
test ! -e "$TARGET/.agents/skills/xian-commit"
expect_pass "冲突预检不部分写入" $?
mv "$TARGET/.claude/skills/xian-commit" "$TMP/user-skill"

# 手工创建的同目标软链不得冒充受管资源。
ln -s "$PROJECT_ROOT" "$TARGET/.agents/skills/xian-commit"
ln -s ../../.agents/skills/xian-commit "$TARGET/.claude/skills/xian-commit"
run install
expect_pass "现有同目标入口作为 borrowed 使用" $?
run uninstall
expect_pass "带手工入口的卸载通过" $?
test -L "$TARGET/.claude/skills/xian-commit"
expect_pass "保留手工同目标链接" $?
test -f "$TARGET/.agents/skills/xian-commit/SKILL.md"
expect_pass "保留手工 hub 内容" $?

# 只有产品入口为手工链接时，也不能删掉其依赖的受管 hub。
TARGET="$TMP/borrowed-endpoint"
mkdir -p "$TARGET/.claude/skills"
ln -s ../../.agents/skills/xian-commit "$TARGET/.claude/skills/xian-commit"
run install
expect_pass "手工入口可以借用新创建的 hub" $?
run uninstall
expect_pass "共享 hub 卸载保守保留" $?
test -f "$TARGET/.claude/skills/xian-commit/SKILL.md"
expect_pass "不会把手工产品入口变成断链" $?
unlink "$TARGET/.claude/skills/xian-commit"
run uninstall
expect_pass "手工依赖移除后可完成清理" $?
test ! -L "$TARGET/.agents/skills/xian-commit"
expect_pass "不再需要的受管 hub 可移除" $?

# 独立安装源搬迁、源文件删除以及无源卸载。
TARGET="$TMP/relocation home"
mkdir "$TARGET" "$TMP/source one"
for asset in sync-global.sh SKILL.md install.sh prompts references hooks policy.example.conf; do
    cp -R "$PROJECT_ROOT/$asset" "$TMP/source one/$asset"
done
SYNC="$TMP/source one/sync-global.sh"
run install
expect_pass "隔离源首次安装通过" $?
mv "$TMP/source one" "$TMP/source two"
SYNC="$TMP/source two/sync-global.sh"
run verify
expect_fail "搬迁后校验报告旧链接" $?
run install
expect_pass "搬迁后凭归属清单重连" $?
run verify
expect_pass "搬迁后重新校验通过" $?
mv "$TMP/source two/SKILL.md" "$TMP/saved-skill"
run verify
expect_fail "源 Skill 删除不会被漏报" $?
run uninstall
expect_pass "源 Skill 删除后仍能依据清单卸载" $?
test ! -L "$TARGET/.codex/skills/xian-commit"
expect_pass "源删除后不留产品悬空链接" $?
mv "$TMP/saved-skill" "$TMP/source two/SKILL.md"
run install
expect_pass "恢复源后重新安装" $?
run install --agents codex,claude
expect_pass "缩减产品选择会清理旧受管入口" $?
test ! -L "$TARGET/.qoder/skills/xian-commit"
expect_pass "退役入口不会遗留" $?
run verify --agents codex,claude
expect_pass "选定产品校验通过" $?
unlink "$TARGET/.codex/skills/xian-commit"
mkdir "$TARGET/.codex/skills/xian-commit"
printf keep > "$TARGET/.codex/skills/xian-commit/user-file"
run install --agents codex,claude
expect_fail "用户替换受管入口后不覆盖" $?
run uninstall
expect_pass "卸载允许保留用户替换资源" $?
test -f "$TARGET/.codex/skills/xian-commit/user-file"
expect_pass "卸载保留替换后的文件" $?

# 旧版本无清单，必须显式确认接管；不接管其他 Skill。
TARGET="$TMP/legacy"
mkdir -p "$TARGET/.agents/skills/xian-commit"
for asset in SKILL.md install.sh prompts references hooks policy.example.conf; do
    ln -s "$PROJECT_ROOT/$asset" "$TARGET/.agents/skills/xian-commit/$asset"
done
printf 'xian-commit user-level skill\n' > "$TARGET/.agents/skills/xian-commit/.xian-global-managed"
SYNC="$PROJECT_ROOT/sync-global.sh"
run install
expect_fail "旧安装不静默猜测归属" $?
run install --adopt-legacy
expect_pass "显式接管旧安装" $?
run verify
expect_pass "接管后清单校验通过" $?
run uninstall
expect_pass "接管后卸载通过" $?
test ! -e "$TARGET/.agents/skills/xian-commit"
expect_pass "接管后 hub 完整移除" $?

TARGET="$TMP/parent-link"
mkdir -p "$TARGET" "$TMP/external"
ln -s "$TMP/external" "$TARGET/.agents"
run install
expect_fail "不通过父目录软链写入其他位置" $?
test ! -e "$TMP/external/skills"
expect_pass "外部位置保持不变" $?
cleanup_repo "$TMP"
summary
