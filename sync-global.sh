#!/bin/sh
# sync-global.sh - 将 xian-* skills 注册到用户级 Agent skill 目录
# 只创建软链，不安装 hooks、policy 或项目级状态。

set -u

usage() {
    cat <<'EOF'
xian-commit global skill sync

Usage:
  sh sync-global.sh [install|status|verify|uninstall] [--dry-run] [--home <dir>]

Modes:
  install     Register xian-* skills in user-level Agent directories (default)
  status      Show current user-level link status without writing
  verify      Fail when a managed link is missing, broken, or conflicting
  uninstall   Remove only links managed by this script

Options:
  --dry-run   Print planned changes without writing
  --home DIR  Use DIR as HOME for testing or isolated installs

Managed locations:
  <home>/.agents/skills            Canonical shared hub
  <home>/.qoder-cn/skills          Qoder CN
  <home>/.codex/skills             Codex
  <home>/.claude/skills            Claude Code
EOF
}

die() {
    echo "sync-global: $*" >&2
    exit 1
}

MODE="install"
case "${1:-}" in
    install|status|verify|uninstall)
        MODE="$1"
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "sync-global: unknown mode '$1'." >&2
        usage >&2
        exit 1
        ;;
esac

DRY_RUN=0
HOME_OVERRIDE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --home)
            shift
            [ "$#" -gt 0 ] || die "--home requires a directory."
            HOME_OVERRIDE="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "sync-global: unknown option '$1'." >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ -n "$HOME_OVERRIDE" ]; then
    HOME="$HOME_OVERRIDE"
    export HOME
fi
[ -n "${HOME:-}" ] || die "HOME is not set."

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT="$SCRIPT_DIR"

AGENTS_ROOT="$HOME/.agents/skills"
QODER_ROOT="$HOME/.qoder-cn/skills"
CODEX_ROOT="$HOME/.codex/skills"
CLAUDE_ROOT="$HOME/.claude/skills"
XIAN_COMMIT_HUB="$AGENTS_ROOT/xian-commit"
MANAGED_MARKER=".xian-global-managed"
GUARD_MARKER="xian-commit:global-guard"

FAILED=0
CONFLICTS=0
HUB_OK=1
LINK_OK=1

SKILL_NAMES=""
SKILL_COUNT=0
for skill_dir in "$REPO_ROOT"/.codex/skills/xian-*; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    skill_name=$(basename "$skill_dir")
    [ "$skill_name" = "xian-commit" ] && continue
    SKILL_NAMES="$SKILL_NAMES $skill_name"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

