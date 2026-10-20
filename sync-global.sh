#!/bin/sh
# 用户级发现入口。只分发本产品，不扫描工程里安装的其他 Skills。
set -eu

MODE=install
TARGET_HOME=${HOME:?HOME is required}
AGENTS="codex claude qoder-cn qoder qoderwork"
DRY_RUN=0
ADOPT_LEGACY=0
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
usage() {
    echo "Usage: sh sync-global.sh [install|status|verify|uninstall] [--home PATH] [--agents codex,claude,qoder-cn,qoder,qoderwork] [--dry-run] [--adopt-legacy]"
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        install|status|verify|uninstall) MODE=$1 ;;
        --home) shift; TARGET_HOME=${1:?--home requires a path} ;;
        --agents) shift; AGENTS=$(printf '%s' "${1:?--agents requires names}" | tr ',' ' ') ;;
        --dry-run) DRY_RUN=1 ;;
        --adopt-legacy) ADOPT_LEGACY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done
for agent in $AGENTS; do
    case "$agent" in codex|claude|qoder-cn|qoder|qoderwork) ;; *) echo "Unknown agent: $agent" >&2; exit 2 ;; esac
done
[ -d "$TARGET_HOME" ] || { echo "Home directory must exist: $TARGET_HOME" >&2; exit 1; }
TARGET_HOME=$(CDPATH= cd -- "$TARGET_HOME" && pwd -P)
TAB=$(printf '\t')
NL='
'
case "$SOURCE$TARGET_HOME" in *"$TAB"*|*"$NL"*) echo "Tab/newline in installation paths is unsupported." >&2; exit 1 ;; esac
HUB=.agents/skills/xian-commit
STATE="$TARGET_HOME/.agents/xian-commit-sync.tsv"
LEGACY="$TARGET_HOME/$HUB/.xian-global-managed"
TEMP=$(mktemp -d "${TMPDIR:-/tmp}/xian-sync.XXXXXX")
LOCK=""
cleanup() {
    rm -f "$TEMP/desired" "$TEMP/next" "$TEMP/old"
    rmdir "$TEMP"
    if [ -n "$LOCK" ]; then rmdir "$LOCK"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
: > "$TEMP/old"
HAD_STATE=0
if [ -L "$STATE" ]; then echo "conflict: manifest is a symlink" >&2; exit 1; fi
if [ -f "$STATE" ]; then cp "$STATE" "$TEMP/old"; HAD_STATE=1; fi

# 限定 manifest 的作用域；即使文件损坏也不能删除其他路径。
valid_path() {
    case "$1:$2" in
        D:.agents/skills/xian-commit|L:.agents/skills/xian-commit) return 0 ;;
        L:.agents/skills/xian-commit/*)
            leaf=${2##*/}
            [ "$2" = ".agents/skills/xian-commit/$leaf" ] || return 1
            case "$leaf" in ""|.|..) return 1 ;; esac
            return 0 ;;
        L:.codex/skills/xian-commit|L:.claude/skills/xian-commit|L:.qoder-cn/skills/xian-commit|L:.qoder/skills/xian-commit|L:.qoderwork/skills/xian-commit) return 0 ;;
    esac
    return 1
}
while IFS="$TAB" read -r kind owner rel target extra; do
    [ -n "$kind" ] || continue
    valid_path "$kind" "$rel" || { echo "Invalid manifest path: $rel" >&2; exit 1; }
    case "$owner" in owned|borrowed) ;; *) echo "Invalid manifest ownership" >&2; exit 1 ;; esac
    [ -n "$target" ] && [ -z "$extra" ] || { echo "Invalid manifest row" >&2; exit 1; }
done < "$TEMP/old"
if ! awk -F '\t' 'seen[$3]++ {exit 1}' "$TEMP/old"; then echo "Duplicate manifest path" >&2; exit 1; fi

