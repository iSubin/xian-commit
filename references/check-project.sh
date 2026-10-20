#!/bin/sh
# 只读检查当前 Git 实际使用的 hooks；不能从配置目录推断安装状态。
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "repository=absent"
    exit 1
}
if [ -f "$ROOT/.xian-commit/config" ]; then echo "policy=present"; else echo "policy=absent"; fi
HOOKS=$(git -C "$ROOT" rev-parse --git-path hooks)
case "$HOOKS" in /*) ;; *) HOOKS="$ROOT/$HOOKS" ;; esac
current=1
for hook in pre-commit commit-msg pre-push post-commit; do
    if [ ! -x "$HOOKS/$hook" ]; then
        echo "$hook=missing-or-not-executable"
        current=0
    elif [ ! -f "$SOURCE/hooks/$hook" ]; then
        echo "$hook=unverified-source-unavailable"
        current=0
    elif cmp -s "$SOURCE/hooks/$hook" "$HOOKS/$hook"; then
        echo "$hook=current"
    else
        echo "$hook=differs"
        current=0
    fi
done
if [ "$current" -eq 1 ]; then echo "hooks=current"; else echo "hooks=unverified"; fi