resolve_path() {
    rp_path="$1"
    rp_depth="${2:-0}"
    if [ "$rp_depth" -gt 20 ]; then
        printf '%s\n' "$rp_path"
        return 0
    fi
    if [ -L "$rp_path" ]; then
        rp_dir=$(dirname "$rp_path")
        rp_target=$(readlink "$rp_path" 2>/dev/null) || {
            printf '%s\n' "$rp_path"
            return 0
        }
        case "$rp_target" in
            /*) rp_next="$rp_target" ;;
            *) rp_next="$rp_dir/$rp_target" ;;
        esac
        resolve_path "$rp_next" $((rp_depth + 1))
        return 0
    fi
    if [ -d "$rp_path" ]; then
        (CDPATH= cd -- "$rp_path" 2>/dev/null && pwd -P) || printf '%s\n' "$rp_path"
        return 0
    fi
    if [ -e "$rp_path" ]; then
        rp_dir=$(dirname "$rp_path")
        rp_base=$(basename "$rp_path")
        (CDPATH= cd -- "$rp_dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$rp_base") || printf '%s\n' "$rp_path"
        return 0
    fi
    printf '%s\n' "$rp_path"
}

link_matches() {
    lm_link="$1"
    lm_expected="$2"
    [ -L "$lm_link" ] || return 1
    [ "$(resolve_path "$lm_link")" = "$(resolve_path "$lm_expected")" ]
}

link_is_managed() {
    lim_link="$1"
    lim_target="$2"
    lim_expected="$3"
    [ -L "$lim_link" ] || return 1
    lim_raw=$(readlink "$lim_link" 2>/dev/null) || return 1
    [ "$lim_raw" = "$lim_target" ] && return 0
    link_matches "$lim_link" "$lim_expected"
}

ensure_symlink() {
    es_link="$1"
    es_target="$2"
    es_expected="$3"
    es_label="$4"
    LINK_OK=1
    if [ -L "$es_link" ]; then
        if link_matches "$es_link" "$es_expected"; then
            echo "  current: $es_label -> $es_link"
        else
            echo "  conflict: $es_label -> $es_link (points elsewhere; left untouched)" >&2
            LINK_OK=0
            FAILED=1
        fi
        return 0
    fi
    if path_exists "$es_link"; then
        echo "  conflict: $es_label -> $es_link (existing non-symlink; left untouched)" >&2
        LINK_OK=0
        FAILED=1
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  would create: $es_label -> $es_link"
        return 0
    fi
    mkdir -p "$(dirname "$es_link")" || {
        echo "  failed: $es_label (cannot create parent directory)" >&2
        LINK_OK=0
        FAILED=1
        return 0
    }
    ln -s "$es_target" "$es_link" || {
        echo "  failed: $es_label -> $es_link" >&2
        LINK_OK=0
        FAILED=1
        return 0
    }
    echo "  created: $es_label -> $es_link"
}

check_symlink() {
    cs_link="$1"
    cs_expected="$2"
    cs_label="$3"
    if [ -L "$cs_link" ]; then
        if link_matches "$cs_link" "$cs_expected"; then
            echo "  current: $cs_label -> $cs_link"
        else
            echo "  conflict: $cs_label -> $cs_link (points elsewhere)" >&2
            FAILED=1
        fi
    elif path_exists "$cs_link"; then
        echo "  conflict: $cs_label -> $cs_link (existing non-symlink)" >&2
        FAILED=1
    else
        echo "  missing: $cs_label -> $cs_link" >&2
        FAILED=1
    fi
}

check_skill_link() {
    csl_link="$1"
    csl_expected="$2"
    csl_label="$3"
    check_symlink "$csl_link" "$csl_expected" "$csl_label"
    if [ ! -f "$csl_link/SKILL.md" ]; then
        echo "  missing: $csl_label/SKILL.md" >&2
        FAILED=1
    fi
}

preflight_symlink() {
    pf_link="$1"
    pf_target="$2"
    pf_expected="$3"
    pf_label="$4"
    if [ -L "$pf_link" ]; then
        if link_is_managed "$pf_link" "$pf_target" "$pf_expected"; then
            return 0
        fi
        echo "  conflict: $pf_label -> $pf_link (points elsewhere)" >&2
        CONFLICTS=$((CONFLICTS + 1))
        return 0
    fi
    if path_exists "$pf_link"; then
        echo "  conflict: $pf_label -> $pf_link (existing non-symlink)" >&2
        CONFLICTS=$((CONFLICTS + 1))
    fi
}

preflight_hub_link() {
    phl_link="$1"
    phl_target="$2"
    phl_label="$3"
    if [ -L "$phl_link" ]; then
        if link_matches "$phl_link" "$phl_target"; then
            return 0
        fi
        echo "  conflict: $phl_label -> $phl_link (points elsewhere)" >&2
        CONFLICTS=$((CONFLICTS + 1))
        return 0
    fi
    if path_exists "$phl_link"; then
        echo "  conflict: $phl_label -> $phl_link (existing non-symlink)" >&2
        CONFLICTS=$((CONFLICTS + 1))
    fi
}

product_roots() {
    printf '%s\n' "$QODER_ROOT:qoder" "$CODEX_ROOT:codex" "$CLAUDE_ROOT:claude"
}

preflight_install() {
    [ -f "$REPO_ROOT/SKILL.md" ] || {
        echo "  missing source: $REPO_ROOT/SKILL.md" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }
    [ -f "$REPO_ROOT/install.sh" ] || {
        echo "  missing source: $REPO_ROOT/install.sh" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }
    [ -f "$REPO_ROOT/prompts/commit-message.md" ] || {
        echo "  missing source: $REPO_ROOT/prompts/commit-message.md" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }
    [ -d "$REPO_ROOT/references" ] || {
        echo "  missing source: $REPO_ROOT/references" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }
    [ -f "$REPO_ROOT/hooks/pre-commit" ] || {
        echo "  missing source: $REPO_ROOT/hooks/pre-commit" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }
    [ -f "$REPO_ROOT/policy.example.conf" ] || {
        echo "  missing source: $REPO_ROOT/policy.example.conf" >&2
        CONFLICTS=$((CONFLICTS + 1))
    }

    if [ -L "$XIAN_COMMIT_HUB" ]; then
        echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (unexpected symlink)" >&2
        CONFLICTS=$((CONFLICTS + 1))
    elif [ -d "$XIAN_COMMIT_HUB" ]; then
        if [ ! -f "$XIAN_COMMIT_HUB/$MANAGED_MARKER" ]; then
            echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (directory is not managed by sync-global)" >&2
            CONFLICTS=$((CONFLICTS + 1))
        else
            preflight_hub_link "$XIAN_COMMIT_HUB/SKILL.md" "$REPO_ROOT/SKILL.md" "xian-commit/SKILL.md"
            preflight_hub_link "$XIAN_COMMIT_HUB/install.sh" "$REPO_ROOT/install.sh" "xian-commit/install.sh"
            preflight_hub_link "$XIAN_COMMIT_HUB/prompts" "$REPO_ROOT/prompts" "xian-commit/prompts"
            preflight_hub_link "$XIAN_COMMIT_HUB/references" "$REPO_ROOT/references" "xian-commit/references"
            preflight_hub_link "$XIAN_COMMIT_HUB/hooks" "$REPO_ROOT/hooks" "xian-commit/hooks"
            preflight_hub_link "$XIAN_COMMIT_HUB/policy.example.conf" "$REPO_ROOT/policy.example.conf" "xian-commit/policy.example.conf"
        fi
    fi

    for skill_name in $SKILL_NAMES; do
        preflight_symlink "$AGENTS_ROOT/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "agents/$skill_name"
    done

    for product_root in $(product_roots); do
        product_dir=${product_root%%:*}
        product_label=${product_root##*:}
        preflight_symlink "$product_dir/xian-commit" "../../.agents/skills/xian-commit" "$XIAN_COMMIT_HUB" "$product_label/xian-commit"
        for skill_name in $SKILL_NAMES; do
            preflight_symlink "$product_dir/$skill_name" "../../.agents/skills/$skill_name" "$AGENTS_ROOT/$skill_name" "$product_label/$skill_name"
        done
    done
}

ensure_hub_link() {
    ehl_link="$1"
    ehl_target="$2"
    ehl_label="$3"
    if [ -L "$ehl_link" ]; then
        if link_matches "$ehl_link" "$ehl_target"; then
            echo "  current: $ehl_label"
        else
            echo "  conflict: $ehl_label -> $ehl_link (points elsewhere; left untouched)" >&2
            FAILED=1
        fi
        return 0
    fi
    if path_exists "$ehl_link"; then
        echo "  conflict: $ehl_label -> $ehl_link (existing non-symlink; left untouched)" >&2
        FAILED=1
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  would create: $ehl_label"
        return 0
    fi
    ln -s "$ehl_target" "$ehl_link" || {
        echo "  failed: $ehl_label" >&2
        FAILED=1
        return 0
    }
    echo "  created: $ehl_label"
}

install_xian_commit_hub() {
    HUB_OK=1
    if [ -L "$XIAN_COMMIT_HUB" ]; then
        echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (unexpected symlink; left untouched)" >&2
        HUB_OK=0
        FAILED=1
        return 0
    fi
    if [ -d "$XIAN_COMMIT_HUB" ]; then
        if [ ! -f "$XIAN_COMMIT_HUB/$MANAGED_MARKER" ]; then
            echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (directory is not managed by sync-global; left untouched)" >&2
            HUB_OK=0
            FAILED=1
            return 0
        fi
        echo "  current: xian-commit hub -> $XIAN_COMMIT_HUB"
    elif [ "$DRY_RUN" -eq 1 ]; then
        echo "  would create: xian-commit hub -> $XIAN_COMMIT_HUB"
    else
        mkdir -p "$XIAN_COMMIT_HUB" || {
            echo "  failed: xian-commit hub (cannot create directory)" >&2
            HUB_OK=0
            FAILED=1
            return 0
        }
        printf 'xian-commit user-level skill\n' > "$XIAN_COMMIT_HUB/$MANAGED_MARKER" || {
            echo "  failed: xian-commit hub marker" >&2
            HUB_OK=0
            FAILED=1
            return 0
        }
        echo "  created: xian-commit hub -> $XIAN_COMMIT_HUB"
    fi

    ensure_hub_link "$XIAN_COMMIT_HUB/SKILL.md" "$REPO_ROOT/SKILL.md" "xian-commit/SKILL.md"
    ensure_hub_link "$XIAN_COMMIT_HUB/install.sh" "$REPO_ROOT/install.sh" "xian-commit/install.sh"
    ensure_hub_link "$XIAN_COMMIT_HUB/prompts" "$REPO_ROOT/prompts" "xian-commit/prompts"
    ensure_hub_link "$XIAN_COMMIT_HUB/references" "$REPO_ROOT/references" "xian-commit/references"
    ensure_hub_link "$XIAN_COMMIT_HUB/hooks" "$REPO_ROOT/hooks" "xian-commit/hooks"
    ensure_hub_link "$XIAN_COMMIT_HUB/policy.example.conf" "$REPO_ROOT/policy.example.conf" "xian-commit/policy.example.conf"
}

install_one() {
    io_name="$1"
    if [ "$io_name" = "xian-commit" ]; then
        install_xian_commit_hub
        [ "$HUB_OK" -eq 1 ] || return 0
        io_hub="$XIAN_COMMIT_HUB"
    else
        io_source="$REPO_ROOT/.codex/skills/$io_name"
        if [ ! -f "$io_source/SKILL.md" ]; then
            echo "  missing source: $io_name -> $io_source" >&2
            FAILED=1
            return 0
        fi
        ensure_symlink "$AGENTS_ROOT/$io_name" "$io_source" "$io_source" "agents/$io_name"
        [ "$LINK_OK" -eq 1 ] || return 0
        io_hub="$AGENTS_ROOT/$io_name"
    fi

    for product_root in $(product_roots); do
        product_dir=${product_root%%:*}
        product_label=${product_root##*:}
        ensure_symlink "$product_dir/$io_name" "../../.agents/skills/$io_name" "$io_hub" "$product_label/$io_name"
    done
}

install_all() {
    echo "xian-commit: 同步用户级 Agent skills"
    echo "  hub: $AGENTS_ROOT"
    echo "  products: $QODER_ROOT, $CODEX_ROOT, $CLAUDE_ROOT"
    preflight_install
    if [ "$CONFLICTS" -gt 0 ]; then
        echo "sync-global: 发现 $CONFLICTS 个冲突，未写入任何文件。" >&2
        exit 1
    fi
    install_one "xian-commit"
    for skill_name in $SKILL_NAMES; do
        install_one "$skill_name"
    done
    echo "  skills: 1 + $SKILL_COUNT"
    if [ "$FAILED" -ne 0 ]; then
        echo "sync-global: 同步未完全成功，请检查上面的冲突或失败项。" >&2
        exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "sync-global: dry-run 完成，未写入文件。"
    else
        echo "sync-global: 用户级同步完成。工程级 hooks/policy 仍需在目标仓库运行 install.sh。"
    fi
}

check_xian_commit_hub() {
    if [ -L "$XIAN_COMMIT_HUB" ]; then
        echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (unexpected symlink)" >&2
        FAILED=1
        return 0
    fi
    if [ ! -d "$XIAN_COMMIT_HUB" ]; then
        echo "  missing: xian-commit hub -> $XIAN_COMMIT_HUB" >&2
        FAILED=1
        return 0
    fi
    if [ ! -f "$XIAN_COMMIT_HUB/$MANAGED_MARKER" ]; then
        echo "  conflict: xian-commit hub -> $XIAN_COMMIT_HUB (not managed by sync-global)" >&2
        FAILED=1
        return 0
    fi
    echo "  current: xian-commit hub -> $XIAN_COMMIT_HUB"
    check_symlink "$XIAN_COMMIT_HUB/SKILL.md" "$REPO_ROOT/SKILL.md" "xian-commit/SKILL.md"
    check_symlink "$XIAN_COMMIT_HUB/install.sh" "$REPO_ROOT/install.sh" "xian-commit/install.sh"
    check_symlink "$XIAN_COMMIT_HUB/prompts" "$REPO_ROOT/prompts" "xian-commit/prompts"
    check_symlink "$XIAN_COMMIT_HUB/references" "$REPO_ROOT/references" "xian-commit/references"
    check_symlink "$XIAN_COMMIT_HUB/hooks" "$REPO_ROOT/hooks" "xian-commit/hooks"
    check_symlink "$XIAN_COMMIT_HUB/policy.example.conf" "$REPO_ROOT/policy.example.conf" "xian-commit/policy.example.conf"
    for required in SKILL.md install.sh prompts/commit-message.md hooks/pre-commit policy.example.conf; do
        if [ ! -f "$XIAN_COMMIT_HUB/$required" ]; then
            echo "  missing: xian-commit/$required" >&2
            FAILED=1
        fi
    done
    if [ ! -d "$XIAN_COMMIT_HUB/references" ]; then
        echo "  missing: xian-commit/references" >&2
        FAILED=1
    fi
}

status_all() {
    echo "xian-commit: 用户级 Agent skill 状态"
    check_xian_commit_hub
    for skill_name in $SKILL_NAMES; do
        check_skill_link "$AGENTS_ROOT/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "agents/$skill_name"
    done
    for product_root in $(product_roots); do
        product_dir=${product_root%%:*}
        product_label=${product_root##*:}
        check_skill_link "$product_dir/xian-commit" "$XIAN_COMMIT_HUB" "$product_label/xian-commit"
        for skill_name in $SKILL_NAMES; do
            check_skill_link "$product_dir/$skill_name" "$AGENTS_ROOT/$skill_name" "$product_label/$skill_name"
        done
    done
}

verify_all() {
    echo "xian-commit: 验证用户级 Agent skill 同步"
    if grep -q "$GUARD_MARKER" "$REPO_ROOT/SKILL.md"; then
        echo "  ok: xian-commit global guard"
    else
        echo "  missing: xian-commit global guard marker in SKILL.md" >&2
        FAILED=1
    fi
    check_xian_commit_hub
    for skill_name in $SKILL_NAMES; do
        check_skill_link "$AGENTS_ROOT/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "agents/$skill_name"
    done
    for product_root in $(product_roots); do
        product_dir=${product_root%%:*}
        product_label=${product_root##*:}
        check_skill_link "$product_dir/xian-commit" "$XIAN_COMMIT_HUB" "$product_label/xian-commit"
        for skill_name in $SKILL_NAMES; do
            check_skill_link "$product_dir/$skill_name" "$AGENTS_ROOT/$skill_name" "$product_label/$skill_name"
        done
    done
    if [ "$FAILED" -ne 0 ]; then
        echo "sync-global verify: 用户级同步不完整。" >&2
        exit 1
    fi
    echo "  skills: 1 + $SKILL_COUNT"
    echo "sync-global verify: ok"
}

remove_managed_link() {
    rml_link="$1"
    rml_target="$2"
    rml_expected="$3"
    rml_label="$4"
    if [ ! -L "$rml_link" ] && ! path_exists "$rml_link"; then
        echo "  missing: $rml_label -> $rml_link"
        return 0
    fi
    if link_is_managed "$rml_link" "$rml_target" "$rml_expected"; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  would remove: $rml_label -> $rml_link"
        else
            rm -f "$rml_link" || {
                echo "  failed: $rml_label -> $rml_link" >&2
                FAILED=1
                return 0
            }
            echo "  removed: $rml_label -> $rml_link"
        fi
    else
        echo "  kept: $rml_label -> $rml_link (not managed by sync-global)" >&2
    fi
}

remove_xian_commit_hub() {
    if [ -L "$XIAN_COMMIT_HUB" ]; then
        echo "  kept: xian-commit hub -> $XIAN_COMMIT_HUB (unexpected symlink)" >&2
        return 0
    fi
    if [ ! -d "$XIAN_COMMIT_HUB" ]; then
        echo "  missing: xian-commit hub -> $XIAN_COMMIT_HUB"
        return 0
    fi
    if [ ! -f "$XIAN_COMMIT_HUB/$MANAGED_MARKER" ]; then
        echo "  kept: xian-commit hub -> $XIAN_COMMIT_HUB (not managed by sync-global)" >&2
        return 0
    fi
    remove_managed_link "$XIAN_COMMIT_HUB/SKILL.md" "$REPO_ROOT/SKILL.md" "$REPO_ROOT/SKILL.md" "xian-commit/SKILL.md"
    remove_managed_link "$XIAN_COMMIT_HUB/install.sh" "$REPO_ROOT/install.sh" "$REPO_ROOT/install.sh" "xian-commit/install.sh"
    remove_managed_link "$XIAN_COMMIT_HUB/prompts" "$REPO_ROOT/prompts" "$REPO_ROOT/prompts" "xian-commit/prompts"
    remove_managed_link "$XIAN_COMMIT_HUB/references" "$REPO_ROOT/references" "$REPO_ROOT/references" "xian-commit/references"
    remove_managed_link "$XIAN_COMMIT_HUB/hooks" "$REPO_ROOT/hooks" "$REPO_ROOT/hooks" "xian-commit/hooks"
    remove_managed_link "$XIAN_COMMIT_HUB/policy.example.conf" "$REPO_ROOT/policy.example.conf" "$REPO_ROOT/policy.example.conf" "xian-commit/policy.example.conf"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  would remove: xian-commit hub marker -> $XIAN_COMMIT_HUB/$MANAGED_MARKER"
    else
        rm -f "$XIAN_COMMIT_HUB/$MANAGED_MARKER"
        rmdir "$XIAN_COMMIT_HUB" 2>/dev/null || echo "  kept: xian-commit hub contains non-managed files -> $XIAN_COMMIT_HUB" >&2
    fi
}

uninstall_all() {
    echo "xian-commit: 移除用户级 Agent skill 同步"
    for product_root in $(product_roots); do
        product_dir=${product_root%%:*}
        product_label=${product_root##*:}
        remove_managed_link "$product_dir/xian-commit" "../../.agents/skills/xian-commit" "$XIAN_COMMIT_HUB" "$product_label/xian-commit"
        for skill_name in $SKILL_NAMES; do
            remove_managed_link "$product_dir/$skill_name" "../../.agents/skills/$skill_name" "$AGENTS_ROOT/$skill_name" "$product_label/$skill_name"
        done
    done
    for skill_name in $SKILL_NAMES; do
        remove_managed_link "$AGENTS_ROOT/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "$REPO_ROOT/.codex/skills/$skill_name" "agents/$skill_name"
    done
    remove_xian_commit_hub
    if [ "$FAILED" -ne 0 ]; then
        echo "sync-global: 部分受管链接移除失败。" >&2
        exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "sync-global: dry-run 完成，未写入文件。"
    else
        echo "sync-global: 用户级同步已移除；外部文件和目录保持不动。"
    fi
}

case "$MODE" in
    install)
        install_all
        ;;
    status)
        status_all
        exit 0
        ;;
    verify)
        verify_all
        ;;
    uninstall)
        uninstall_all
        ;;
esac