# 拒绝经由父目录软链改写用户其他位置。
safe_parent() {
    parent=${1%/*}
    while [ "$parent" != "." ] && [ -n "$parent" ]; do
        [ ! -L "$TARGET_HOME/$parent" ] || return 1
        [ ! -e "$TARGET_HOME/$parent" ] || [ -d "$TARGET_HOME/$parent" ] || return 1
        case "$parent" in */*) parent=${parent%/*} ;; *) break ;; esac
    done
}
safe_parent .agents/xian-commit-sync.tsv || {
    echo "conflict: symlink/non-directory state parent" >&2
    exit 1
}
matches() {
    if [ "$1" = D ]; then
        [ -d "$TARGET_HOME/$2" ] && [ ! -L "$TARGET_HOME/$2" ]
    else
        [ -L "$TARGET_HOME/$2" ] && [ "$(readlink "$TARGET_HOME/$2")" = "$3" ]
    fi
}
exists() { [ -e "$TARGET_HOME/$1" ] || [ -L "$TARGET_HOME/$1" ]; }
record() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$TEMP/next"; }
: > "$TEMP/next"
: > "$TEMP/desired"
if [ "$MODE" != uninstall ]; then
    printf 'L\t%s\t%s\n' "$HUB" "$SOURCE" >> "$TEMP/desired"
    for agent in $AGENTS; do
        printf 'L\t.%s/skills/xian-commit\t../../.agents/skills/xian-commit\n' "$agent"
    done | sort -u >> "$TEMP/desired"
fi

FAILED=0
conflict() { echo "conflict: $1" >&2; FAILED=1; }
MIGRATE_HUB=0
if [ "$MODE" != uninstall ]; then
    for asset in SKILL.md install.sh prompts references hooks policy.example.conf; do
        [ -e "$SOURCE/$asset" ] || conflict "missing source: $SOURCE/$asset"
    done
fi
if [ "$MODE" = install ] && [ -e "$LEGACY" ] && [ ! -s "$TEMP/old" ] && [ "$ADOPT_LEGACY" -ne 1 ]; then
    conflict "legacy install: use --adopt-legacy once after checking the existing links"
fi
if [ "$MODE" = uninstall ] && [ -e "$LEGACY" ] && [ ! -s "$TEMP/old" ]; then
    conflict "legacy install: run install --adopt-legacy before uninstall"
fi
# 旧版 hub 是真实目录 + 文件软链。确认每个成员归属后才能转换成目录软链。
# Codex 等产品的发现器可能忽略软链形式的 SKILL.md。
if [ "$MODE" = install ] && [ -d "$TARGET_HOME/$HUB" ] && [ ! -L "$TARGET_HOME/$HUB" ]; then
    if awk -F '\t' -v p="$HUB" '$1=="D" && $2=="owned" && $3==p {found=1} END {exit !found}' "$TEMP/old"; then
        MIGRATE_HUB=1
    elif [ "$ADOPT_LEGACY" -eq 1 ] && [ -f "$LEGACY" ] && [ ! -L "$LEGACY" ]; then
        MIGRATE_HUB=1
    fi
    if [ "$MIGRATE_HUB" -eq 1 ]; then
        for member in "$TARGET_HOME/$HUB"/* "$TARGET_HOME/$HUB"/.[!.]* "$TARGET_HOME/$HUB"/..?*; do
            [ -e "$member" ] || [ -L "$member" ] || continue
            asset=${member##*/}
            case "$asset" in
                .xian-global-managed)
                    [ -f "$member" ] && [ ! -L "$member" ] || conflict "modified legacy marker"
                    ;;
                SKILL.md|install.sh|prompts|references|hooks|policy.example.conf)
                    expected=$(awk -F '\t' -v p="$HUB/$asset" '$1=="L" && $2=="owned" && $3==p {print $4}' "$TEMP/old")
                    if [ "$HAD_STATE" -eq 0 ]; then expected="$SOURCE/$asset"; fi
                    [ -n "$expected" ] && matches L "$HUB/$asset" "$expected" || conflict "modified/borrowed legacy resource: $asset"
                    ;;
                *) conflict "extra legacy hub content (preserved): $asset" ;;
            esac
        done
    fi
fi
while IFS="$TAB" read -r kind rel target; do
    safe_parent "$rel" || { conflict "symlink/non-directory parent: $rel"; continue; }
    if [ "$kind" = L ] && [ "${rel#"$HUB/"}" != "$rel" ] && [ ! -e "$target" ]; then
        conflict "missing source: $target"
    fi
    old_owner=$(awk -F '\t' -v p="$rel" '$3==p {print $2}' "$TEMP/old")
    old_target=$(awk -F '\t' -v p="$rel" '$3==p {print $4}' "$TEMP/old")
    owner=owned
    if [ "$rel" = "$HUB" ] && [ "$MIGRATE_HUB" -eq 1 ]; then
        owner=owned
    elif [ -n "$old_owner" ]; then
        owner=$old_owner
        if exists "$rel" && ! matches "$kind" "$rel" "$old_target"; then
            conflict "modified managed entry (preserved): $rel"
        elif [ "$owner" = borrowed ] && ! matches "$kind" "$rel" "$target"; then
            conflict "external entry cannot be repaired automatically: $rel"
        fi
    elif exists "$rel"; then
        if matches "$kind" "$rel" "$target"; then
            owner=borrowed
            if [ "$ADOPT_LEGACY" -eq 1 ] && [ -f "$LEGACY" ] && [ ! -L "$LEGACY" ]; then owner=owned; fi
        else
            conflict "external entry (preserved): $rel"
        fi
    fi
    record "$kind" "$owner" "$rel" "$target"
    if [ "$MODE" = verify ] || [ "$MODE" = status ]; then
        if [ -z "$old_owner" ]; then conflict "unregistered: $rel"
        elif matches "$kind" "$rel" "$target" && [ -e "$TARGET_HOME/$rel" ]; then
            echo "current: $rel ($owner)"
        else conflict "missing, dangling or outdated: $rel"; fi
    fi
