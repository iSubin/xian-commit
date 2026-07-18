#!/bin/sh
# install.sh - 把 xian-commit 技术资源装到当前 git repo
# 默认安装 Codex / Claude Code skills + prompt + policy + hooks。幂等,可重复运行。

set -u

MODE="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
PROMPT_SRC="$SCRIPT_DIR/prompts/commit-message.md"
SKILL_SRC="$SCRIPT_DIR/SKILL.md"
POLICY_SRC="$SCRIPT_DIR/policy.example.conf"
REFERENCES_SRC="$SCRIPT_DIR/references"

case "$MODE" in
    all|update|hooks|skill|verify|status|uninstall) ;;
    -h|--help)
        cat <<EOF
xian-commit install

Usage:
  sh install.sh          # install all resources(default)
  sh install.sh all      # install skill, prompt, policy, hooks
  sh install.sh update   # update installed resources(same as all)
  sh install.sh hooks    # install only .git/hooks
  sh install.sh skill    # install only agent skills and .xian-commit policy
  sh install.sh verify   # verify installed resources in current repo
  sh install.sh status   # show installed resource status without writing
  sh install.sh uninstall # remove xian-commit managed resources
EOF
        exit 0
        ;;
    *)
        echo "xian-commit install: unknown mode '$MODE'." >&2
        echo "允许: all / update / hooks / skill / verify / status / uninstall" >&2
        exit 1
        ;;
esac

# 检查在 git 仓库内
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GIT_DIR" ]; then
    echo "xian-commit install: 当前目录不是 git 仓库。" >&2
    echo "请先 cd 到 git 仓库根目录,或运行 git init。" >&2
    exit 1
fi
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

# linked worktree 的 $GIT_DIR 是私有目录，但 hooks 默认位于共享 git-dir。
# 交给 Git 解析实际路径，避免手工拼接 $GIT_DIR/hooks。
CORE_HOOKS_PATH_SET=0
CORE_HOOKS_PATH=""
if CORE_HOOKS_PATH=$(git config --get core.hooksPath 2>/dev/null); then
    CORE_HOOKS_PATH_SET=1
fi

reject_custom_hooks_path() {
    [ "$CORE_HOOKS_PATH_SET" -eq 0 ] && return 0
    hooks_path_display="$CORE_HOOKS_PATH"
    [ -n "$hooks_path_display" ] || hooks_path_display="<empty>"
    cat >&2 <<EOF
xian-commit $MODE: 检测到 core.hooksPath=${hooks_path_display}。
为避免覆盖 Husky 等现有 hook 管理器，xian-commit 不会直接安装或验证 hooks。
请先取消 core.hooksPath，或手动将 xian-commit hooks 串联到现有 hook 管理器。
EOF
    exit 1
}

case "$MODE" in
    all|update|hooks|verify) reject_custom_hooks_path ;;
esac

HOOKS_PATH=$(git -C "$REPO_ROOT" rev-parse --git-path hooks 2>/dev/null)
if [ -z "$HOOKS_PATH" ]; then
    echo "xian-commit install: 无法解析 Git hooks 目录。" >&2
    exit 1
