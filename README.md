# xian-commit

[English](README_EN.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**面向 Codex、Claude Code、Qoder 等 AI Coding Agent 的 Git 交付治理 Skill。**

xian-commit 让 Agent 继续使用标准 `git`，同时在三个环节提供可配置的确定性校验：

- **提交范围**：拦截敏感文件、临时文件和项目自定义的 deny 路径；
- **提交信息**：校验 type、中文标题、正文、重复前缀与 emoji；
- **推送边界**：满足安全条件才自动普通推送，并在 push 前检查 behind、protected branch 与 `never` policy。

它由 Agent Skill、项目 policy 和四个 Git hooks 组成：Skill 负责工作流与判断，policy 保存规则，hooks 在 Git 调用点执行拦截。

> **安装范围**：`install.sh` 只作用于当前目标仓库；`sync-global.sh` 只负责用户级 Skill 发现，不安装 hooks 或 policy。每个需要 hooks 的仓库仍需单独安装。
>
> **安全边界**：这是本地客户端护栏，不是服务端强制门禁。`git commit --no-verify` 仍可绕过 hooks；关键分支保护、权限和 CI 仍应配置在远端。

## 目录

- [为什么需要 xian-commit](#为什么需要-xian-commit)
- [快速开始](#快速开始)
- [四个 Git 护栏](#四个-git-护栏)
- [配置](#配置)
- [多 Agent 与平台](#多-agent-与平台)
- [推荐的项目接入方式](#推荐的项目接入方式)
- [它是怎么工作的](#它是怎么工作的)
- [与常见工具的区别](#与常见工具的区别)
- [仓库结构](#仓库结构)
- [边界与限制](#边界与限制)
- [开发与贡献](#开发与贡献)

## 为什么需要 xian-commit

AI Coding Agent 能写代码，却常在交付最后一步犯错：把运行产物或密钥一起暂存、写出 `feat: feat ...` 这类重复标题，或在 upstream 已分叉时直接推送。

xian-commit 把责任拆开：

- Agent Skill 负责归因改动、规划提交并撰写 Commit Message；
- policy 只保存规则，不保存运行状态或口头授权；
- Git hooks 执行确定性的本地边界校验；
- remote push 是最后一个外部副作用，按 policy 与 Git 事实处理。

它关注“改动如何安全、可解释地进入 Git”，不判断功能是否完成。

## 快速开始

### 环境要求

- Git；
- 兼容 POSIX 的 shell，以及 `awk`、`sed`、`xargs`、`mktemp` 等标准 Unix 工具；
- Perl，用于中文标题与 emoji 检查；
- 可选：Node.js，仅用于本机 Agent 发现测试。

CI 在 Ubuntu 与 macOS 上运行；未声明 Windows 支持。

### 方式一：完整工程级安装

适合希望 Agent 通过项目级 Skill 发现 xian-commit 的仓库。先克隆本仓库，再进入目标仓库安装：

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

默认安装会写入：

- Codex 与 Claude Code 的项目级 Skill；
- 提交信息 prompt 和 `references/` 参考脚本；
- `policy.example.conf` 和 `.xian-commit/config`（若不存在）；
- 四个 Git hooks。

已有 `.xian-commit/config` 不会被覆盖。hooks 从下一次 `git commit` 或 `git push` 起生效；如 Codex / Claude Code 会话已打开，请重开会话以重新扫描项目级 Skill。

### 方式二：全局 Skill + 按仓库安装 hooks（多 Agent / 多仓库推荐）

如果希望多个工程共享同一份 Skill，又不想在每个仓库复制项目级 Skill：

```sh
# 1. 注册用户级 Skill（一次）
sh /path/to/xian-commit/sync-global.sh install
sh /path/to/xian-commit/sync-global.sh verify

# 2. 在每个目标仓库安装 hooks
cd /path/to/your-project
sh ~/.agents/skills/xian-commit/references/check-project.sh
sh ~/.agents/skills/xian-commit/install.sh hooks
sh ~/.agents/skills/xian-commit/references/check-project.sh
```

`hooks` 只安装四个 hooks，不复制 Skill，也不创建或修改 `.xian-commit/config`。没有配置时不会自动 push；已有配置（包括 `auto-safe`）仍然生效。未使用全局安装时，把 `~/.agents/skills/xian-commit` 换成实际源码路径。

也可以直接在 Agent 中发起：

> 使用 xian-commit，为当前工程安装 Git hooks。先检查已有 hooks，保留现有配置，安装后验证，不提交或推送。

Skill 会先做只读检查；已是 `hooks=current` 就跳过安装。只有首次接入、更新或修复时才写入，并在覆盖前说明冲突。

### 验证安装

| 检查 | 适用场景 | 说明 |
| --- | --- | --- |
| `install.sh verify` | 完整安装 | 检查 Skill、prompt、references、config 与 hooks，并执行 `commit-msg` / `pre-commit` smoke test；不适用于 hooks-only |
| `references/check-project.sh` | 任何安装 | 检查 policy、Git 有效 hooks 路径及四个 hook 的内容与执行权限；必须读到 `hooks=current` |
| `sync-global.sh verify` | 全局 Skill | 只校验用户级链接与资源，不验证 Agent 是否实际加载 |

`hooks=unverified` 不算通过，即使检查脚本退出码为 0。`check-project.sh` 只比较内容与权限，不执行真实提交。

### 更新与卸载

- **完整安装**：先更新源仓库（建议 `git pull --ff-only`），再在目标仓库运行 `install.sh status`、`install.sh update`、`install.sh verify`；`update` 会保留现有 config。`pull` 因本地修改或分叉失败时，先处理源仓库状态，不要强制覆盖安装源。
- **hooks-only**：先运行 `check-project.sh`；仍为 `hooks=current` 就跳过，不为 README 或普通业务代码变化重装 hooks。
- **全局 Skill**：源仓库更新后软链立即指向新内容；运行 `sync-global.sh install` / `verify`，并重开 Agent 会话。
- **卸载**：`install.sh uninstall` 移除受管理资源，保留 config 和内容已被用户修改的 hooks；`sync-global.sh uninstall` 只移除本工具管理的用户级链接。

**覆盖与冲突**：首次遇到内容不同的同名 hook 会备份为 `*.pre-xian-commit.bak`，之后不覆盖首份备份，也不自动串联执行。设置了 `core.hooksPath` 时，`install.sh` 的 `all`、`update`、`hooks`、`verify` 会明确拒绝，避免覆盖 Husky 等管理器。linked worktree 默认共享 hooks，安装会影响同一仓库的其他 worktree。

### 命令速查

`install.sh` 的命令均以当前目标 Git 仓库为作用域；用户级发现由 `sync-global.sh` 单独管理，二者可以同时使用。下表中的脚本名省略了源码路径；实际执行时请使用 `/path/to/xian-commit/...` 或全局 hub 路径。

| 命令 | 写入目标仓库 | 用途 |
| --- | --- | --- |
| `sh install.sh` / `sh install.sh all` | 是 | 安装全部 Agent 资产、policy 与 hooks |
| `sh install.sh update` | 是 | 更新同一套受管理资源，保留现有 config |
| `sh install.sh hooks` | 是 | 仅安装四个 Git hooks |
| `sh install.sh skill` | 是 | 仅安装 Codex/Claude Code Skill、prompt、references 与 policy（含首次 config） |
| `sh install.sh verify` | 否 | 检查完整安装并执行 smoke test；不适用于 hooks-only |
| `sh install.sh status` | 否 | 显示已安装资源与源文件是否一致 |
| `sh install.sh uninstall` | 是 | 移除受管理资源，保留 config 和不同内容的 hooks |
| `sh sync-global.sh install` | 否（写用户级链接） | 注册或刷新用户级 Skill |
| `sh sync-global.sh status` | 否 | 查看用户级链接状态 |
| `sh sync-global.sh verify` | 否 | 校验链接、资源与归属清单 |
| `sh sync-global.sh uninstall` | 否（移除用户级链接） | 只移除本工具管理的用户级链接 |

## 四个 Git 护栏

| Hook | 拦截/执行内容 | 拒绝或回退行为 |
| --- | --- | --- |
| `pre-commit` | 检查 staged 路径，拦截敏感文件、临时文件和项目 deny 规则 | 拒绝 commit，并提示用 `git reset HEAD <files>` 移出暂存区 |
| `commit-msg` | 校验类型、中文标题、正文、重复类型与 emoji；仅在对应 Git 操作状态有效时豁免 Merge/Revert 消息 | 拒绝普通不合规 commit，按提示重新提交 |
| `post-commit` | 在 `auto-safe` 条件全部成立时执行普通 push | 条件不足时跳过；push 失败只报告，本地 commit 保持成功 |
| `pre-push` | 检查当前检出的普通分支及其 upstream 的 protected branch、`never` policy 与落后状态 | 拒绝或提示先 `git pull --rebase`；无 upstream 时仅提示首次 push 设置 upstream |

这些 hooks 同样作用于人手输入的 `git commit` / `git push`，不是只对 Agent 生效。

**提交信息默认规则**：type 为 `feat fix refactor docs test chore`，标题需含中文，正文必填，禁止重复 type 前缀和 emoji。

**Merge/Revert 的严格边界**：只有在对应的 merge/revert 操作状态存在且有效时才豁免普通格式。操作完成后，保留默认 `Merge ...` / `Revert "..."` 消息执行 `git commit --amend --no-edit` 会被拒绝；改用符合 policy 的消息即可。普通合规消息的 `--amend --no-edit` 不受影响。这是为避免普通提交伪造标题而有意保留的限制，不要通过 `--no-verify` 绕过。

**路径检查**：支持子目录、中文、空格和换行文件名，允许删除已跟踪的敏感文件；默认拦截 `.xian-relay*`、`*.env`、`*.tmp`、`*.swp`、`*.pem`、`id_rsa`、`.DS_Store` 等。删除 Git 中的文件不代表密钥已从历史中清除，泄露后的凭据仍需轮换。

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

- `auto-safe`：仅在安全条件同时成立时，post-commit 自动普通推送；
- `explicit-only`：关闭自动推送，当前用户明确要求 push 后才由 Agent 推送；
- `never`：pre-push 在当前检出的普通分支上拒绝推送；旧值 `disabled` 作为 `never` 的兼容别名。

完整安装生成的 config 默认使用 `auto-safe`；没有 config 时，post-commit 按 `explicit-only` 处理。`auto-safe` 自动推送要求同时满足：本轮刚创建 commit、tracked/staged 工作区干净、有 upstream、能读取 remote head、本地只 ahead 而不 behind/diverged、当前分支不受保护。未跟踪文件本身不会阻断 auto-safe；任一条件不满足时不会自动推送，即使推送失败，本地 commit 仍然成功。

`path.allow` 会先于内置 denylist 与 `path.deny` 生效，适合项目明确拥有的协议证据路径。普通 `*.log` 不会被默认拒绝；如需收紧请用 `path.deny`。

pre-push 只判断当前检出的普通分支及其 upstream：detached HEAD 会直接放行，也不会解析任意 `git push` 的远端目标 ref。因此 `branch.protected` 与 `never` 是客户端护栏，不能替代服务端分支保护。

## 多 Agent 与平台

| 产品 | 工程级支持 | 用户级入口 |
| --- | --- | --- |
| Codex | `.codex/skills/xian-commit` + hooks | `~/.codex/skills/xian-commit` |
| Claude Code | `.claude/skills/xian-commit` + hooks | `~/.claude/skills/xian-commit` |
| Qoder CN | hooks/policy 由 `install.sh` 安装 | `~/.qoder-cn/skills/xian-commit` |
| Qoder / Qoder CLI | hooks/policy 由 `install.sh` 安装 | `~/.qoder/skills/xian-commit` |
| QoderWork | hooks/policy 由 `install.sh` 安装 | `~/.qoderwork/skills/xian-commit` |
| 其他 Coding Agents | 可独立使用 hooks | 若产品读取 `~/.agents/skills`，可复用 hub |

`install.sh` 只为 Codex 和 Claude Code 安装项目级 Skill；Qoder 产品使用上表的用户级入口，并需在实际版本上确认发现。Qoder 产品不是同一个目录：[Qoder CLI 文档](https://docs.qoder.com/cli/Skills)、[QoderWork 文档](https://docs.qoder.com/qoderwork/skills)。目录适配不等于每个产品版本已完成运行时认证。

### 用户级同步细节

共享 hub 为 `~/.agents/skills/xian-commit`，整个目录链接回源仓库，保留真实的 `SKILL.md`，避免部分发现器忽略文件软链。默认建立上表五种产品入口；即使产品未安装，也会创建对应链接，但这不会安装产品本身。可用 `--agents codex,claude,qoder-cn` 选择子集，之后的 `install/status/verify` 使用相同参数。

- 归属记录在 `~/.agents/xian-commit-sync.tsv`。仓库搬迁后，从新位置运行 `install` 可修复原受管链接；源文件删除会使 `verify` 失败，但仍能用任一完整源码副本执行 `uninstall`。
- 缩减 `--agents` 列表时，只清理已记录且未被用户替换的旧入口。真实同名目录、异目标链接会阻断安装；同目标手工链接标记为 `borrowed`，卸载不会删除。若手工产品入口仍依赖共享 hub，卸载保留 hub，提示手工处理后再重试。
- 旧版没有归属清单，无法可靠判断哪些链接是手工创建。确认现有 `xian-commit` 链接可以由安装器接管后，先运行一次 `install --adopt-legacy`，再搬迁或卸载。此选项仅接管 `xian-commit`，不接管其他 Skills；旧版导出的其他 `xian-*` 入口需单独检查和处理。
- `--home /path/to/home` 支持隔离试装；`--dry-run` 不写入目标目录。

### Agent 发现 smoke test

`sync-global.sh verify` 成功只证明链接和资源可访问。重开产品会话，在没有工程级 Skill 的临时工程中显式调用 `xian-commit`，让 Agent 返回 Skill 的实际来源路径和项目守卫结论，不执行 commit/push。这才是该产品当前版本的发现 smoke test。

可选的本机自动检查（需要 Node.js 和对应 CLI）：

```sh
node scripts/check-agent-discovery.mjs codex claude
```

它在临时空目录中读取产品的初始化发现清单，不发送模型请求、不执行 Git 交付。Qoder CN 可在“扩展 → 已安装 → 技能”中搜索 `xian-commit`。这些检查验证发现层，不验证模型是否真的采用规范。

Skill 可发现不等于每次自动触发。若希望稳定采用，应显式调用 Skill，或在该产品支持的用户级指令中添加 Git 交付路由；本脚本不自动改写用户指令。

## 推荐的项目接入方式

安装器只管理 xian-commit 自己的 Skill、prompt、policy 和 hooks，**不会自动修改目标项目的 `AGENTS.md` 或 `CLAUDE.md`**。这两个文件属于目标项目，通常还有架构、测试和业务约束；由安装器直接改写并不安全。

推荐按以下顺序接入：

1. 在目标仓库通过 Skill 安装 hooks 并检查；需要工程级 Skill 和 policy 时才选完整安装和 `verify`。
2. 如已有 `.xian-commit/config`，检查其中的 `auto-safe`、`explicit-only` 或 `never` 是否符合团队习惯；hooks-only 无配置时不自动 push。
3. 重新打开 Codex / Claude Code / Qoder 会话，让项目级 Skill 或用户级同步结果被重新扫描。
4. 用一次小改动实际执行 commit；确认 hook 提示、提交信息和 push 边界符合预期后，再推广到团队。

如果 Agent 能稳定发现全局或项目级 Skill，不需要再改入口文件。如果希望把 Git 交付入口写得更明确，可以在目标项目已有的文件中增加一条简短路由。以下路径示例适用于完整工程级安装；全局 Skill 用户应写“使用 xian-commit Skill，遵守已有项目 policy”，不要引用不存在的工程级副本。

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

默认完整安装使用 `push.mode=auto-safe`：只有安全条件全部成立时才自动普通推送；条件不足或没有配置时不会自动推送。remote push 是最后一个外部副作用，失败不会回滚已完成的本地 commit。

## 与常见工具的区别

| 工具 | 官方定位 | xian-commit 的关注点 |
| --- | --- | --- |
| [Husky](https://typicode.github.io/husky/) | 管理原生 Git hooks，并可在 commit/push 时运行检查 | 面向 Agent 的改动归因、提交信息 policy、staged-path 防护与安全推送边界 |
| [Commitizen](https://commitizen-tools.github.io/commitizen/) | 提交规范，以及版本、changelog、release 自动化 | 不做版本号、changelog 或 release 管理 |
| [pre-commit](https://pre-commit.com/) | 管理多语言 pre-commit hooks | 不替代其生态，专注 Agent 交付末端的 Git 规则 |

它们可以在同一仓库出现，但 xian-commit 不声明替代关系，也不提供自动互操作或自动 hook 编排。

## 仓库结构

```text
hooks/               四个 Git hooks
install.sh           工程级安装、更新、验证与卸载
sync-global.sh       用户级 Skill 同步
SKILL.md             Agent 工作流与交付边界
prompts/             Commit Message 规范
references/          check-project.sh 等参考脚本
scripts/             Agent 发现 smoke test
tests/               Shell 回归测试
policy.example.conf  policy 模板
```

## 边界与限制

- 不做代码 review、业务验证或质量 gate、release 管理、版本号更新，也不生成 changelog；
- 不判断“功能是否完成”，只帮助把已经确认范围的改动以安全、可解释的 Git 方式交付；
- 不自动修改目标项目的 `.gitignore`，不替你编排备份 hook，也不绕过 Git 的远端权限、分支保护或冲突处理；
- 用户级同步只负责让 Agent 产品发现 Skill；hooks、policy 和项目状态仍以目标工程的工程级安装为准；
- 不依赖外部 Harness 或 change 生命周期。

## 开发与贡献

本地测试见 [tests/run_tests.sh](tests/run_tests.sh)：

```sh
sh tests/run_tests.sh
```

CI 在 `ubuntu-latest` 与 `macos-latest` 上运行 shell 语法检查、测试与安装 smoke test。欢迎围绕可复现问题提交聚焦的 Issues 与 PRs。

请勿在公开 Issue 中粘贴凭据、私有仓库内容或可被直接滥用的漏洞利用细节。

## License

MIT，见 [LICENSE](LICENSE)。
