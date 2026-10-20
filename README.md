# xian-commit

[English](README_EN.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**xian-commit 是一个可安装到 Codex、Claude Code、Qoder 等 AI Coding Agent 项目中的 Git 交付治理 Skill。**

它让 Agent 继续使用标准 Git，同时在提交范围、Commit Message 和推送边界提供可配置的确定性校验；配套 Git Hooks 是这个 Skill 的确定性执行层。

它不是 Node/Python 包，也不是常驻服务；运行时依赖 Git、兼容 POSIX 的 shell 与标准 Unix 工具，以及用于中文与 emoji 提交信息检查的 Perl。

> **安装范围：工程级执行 + 可选用户级发现。**
> `install.sh` 只把 Skill、policy 和 hooks 写入当前目标 Git 仓库，不会直接写入 `~/.codex/skills`、`~/.claude/skills` 或 `~/.qoder-cn/skills`。每个需要 hooks/policy 的工程仍必须单独安装。
> `sync-global.sh` 是可选步骤：它只把本产品的 `xian-commit` Skill 注册到用户级目录，不导出本工程安装的其他 Skills。它不安装 hooks 或 policy，也不替代工程级安装。本项目不依赖 Harness。

## 为什么需要 xian-commit

AI Coding Agent 能写代码，也会在交付最后一步犯具体而昂贵的错误：把 runtime 或敏感文件暂存、写出 `feat: feat ...` 这类重复类型标题，或未检查 upstream 是否分叉就直接推送。

`xian-commit` 把责任拆开：

- Agent Skill 负责归因改动、规划提交并写 Commit Message；
- policy 只保存规则，不保存运行状态或口头授权；
- Git hooks 执行确定性的本地边界校验；
- remote push 是最后一个外部副作用，按 policy 与 Git 事实处理。

它面向 AI Coding Agent 的 Git delivery，不是通用 Git 客户端，也不是业务质量门禁。

## 安装与更新

### 通过 Skill 安装 hooks（已有全局 Skill 时推荐）

Agent 已能发现 `xian-commit` 时,在目标工程中直接说:

> 使用 xian-commit，为当前工程安装 Git hooks。先检查已有 hooks，保留现有配置，安装后验证，不提交或推送。

Skill 会定位目标仓库和自身安装源、检查冲突、调用 `install.sh hooks`,再读取 `references/check-project.sh` 的结果。无需额外安装工程级 Skill。尚未全局安装时,先完成下方「跨 Agent 用户级安装」,重开 Agent 会话后再发出请求。

检查或更新也可直接说“使用 xian-commit，检查当前工程的 hooks 是否已安装”或“使用 xian-commit，将当前工程的 hooks 更新到本地安装源版本”。检查请求只读;更新请求同样先处理冲突,不会自动拉取源仓库或提交、推送。

手动执行等价流程时,先检查已有 hooks 与 `core.hooksPath`,确认没有待处理的覆盖冲突后,在目标工程运行:

```sh
cd /path/to/your-project
sh ~/.agents/skills/xian-commit/install.sh hooks
sh ~/.agents/skills/xian-commit/references/check-project.sh
```

- `hooks` 只安装四个 hooks,不会复制 Skill 或创建、修改 `.xian-commit/config`。没有配置时不会自动 push;已有配置仍然生效,包括 `auto-safe`。
- 四个 hook 均为 `current` 且汇总为 `hooks=current`,表示 Git 有效路径下的文件内容与执行权限检查通过。`hooks=unverified` 不算通过,即使检查脚本退出码为 0。此检查不执行 hooks,不是实际提交测试。
- **仅安装 hooks 后用上述检查脚本,不要用 `install.sh verify`**;后者要求完整工程级 Skill 和 policy。安装器末尾的通用提示也按此区分。
- Skill 遇到内容不同的已有 hooks 会先说明冲突,获得替换许可后才继续;安装器本身会备份后替换,不会自动串联。设置了 `core.hooksPath` 时停止直接安装,不擅自清除 Husky 等配置。linked worktree 默认共享 hooks,安装会影响同一仓库的其他 worktree。

这是本地客户端防护,不是不可绕过的服务端门禁。全局 Skill 安装一次即可发现;hooks 仍需按目标仓库安装。

### 首次完整安装（工程级 Skill、policy 与 hooks）

先克隆本仓库，再在**另一个目标 Git 仓库**中安装：

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

默认安装会写入 Codex 与 Claude Code 的 Skill、提交信息 prompt、lifecycle 参考脚本、policy 和四个 hooks。已有 `.xian-commit/config` 会保留，不会被安装或更新覆盖。

hooks 会从下一次 `git commit` 或 `git push` 起生效。若 Codex 或 Claude Code 会话已经打开，请在目标项目中重新打开会话，让项目级 Skills 被重新扫描。

### 更新已有工程

完整安装的工程保存自己的项目级 Skill、policy 和 hooks，因此 xian-commit 源仓库更新后，需要在每个已接入工程中分别执行更新。若采用全局 Skill + hooks-only,更新源仓库后只需重复上面的 hooks 安装与检查流程,不要使用下面的完整更新命令。

完整安装的更新方式是先更新本地的 xian-commit 源仓库，再从目标工程运行：

```sh
git -C /path/to/xian-commit pull --ff-only

cd /path/to/your-project
sh /path/to/xian-commit/install.sh status
sh /path/to/xian-commit/install.sh update
sh /path/to/xian-commit/install.sh verify
```

`status` 是只读检查，可先确认哪些受管理资源缺失或与当前源版本不同；`update` 会刷新 Codex/Claude Code Skill、prompt、references、`policy.example.conf` 和四个 hooks；`verify` 再检查安装完整性与 hook 可执行性。更新完成后，重新打开目标工程中的 Codex / Claude Code 会话，让新版项目级 Skill 生效。

更新时的覆盖与保留规则：

- `.xian-commit/config` 是目标工程自己的 policy，首次创建后不会被后续安装或更新覆盖。
- 受管理的 Skill、prompt、references、`policy.example.conf` 和 hooks 会更新为当前 xian-commit 源版本。
- 首次遇到内容不同的同名 hook 时，安装器会保存为 `*.pre-xian-commit.bak`；后续重复安装或更新不会覆盖这份最初备份。活动 hook 仍会更新为当前 xian-commit 版本，备份也不会自动串联执行。
- linked worktree 使用 Git 解析出的共享 hooks 目录，同一个主仓库的 worktree 无需分别维护私有 hooks。
- 若 `git config --show-origin --get core.hooksPath` 有输出，安装、更新和 `verify` 会明确拒绝。不要为了安装而盲目清除 Husky 等现有配置；应先决定由哪个工具管理 hooks，再手动串联所需逻辑。

如果 `git pull --ff-only` 因本地修改或分叉失败，先处理 xian-commit 源仓库本身的 Git 状态；不要用强制覆盖来更新安装源。

### 跨 Agent 用户级安装（可选）

如果希望不同产品在所有工程中发现同一份 `xian-commit`，可以运行：

```sh
sh /path/to/xian-commit/sync-global.sh install
sh /path/to/xian-commit/sync-global.sh verify
```

共享 hub 为 `~/.agents/skills/xian-commit`，整个目录链接回源仓库，保留真实的 `SKILL.md`，避免部分发现器忽略文件软链。默认建立下面五种产品入口；产品未安装时，创建目录本身不会安装产品。可用 `--agents codex,claude,qoder-cn` 选择子集，之后的 `install/status/verify` 使用相同参数。

| 产品 / 选择值 | 用户级入口 |
| --- | --- |
| Codex / `codex` | `~/.codex/skills/xian-commit` |
| Claude Code / `claude` | `~/.claude/skills/xian-commit` |
| Qoder CN / `qoder-cn` | `~/.qoder-cn/skills/xian-commit` |
| Qoder / Qoder CLI / `qoder` | `~/.qoder/skills/xian-commit` |
| QoderWork / `qoderwork` | `~/.qoderwork/skills/xian-commit` |

Qoder 产品不是同一个目录：[Qoder CLI 文档](https://docs.qoder.com/cli/Skills)、[QoderWork 文档](https://docs.qoder.com/qoderwork/skills)。目录适配不等于每个产品版本已完成运行时认证。

常用命令：

| 命令 | 写入位置 | 用途 |
| --- | --- | --- |
| `sh sync-global.sh install` | 用户级软链与归属清单 | 注册或刷新 `xian-commit` |
| `sh sync-global.sh status` | 否 | 查看每个产品入口是否 current/missing/conflict |
| `sh sync-global.sh verify` | 否 | 校验链接、源资源和清单；不验证 Agent 实际加载 |
| `sh sync-global.sh uninstall` | 用户级软链 | 只移除本工具管理的软链，保留外部文件 |
| `sh sync-global.sh install --dry-run` | 否 | 预演同步，不写文件 |

更新、迁移与卸载：

- 更新源仓库后，现有软链立即指向新内容；重新运行 `install`、`verify` 并重开 Agent 会话。若需要固定版本，固定源仓库版本或使用工程级副本。
- 新版将归属记录在 `~/.agents/xian-commit-sync.tsv`。仓库搬迁后，从新位置运行 `install` 可修复原受管链接；源文件删除会使 `verify` 失败，但仍能用任一完整源码副本执行 `uninstall`。
- 缩减 `--agents` 列表时，只清理已记录且未被用户替换的旧入口。真实同名目录、异目标链接会阻断安装；同目标手工链接标记为 `borrowed`，卸载不会删除。若手工产品入口仍依赖共享 hub，卸载保留 hub，提示手工处理后再重试。
- 旧版没有归属清单，无法可靠判断哪些链接是手工创建。确认现有 `xian-commit` 链接可以由安装器接管后，先运行一次 `install --adopt-legacy`，再搬迁或卸载。此选项仅接管 `xian-commit`，不接管其他 Skills；旧版导出的其他 `xian-*` 入口需单独检查和处理。
- `--home /path/to/home` 支持隔离试装；`--dry-run` 不写入目标目录。

项目守卫与实际验证：

- 用户级安装只提供发现入口。没有 `.xian-commit/config` 时采用通用提交纪律；有配置也不代表 hooks 生效，其他工具目录更不能作为安装证明。
- 从目标仓库运行 `sh ~/.agents/skills/xian-commit/references/check-project.sh`，检查 Git 的有效 hooks 路径及四个 hook 的内容与执行权限。`hooks=unverified` 不能视作防护已经开启。
- `sync-global.sh verify` 成功只证明链接和资源可访问。重开产品会话，在没有工程级 Skill 的临时工程中显式调用 `xian-commit`，让 Agent 返回 Skill 的实际来源路径和项目守卫结论，不执行 commit/push。这才是该产品当前版本的发现 smoke test。
- Skill 可发现不等于每次自动触发。若希望稳定采用，应显式调用 Skill，或在该产品支持的用户级指令中添加 Git 交付路由；本脚本不自动改写用户指令。

可选的本机发现测试（需要 Node.js 和对应 CLI，不属于 shell 运行时依赖）：

```sh
node scripts/check-agent-discovery.mjs codex claude
```

它在临时空目录中读取产品的初始化发现清单，不发送模型请求、不执行 Git 交付。Qoder CN 可在“扩展 → 已安装 → 技能”中搜索 `xian-commit`。这两种检查验证发现层，不验证模型是否真的采用规范；实际调用仍按上面的 smoke test 完成。

## 推荐的项目接入方式

安装器只管理 xian-commit 自己的 Skill、prompt、policy 和 hooks，**不会自动修改目标项目的 `AGENTS.md` 或 `CLAUDE.md`**。这两个文件属于目标项目，里面通常还有架构、测试和业务约束；由安装器直接改写并不安全。

推荐按以下顺序接入：

1. 在目标仓库通过 Skill 安装 hooks 并检查;需要工程级 Skill 和 policy 时才选完整安装和 `verify`。
2. 如已有 `.xian-commit/config`,检查其中的 `auto-safe`、`explicit-only` 或 `never` 是否符合团队习惯;hooks-only 无配置时不自动 push。
3. 重新打开 Codex / Claude Code / Qoder 会话，让项目级 Skill 或用户级同步结果被重新扫描。
4. 用一次小改动实际执行 commit；确认 hook 提示、提交信息和 push 边界符合预期后，再推广到团队。

如果 Agent 能稳定发现全局或项目级 Skill，不需要再改入口文件。如果希望把 Git 交付入口写得更明确，可以在目标项目已有的文件中增加一条简短路由。以下路径示例适用于完整工程级安装;全局 Skill 用户应写“使用 xian-commit Skill，遵守已有项目 policy”，不要引用不存在的工程级副本。

`AGENTS.md`（Codex / 通用 Agent）：

```markdown
## Git 交付

涉及 commit、push 或交付收口时，使用项目级 `.codex/skills/xian-commit/SKILL.md`，
并遵守 `.xian-commit/config`；不得绕过 Git Hooks。
```

`CLAUDE.md`（Claude Code）：

```markdown
## Git 交付

涉及 commit、push 或交付收口时，使用项目级 `.claude/skills/xian-commit/SKILL.md`，
并遵守 `.xian-commit/config`；不得绕过 Git Hooks。
```

入口文件只负责告诉 Agent“什么时候使用 xian-commit”。完整流程继续以安装后的 `SKILL.md` 为准，项目策略以 `.xian-commit/config` 为准，确定性拦截以 Git Hooks 为准。不要把整份 Skill 复制进 `AGENTS.md` / `CLAUDE.md`，否则升级后容易出现多份规则不一致。

## 它是怎么工作的

安装后，Agent 仍调用 `git add`、`git commit` 与 `git push`；没有另一套 Git 命令需要学习。Skill 引导 Agent 做提交归因与计划，policy 提供项目规则，hooks 在 Git 调用点兜底。

默认 `push.mode=auto-safe` 时，自动普通推送必须同时满足：本轮刚创建 commit、tracked/staged 工作区干净、有 upstream、能读取 remote head、本地只 ahead 而不 behind/diverged、当前分支不受保护。未跟踪文件本身不会阻断 auto-safe。

任一条件不满足时不会自动推送；即使 auto-safe 推送失败，本地 commit 仍然成功。缺少配置时，对自动推送采取保守的 `explicit-only` 行为。

## 四道 Git 护栏

| Hook | 拦截/执行内容 | 拒绝或回退行为 |
| --- | --- | --- |
| `pre-commit` | 检查 staged 路径，拦截敏感文件、临时文件和项目 deny 规则 | 拒绝 commit，并提示用 `git reset HEAD <files>` 移出暂存区 |
| `commit-msg` | 校验类型、中文标题、正文、重复类型与 emoji；放行 `Merge ` / `Revert "` 开头的 Git 生成消息 | 拒绝普通不合规 commit，按提示重新提交 |
| `post-commit` | 在 `auto-safe` 条件全部成立时执行普通 push | 条件不足时跳过；push 失败只报告，本地 commit 保持成功 |
| `pre-push` | 仅检查当前检出的普通分支及其 upstream 的 protected branch、`never` policy 与落后状态 | 拒绝或提示先 `git pull --rebase`；无 upstream 时仅提示首次 push 设置 upstream |

这些 hooks 同样作用于人手输入的 `git commit` / `git push`，不是只对 Agent 生效。

路径检查支持子目录、中文、空格和换行文件名，并允许删除已跟踪的敏感文件；默认拒绝 `*.pem` 等私钥路径。删除 Git 中的文件不代表密钥已经从历史中清除，泄露后的凭据仍需轮换。

若目标仓库已有内容不同的同名 hook，安装器会备份为 `*.pre-xian-commit.bak`，再写入 xian-commit 的 hook。备份 hook **不会自动串联执行**；请按目标项目的实际需求手动组合两者逻辑后再使用。linked worktree 会将 hooks 安装到 Git 解析的共享 hooks 目录；若已配置 `core.hooksPath`，安装、更新和 `verify` 会明确拒绝，避免覆盖 Husky 等现有 hook 管理器。请先确认 hook 管理权，再选择保留现有配置并手动串联，或在确认不再需要时取消该配置。

## 与常见工具的区别

| 工具 | 官方定位 | xian-commit 的关注点 |
| --- | --- | --- |
| [Husky](https://typicode.github.io/husky/) | 管理原生 Git hooks，并可在 commit/push 时运行检查 | 面向 Agent 的改动归因、提交信息 policy、staged-path 防护与安全推送边界 |
| [Commitizen](https://commitizen-tools.github.io/commitizen/) | 提交规范，以及版本、changelog、release 自动化 | 不做版本号、changelog 或 release 管理 |
| [pre-commit](https://pre-commit.com/) | 管理多语言 pre-commit hooks | 不替代其生态，专注 Agent 交付末端的 Git 规则 |

它们可以在同一仓库出现，但 xian-commit 不声明替代关系，也不提供自动互操作或自动 hook 编排。

## 配置

目标项目的规则文件是 `.xian-commit/config`，格式见 [policy.example.conf](policy.example.conf)。它只保存规则；不要在其中记录 change 状态、Agent 计划或一次性 push 授权。

| Key | 默认值 | 作用 |
| --- | --- | --- |
| `push.mode` | `auto-safe` | `auto-safe`、`explicit-only` 或 `never` |
| `branch.protected` | 空 | 拒绝或跳过匹配的分支 glob |
| `path.allow` | 空 | 在 deny 检查前允许的 staged 路径 glob |
| `path.deny` | 空 | 额外拒绝的 staged 路径 glob |
| `message.types` | `feat fix refactor docs test chore` | 允许的提交类型 |
| `message.title_language` | `zh` | `zh` 要求标题包含中文；`any` 跳过该检查 |
| `message.body_required` | `true` | 是否要求标题后的正文 |

`push.mode` 的含义：

- `auto-safe`：仅在安全条件同时成立时，post-commit 自动普通推送。
- `explicit-only`：关闭自动推送，当前用户明确要求 push 后才由 Agent 推送。
- `never`：pre-push 在当前检出的普通分支上拒绝推送；旧值 `disabled` 作为 `never` 的兼容别名。

`path.allow` 会先于内置 denylist 与 `path.deny` 生效，适合项目明确拥有的协议证据路径。普通 `*.log` 不会被默认拒绝；如需收紧请用 `path.deny`。

pre-push 只判断当前检出的普通分支及其 upstream：detached HEAD 会直接放行，也不会解析任意 `git push` 的远端目标 ref。因此 `branch.protected` 与 `never` 是客户端护栏，不能替代服务端分支保护。

## 安装与维护命令

`install.sh` 的命令均以当前目标 Git 仓库为作用域；用户级发现由 `sync-global.sh` 单独管理，二者可以同时使用。

| 命令 | 是否写入目标仓库 | 用途 |
| --- | --- | --- |
| `sh /path/to/xian-commit/install.sh` / `sh /path/to/xian-commit/install.sh all` | 是 | 安装全部 Agent 资产、policy 与 hooks |
| `sh /path/to/xian-commit/install.sh update` | 是 | 更新同一套受管理资源，保留现有 config |
| `sh /path/to/xian-commit/install.sh hooks` | 是 | 仅安装四个 Git hooks |
| `sh /path/to/xian-commit/install.sh skill` | 是 | 仅安装 Codex/Claude Code Skill、prompt、参考资料与 policy |
| `sh /path/to/xian-commit/install.sh verify` | 否 | 检查完整工程级安装并做 hook smoke test；不适用于 hooks-only |
| `sh /path/to/xian-commit/references/check-project.sh` | 否 | 检查实际 hooks 内容与执行权限；hooks-only 也适用，须读取 `hooks=current/unverified` |
| `sh /path/to/xian-commit/install.sh status` | 否 | 显示已安装资源与源文件是否一致 |
| `sh /path/to/xian-commit/install.sh uninstall` | 是 | 移除受管理资源；保留 config 和不同内容的 hooks |
| `sh /path/to/xian-commit/sync-global.sh install` | 否（写用户级软链） | 将 `xian-commit` 注册到共享 hub 与选定产品目录 |
| `sh /path/to/xian-commit/sync-global.sh status` | 否 | 只读查看用户级软链状态 |
| `sh /path/to/xian-commit/sync-global.sh verify` | 否 | 检查用户级软链、断链和冲突 |
| `sh /path/to/xian-commit/sync-global.sh uninstall` | 否（移除用户级软链） | 只移除本工具管理的用户级软链 |

## Agent 与平台兼容性

| 对象 | 支持方式 |
| --- | --- |
| Codex | 工程级 `.codex/skills/xian-commit` + hooks；可选用户级入口 |
| Claude Code | 工程级 `.claude/skills/xian-commit` + hooks；可选用户级入口 |
| Qoder / Qoder CN / QoderWork | 工程级 hooks/policy 由 `install.sh` 安装；用户级 Skill 按上表区分产品目录，需在所用版本上实际确认发现 |
| 其他 Coding Agents | 可独立使用 hooks，或在支持 `~/.agents/skills` 时复用用户级 hub；不宣称所有产品自动识别 |
| Ubuntu | CI 已验证 |
| macOS | CI 已验证 |

当前 CI 仅在 Ubuntu 与 macOS 运行；未声明 Windows 支持。

## 边界与限制

`xian-commit` 不做代码 review、业务验证或质量 gate、release 管理、版本号更新，也不生成 changelog。它不判断“功能是否完成”，只帮助把已经确认范围的改动以安全、可解释的 Git 方式交付。

它也不会自动修改目标项目的 `.gitignore`，不会替你判断备份 hook 应如何编排，更不会绕过 Git 的远端权限、分支保护或冲突处理。用户级同步只负责让 Agent 产品发现 skill；hooks、policy 和项目状态仍以目标工程的工程级安装为准。

## 开发与贡献

本地测试见 [tests/run_tests.sh](tests/run_tests.sh)：

```sh
sh tests/run_tests.sh
```

CI 在 `ubuntu-latest` 与 `macos-latest` 上运行 shell 语法检查、测试与安装 smoke test。欢迎围绕可复现问题提交聚焦的 Issues 与 PRs。

请勿在公开 Issue 中粘贴凭据、私有仓库内容或可被直接滥用的漏洞利用细节。

## License

MIT，见 [LICENSE](LICENSE)。