done < "$TEMP/desired"

# 旧清单驱动卸载/退役，不依赖当前源文件枚举。
while IFS="$TAB" read -r kind owner rel target; do
    [ -n "$kind" ] || continue
    if awk -F '\t' -v p="$rel" '$2==p {found=1} END {exit !found}' "$TEMP/desired"; then continue; fi
    if [ "$MODE" = status ] || [ "$MODE" = verify ]; then conflict "retired entry needs install reconciliation: $rel"; continue; fi
    safe_parent "$rel" || { conflict "unsafe parent: $rel"; continue; }
    if [ "$owner" = owned ] && exists "$rel" && ! matches "$kind" "$rel" "$target"; then
        echo "preserved: modified entry $rel"
    fi
done < "$TEMP/old"
if [ "$FAILED" -ne 0 ]; then
    echo "No files written." >&2
    exit 1
fi
if [ "$MODE" = status ] || [ "$MODE" = verify ]; then
    echo "Links verified. Agent runtime discovery is NOT checked; open a new session and invoke xian-commit."
    exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then echo "dry-run: $MODE; no files written"; exit 0; fi
mkdir -p "$TARGET_HOME/.agents"
LOCK="$TARGET_HOME/.agents/.xian-commit-sync.lock"
if ! mkdir "$LOCK" 2>/dev/null; then LOCK=""; echo "Another sync is running (or a stale lock needs inspection)." >&2; exit 1; fi
if [ -f "$STATE" ]; then
    cmp -s "$STATE" "$TEMP/old" || { echo "Manifest changed; retry." >&2; exit 1; }
elif [ -s "$TEMP/old" ]; then echo "Manifest disappeared; retry." >&2; exit 1; fi

KEEP_HUB=0
if [ "$MODE" = uninstall ]; then
    while IFS="$TAB" read -r kind owner rel target; do
        case "$rel" in "$HUB"|"$HUB/"*) continue ;; esac
        if [ "$owner" = borrowed ] && matches "$kind" "$rel" "$target"; then
            KEEP_HUB=1
        fi
    done < "$TEMP/old"
fi
while IFS="$TAB" read -r kind owner rel target; do
    [ -n "$kind" ] || continue
    if awk -F '\t' -v p="$rel" '$2==p {found=1} END {exit !found}' "$TEMP/desired"; then continue; fi
    [ "$owner" = owned ] || continue
    if [ "$KEEP_HUB" -eq 1 ]; then
        case "$rel" in "$HUB"|"$HUB/"*) continue ;; esac
    fi
    if [ "$kind" = L ] && matches "$kind" "$rel" "$target"; then
        unlink "$TARGET_HOME/$rel"
        echo "removed: $rel"
    fi
done < "$TEMP/old"
if [ "$MODE" = uninstall ]; then
    if [ "$KEEP_HUB" -eq 1 ]; then
        echo "Shared hub retained for borrowed product links; remove those manually before retrying uninstall."
        exit 0
    fi
    if awk -F '\t' '$1=="D" && $2=="owned" {found=1} END {exit !found}' "$TEMP/old"; then
        rmdir "$TARGET_HOME/$HUB" 2>/dev/null || true
    fi
    [ ! -f "$STATE" ] || rm -f "$STATE"
    echo "Uninstalled recorded owned links; external and modified files preserved."
    exit 0
fi
if [ "$MIGRATE_HUB" -eq 1 ]; then
    for asset in SKILL.md install.sh prompts references hooks policy.example.conf; do
        if [ -L "$TARGET_HOME/$HUB/$asset" ]; then unlink "$TARGET_HOME/$HUB/$asset"; fi
    done
    if [ -f "$LEGACY" ] && [ ! -L "$LEGACY" ]; then rm -f "$LEGACY"; fi
    rmdir "$TARGET_HOME/$HUB"
fi
while IFS="$TAB" read -r kind owner rel target; do
    [ "$owner" = owned ] || continue
    if [ "$kind" = D ]; then mkdir -p "$TARGET_HOME/$rel"; continue; fi
    if matches "$kind" "$rel" "$target"; then continue; fi
    mkdir -p "$TARGET_HOME/${rel%/*}"
    if [ -L "$TARGET_HOME/$rel" ]; then unlink "$TARGET_HOME/$rel"; fi
    ln -s "$target" "$TARGET_HOME/$rel"
    echo "linked: $rel"
done < "$TEMP/next"
STATE_TEMP=$(mktemp "$TARGET_HOME/.agents/.xian-commit-manifest.XXXXXX")
cp "$TEMP/next" "$STATE_TEMP"
mv -f "$STATE_TEMP" "$STATE"
if [ "$ADOPT_LEGACY" -eq 1 ] && [ -f "$LEGACY" ] && [ ! -L "$LEGACY" ]; then rm -f "$LEGACY"; fi
echo "Installed xian-commit only. Restart Agent sessions to refresh discovery."
