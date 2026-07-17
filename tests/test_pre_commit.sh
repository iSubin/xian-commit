#!/bin/sh
# tests/test_pre_commit.sh
# 用法: sh test_pre_commit.sh <project_root>

PROJECT_ROOT="$1"
. "$PROJECT_ROOT/tests/lib.sh"

# 用例 1: 普通文件应通过
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit commit-msg)
echo "print('hello')" > "$TMP/a.py"
cd "$TMP"
git add a.py
git commit -m "feat: 测试普通文件

普通 Python 文件,不应被拦截。" 2>/dev/null
expect_pass "普通 Python 文件应通过" $?
cleanup_repo "$TMP"

# 用例 2: .xian-relay/ 路径应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
mkdir -p "$TMP/.xian-relay/changes/abc"
echo "approved: true" > "$TMP/.xian-relay/changes/abc/gate.md"
cd "$TMP"
git add .xian-relay/changes/abc/gate.md
git commit -m "feat: 测试 xian-relay 路径

应被 pre-commit 拦截。" 2>err.log
expect_fail ".xian-relay/ 路径应拦截" $?
expect_contains "错误提示提到 xian-relay" "$(cat err.log 2>/dev/null)" "xian-relay"
cleanup_repo "$TMP"

# 用例 3: *_tmp.py 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
echo "debug" > "$TMP/debug_tmp.py"
cd "$TMP"
git add debug_tmp.py
git commit -m "feat: 测试临时文件

应被拦截。" 2>/dev/null
expect_fail "*_tmp.py 应拦截" $?
cleanup_repo "$TMP"

# 用例 4: .DS_Store 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
echo "data" > "$TMP/.DS_Store"
cd "$TMP"
git add .DS_Store
git commit -m "feat: 测试 DS_Store

应被拦截。" 2>/dev/null
expect_fail ".DS_Store 应拦截" $?
cleanup_repo "$TMP"

# 用例 5: *.env 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
echo "SECRET=abc" > "$TMP/prod.env"
cd "$TMP"
git add prod.env
git commit -m "feat: 测试 env 文件

应被拦截。" 2>/dev/null
expect_fail "*.env 应拦截" $?
cleanup_repo "$TMP"

# 用例 6: id_rsa 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
echo "PRIVATE KEY DATA" > "$TMP/id_rsa"
cd "$TMP"
git add id_rsa
git commit -m "feat: 测试 SSH 私钥

应被拦截。" 2>/dev/null
expect_fail "id_rsa 应拦截" $?
cleanup_repo "$TMP"

# 用例 7: *.swp 应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
echo "swap" > "$TMP/.a.py.swp"
cd "$TMP"
git add .a.py.swp
git commit -m "feat: 测试 swap 文件

应被拦截。" 2>/dev/null
expect_fail "*.swp 应拦截" $?
cleanup_repo "$TMP"

# 用例 8: 合法的 debug.py 不应误杀(验证黑名单不宽)
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit commit-msg)
echo "x" > "$TMP/debug_helper.py"
cd "$TMP"
git add debug_helper.py
git commit -m "feat: 测试非临时 debug 文件

合法文件,应通过。" 2>/dev/null
expect_pass "debug_helper.py 不应被误杀" $?
cleanup_repo "$TMP"

# 用例 9: policy path.deny 追加规则应拦截
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit)
mkdir -p "$TMP/.xian-commit" "$TMP/generated"
printf "path.deny=generated/**\n" > "$TMP/.xian-commit/config"
echo "artifact" > "$TMP/generated/out.txt"
cd "$TMP"
git add generated/out.txt
git commit -m "feat: 测试 policy 路径规则

应被 pre-commit policy 拦截。" 2>err.log
expect_fail "policy path.deny 应拦截" $?
expect_contains "错误提示提到 generated" "$(cat err.log 2>/dev/null)" "generated/**"
cleanup_repo "$TMP"

# 用例 10: 普通 *.log 应允许提交
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit commit-msg)
echo "runtime log" > "$TMP/app.log"
echo "debug log" > "$TMP/debug.log"
cd "$TMP"
git add app.log debug.log
git commit -m "feat: 测试普通日志文件提交

项目可能需要长期跟踪运行日志,默认 pre-commit 不应按扩展名拦截普通日志。" 2>err.log
expect_pass "普通 app.log/debug.log 应允许提交" $?
cleanup_repo "$TMP"

# 用例 11: Harness 协议证据日志应允许提交
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit commit-msg)
mkdir -p \
  "$TMP/docs/xian-harness/changes/demo-change/verify/evidence/logs" \
  "$TMP/docs/xian-harness/evidence/demo-change" \
  "$TMP/cases/base-case/docs/xian-harness/changes/demo-change/verify/evidence/logs" \
  "$TMP/cases/base-case/docs/xian-harness/evidence/demo-change"
echo "transition" > "$TMP/docs/xian-harness/changes/demo-change/.change-transition.log"
echo "verify log" > "$TMP/docs/xian-harness/changes/demo-change/verify/evidence/logs/run-001.log"
echo "evidence log" > "$TMP/docs/xian-harness/evidence/demo-change/run-001.log"
echo "case transition" > "$TMP/cases/base-case/docs/xian-harness/changes/demo-change/.change-transition.log"
echo "case verify log" > "$TMP/cases/base-case/docs/xian-harness/changes/demo-change/verify/evidence/logs/run-002.log"
echo "case evidence log" > "$TMP/cases/base-case/docs/xian-harness/evidence/demo-change/run-002.log"
cd "$TMP"
git add docs cases
git commit -m "feat: 测试 Harness 证据日志

Harness 协议证据日志是合法审计产物,默认应允许提交。" 2>err.log
expect_pass "Harness evidence log 应允许提交" $?
cleanup_repo "$TMP"

# 用例 12: policy path.allow 可扩展允许路径
TMP=$(setup_repo "$PROJECT_ROOT" pre-commit commit-msg)
mkdir -p "$TMP/.xian-commit" "$TMP/reports"
printf "path.allow=reports/*.log\npath.deny=reports/**\n" > "$TMP/.xian-commit/config"
echo "kept report" > "$TMP/reports/audit.log"
cd "$TMP"
git add reports/audit.log
git commit -m "feat: 测试 policy 允许路径

项目可通过 path.allow 覆盖 path.deny 中更宽的自定义拦截规则。" 2>err.log
expect_pass "policy path.allow 应优先于 path.deny" $?
cleanup_repo "$TMP"

summary