fi
case "$HOOKS_PATH" in
    /*) HOOKS_DST="$HOOKS_PATH" ;;
    *) HOOKS_DST="$REPO_ROOT/$HOOKS_PATH" ;;
esac

CODEX_SKILL_DST="$REPO_ROOT/.codex/skills/xian-commit"
CLAUDE_SKILL_DST="$REPO_ROOT/.claude/skills/xian-commit"
POLICY_DST="$REPO_ROOT/.xian-commit"

install_hooks() {
    if [ ! -d "$HOOKS_SRC" ]; then
        echo "xian-commit install: 找不到 hooks 目录 ($HOOKS_SRC)。" >&2
        exit 1
    fi

    mkdir -p "$HOOKS_DST"

    INSTALLED=""
    BACKED_UP=""

    for hook_src in "$HOOKS_SRC"/*; do
        [ -f "$hook_src" ] || continue
        hook_name=$(basename "$hook_src")
        hook_dst="$HOOKS_DST/$hook_name"
        if [ -f "$hook_dst" ] && ! diff -q "$hook_src" "$hook_dst" >/dev/null 2>&1; then
            backup="${hook_dst}.pre-xian-commit.bak"
            if [ ! -f "$backup" ]; then
                cp "$hook_dst" "$backup"
                BACKED_UP="$BACKED_UP
  - $hook_name -> $(basename "$backup")"
            fi
        fi
        cp "$hook_src" "$hook_dst"
        chmod +x "$hook_dst"
        INSTALLED="$INSTALLED $hook_name"
    done

    echo "xian-commit: 已安装 hooks 到 $HOOKS_DST"
    echo "  installed:$INSTALLED"
    if [ -n "$BACKED_UP" ]; then
        echo "  backed up:$BACKED_UP"
    fi
}

install_skill_to() {
    skill_dst="$1"

    mkdir -p "$skill_dst/prompts"
    cp "$SKILL_SRC" "$skill_dst/SKILL.md"
    cp "$PROMPT_SRC" "$skill_dst/prompts/commit-message.md"
    if [ -d "$REFERENCES_SRC" ]; then
        mkdir -p "$skill_dst/references"
        for reference_src in "$REFERENCES_SRC"/*; do
            [ -f "$reference_src" ] || continue
            cp "$reference_src" "$skill_dst/references/$(basename "$reference_src")"
        done
    fi
}

install_skill() {
    if [ ! -f "$SKILL_SRC" ] || [ ! -f "$PROMPT_SRC" ] || [ ! -f "$POLICY_SRC" ]; then
        echo "xian-commit install: 缺少 SKILL.md、prompt 或 policy.example.conf。" >&2
        exit 1
    fi

    mkdir -p "$POLICY_DST"
    install_skill_to "$CODEX_SKILL_DST"
    install_skill_to "$CLAUDE_SKILL_DST"
    cp "$POLICY_SRC" "$POLICY_DST/policy.example.conf"

    if [ ! -f "$POLICY_DST/config" ]; then
        cp "$POLICY_SRC" "$POLICY_DST/config"
        policy_status="created .xian-commit/config"
    else
        policy_status="kept existing .xian-commit/config"
    fi

    echo "xian-commit: 已安装 agent assets 到 $REPO_ROOT"
    echo "  codex skill: .codex/skills/xian-commit/SKILL.md"
    echo "  claude skill: .claude/skills/xian-commit/SKILL.md"
    echo "  prompt: prompts/commit-message.md"
    if [ -d "$REFERENCES_SRC" ]; then
        echo "  references: references/"
    fi
    echo "  policy: $policy_status"
}

verify_install() {
    failed=0

    check_file() {
        path="$1"
        if [ -f "$path" ]; then
            echo "  ok: $path"
        else
            echo "  missing: $path" >&2
            failed=1
        fi
    }

    check_exec() {
        path="$1"
        if [ -x "$path" ]; then
            echo "  ok: $path"
        else
            echo "  missing or not executable: $path" >&2
            failed=1
        fi
    }

    check_skill_tree() {
        skill_dst="$1"
        check_file "$skill_dst/SKILL.md"
        check_file "$skill_dst/prompts/commit-message.md"
        if [ -d "$REFERENCES_SRC" ]; then
            for reference_src in "$REFERENCES_SRC"/*; do
                [ -f "$reference_src" ] || continue
                check_file "$skill_dst/references/$(basename "$reference_src")"
            done
        fi
    }

    echo "xian-commit: 验证安装资源"
    check_skill_tree "$CODEX_SKILL_DST"
    check_skill_tree "$CLAUDE_SKILL_DST"
    check_file "$POLICY_DST/config"
    check_exec "$HOOKS_DST/pre-commit"
    check_exec "$HOOKS_DST/commit-msg"
    check_exec "$HOOKS_DST/post-commit"
    check_exec "$HOOKS_DST/pre-push"

    if [ "$failed" -ne 0 ]; then
        echo "xian-commit verify: 安装资源不完整。" >&2
        exit 1
    fi

    tmp_msg=$(mktemp 2>/dev/null || mktemp -t xian-commit-msg) || exit 1
    tmp_policy=$(mktemp 2>/dev/null || mktemp -t xian-commit-policy) || {
        rm -f "$tmp_msg"
        exit 1
    }
    cat > "$tmp_msg" <<'EOF'
docs: xian-commit verify
EOF
    cat > "$tmp_policy" <<'EOF'
message.types=docs
message.title_language=any
message.body_required=false
EOF
    if XIAN_COMMIT_CONFIG="$tmp_policy" "$HOOKS_DST/commit-msg" "$tmp_msg" >/dev/null 2>&1; then
        echo "  ok: commit-msg smoke"
    else
        rm -f "$tmp_msg" "$tmp_policy"
        echo "xian-commit verify: commit-msg smoke failed." >&2
        exit 1
    fi
    rm -f "$tmp_msg" "$tmp_policy"

    if git diff --cached --quiet --; then
        if "$HOOKS_DST/pre-commit" >/dev/null 2>&1; then
            echo "  ok: pre-commit smoke"
        else
            echo "xian-commit verify: pre-commit smoke failed." >&2
            exit 1
        fi
    else
        echo "  skip: pre-commit smoke(staged files present)"
    fi

    echo "xian-commit verify: ok"
}

status_install() {
    compare_file() {
        file_label="$1"
        file_src="$2"
        file_dst="$3"
        if [ ! -f "$file_dst" ]; then
            echo "  missing: $file_label -> $file_dst"
        elif [ -n "$file_src" ] && [ -f "$file_src" ] && diff -q "$file_src" "$file_dst" >/dev/null 2>&1; then
            echo "  current: $file_label -> $file_dst"
        elif [ -n "$file_src" ] && [ -f "$file_src" ]; then
            echo "  differs: $file_label -> $file_dst"
        else
            echo "  present: $file_label -> $file_dst"
        fi
    }

    compare_skill_tree() {
        tree_label="$1"
        tree_dst="$2"
        compare_file "$tree_label skill" "$SKILL_SRC" "$tree_dst/SKILL.md"
        compare_file "$tree_label prompt" "$PROMPT_SRC" "$tree_dst/prompts/commit-message.md"
        if [ -d "$REFERENCES_SRC" ]; then
            for reference_src in "$REFERENCES_SRC"/*; do
                [ -f "$reference_src" ] || continue
                compare_file "$tree_label reference $(basename "$reference_src")" "$reference_src" "$tree_dst/references/$(basename "$reference_src")"
            done
        fi
    }

    compare_hook() {
        name="$1"
        src="$HOOKS_SRC/$name"
        dst="$HOOKS_DST/$name"
        if [ ! -f "$dst" ]; then
            echo "  missing: hook $name -> $dst"
        elif [ ! -x "$dst" ]; then
            echo "  not-executable: hook $name -> $dst"
        elif diff -q "$src" "$dst" >/dev/null 2>&1; then
            echo "  current: hook $name -> $dst"
        else
            echo "  differs: hook $name -> $dst"
        fi
    }

    echo "xian-commit: 安装状态($REPO_ROOT)"
    compare_skill_tree "codex" "$CODEX_SKILL_DST"
    compare_skill_tree "claude" "$CLAUDE_SKILL_DST"
    compare_file "policy example" "$POLICY_SRC" "$POLICY_DST/policy.example.conf"
    compare_file "policy config" "" "$POLICY_DST/config"
    compare_hook "pre-commit"
    compare_hook "commit-msg"
    compare_hook "post-commit"
    compare_hook "pre-push"
}

uninstall_resources() {
    echo "xian-commit: 卸载自身管理的技术资源($REPO_ROOT)"

    if [ -d "$CODEX_SKILL_DST" ]; then
        rm -rf "$CODEX_SKILL_DST"
        echo "  removed: .codex/skills/xian-commit"
    else
        echo "  missing: .codex/skills/xian-commit"
    fi

    if [ -d "$CLAUDE_SKILL_DST" ]; then
        rm -rf "$CLAUDE_SKILL_DST"
        echo "  removed: .claude/skills/xian-commit"
    else
        echo "  missing: .claude/skills/xian-commit"
    fi

    if [ -f "$POLICY_DST/policy.example.conf" ]; then
        rm -f "$POLICY_DST/policy.example.conf"
        echo "  removed: .xian-commit/policy.example.conf"
    else
        echo "  missing: .xian-commit/policy.example.conf"
    fi

    rmdir "$POLICY_DST" 2>/dev/null || true
    if [ -f "$POLICY_DST/config" ]; then
        echo "  kept: .xian-commit/config"
    fi

    for hook_name in pre-commit commit-msg post-commit pre-push; do
        hook_src="$HOOKS_SRC/$hook_name"
        hook_dst="$HOOKS_DST/$hook_name"
        if [ ! -f "$hook_dst" ]; then
            echo "  missing: hook $hook_name"
        elif [ -f "$hook_src" ] && diff -q "$hook_src" "$hook_dst" >/dev/null 2>&1; then
            rm -f "$hook_dst"
            echo "  removed: hook $hook_name"
        else
            echo "  kept: hook $hook_name differs from xian-commit source"
        fi
    done
}

case "$MODE" in
    all|update)
        install_skill
        install_hooks
        ;;
    hooks)
        install_hooks
        ;;
    skill)
        install_skill
        ;;
    verify)
        verify_install
        exit 0
        ;;
    status)
        status_install
        exit 0
        ;;
    uninstall)
        uninstall_resources
        exit 0
        ;;
esac

echo ""
echo "卸载:"
echo "  rm -rf $CODEX_SKILL_DST"
echo "  rm -rf $CLAUDE_SKILL_DST"
echo "  rm -rf $POLICY_DST"
echo "  rm -f $HOOKS_DST/{pre-commit,commit-msg,post-commit,pre-push}"
echo ""
echo "安装状态:sh $SCRIPT_DIR/install.sh status"
echo "更新:sh $SCRIPT_DIR/install.sh update"
echo "安装自检:sh $SCRIPT_DIR/install.sh verify"
echo "卸载:sh $SCRIPT_DIR/install.sh uninstall"
echo "开发测试:sh $SCRIPT_DIR/tests/run_tests.sh"

exit 0
