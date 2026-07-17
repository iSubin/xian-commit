# xian-commit

[English](README_EN.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**xian-commit 是一个可安装到 Codex、Claude Code 等 AI Coding Agent 项目中的 Git 交付治理 Skill。**

它让 Agent 继续使用标准 Git，同时在提交范围、Commit Message 和推送边界提供可配置的确定性校验；配套 Git Hooks 是这个 Skill 的确定性执行层。

它不是 Node/Python 包，也不是常驻服务；运行时依赖 Git、兼容 POSIX 的 shell 与标准 Unix 工具，以及用于中文与 emoji 提交信息检查的 Perl。

## 为什么需要 xian-commit

AI Coding Agent 能写代码，也会在交付最后一步犯具体而昂贵的错误：把 runtime 或敏感文件暂存、写出 `feat: feat ...` 这类重复类型标题，或未检查 upstream 是否分叉就直接推送。

`xian-commit` 把责任拆开：

- Agent Skill 负责归因改动、规划提交并写 Commit Message；
- policy 只保存规则，不保存运行状态或口头授权；
- Git hooks 执行确定性的本地边界校验；
- remote push 是最后一个外部副作用，按 policy 与 Git 事实处理。

它面向 AI Coding Agent 的 Git delivery，不是通用 Git 客户端，也不是业务质量门禁。

## 三分钟开始

先克隆本仓库，再在**另一个目标 Git 仓库**中安装：

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

默认安装会写入 Codex 与 Claude Code 的 Skill、提交信息 prompt、lifecycle 参考脚本、policy 和四个 hooks。已有 `.xian-commit/config` 会保留，不会被安装或更新覆盖。

hooks 会从下一次 `git commit` 或 `git push` 起生效。若 Codex 或 Claude Code 会话已经打开，请在目标项目中重新打开会话，让项目级 Skills 被重新扫描。

## 推荐的项目接入方式

安装器只管理 xian-commit 自己的 Skill、prompt、policy 和 hooks，**不会自动修改目标项目的 `AGENTS.md` 或 `CLAUDE.md`**。这两个文件属于目标项目，里面通常还有架构、测试和业务约束；由安装器直接改写并不安全。

推荐按以下顺序接入：

1. 在目标仓库运行安装和 `verify`。
2. 检查 `.xian-commit/config`，按团队习惯选择 `auto-safe`、`explicit-only` 或 `never`。
3. 重新打开 Codex / Claude Code 会话，让项目级 Skill 被重新扫描。
4. 用一次小改动实际执行 commit；确认 hook 提示、提交信息和 push 边界符合预期后，再推广到团队。

如果 Agent 能稳定发现项目级 Skills，不需要再改入口文件。如果希望把 Git 交付入口写得更明确，可以在目标项目已有的文件中增加一条简短路由。

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
| `commit-msg` | 校验类型、中文标题、正文、重复类型与 emoji | 拒绝 commit，按提示修正 message 后重新提交 |
| `post-commit` | 在 `auto-safe` 条件全部成立时执行普通 push | 条件不足时跳过；push 失败只报告，本地 commit 保持成功 |
| `pre-push` | 仅检查当前检出的普通分支及其 upstream 的 protected branch、`never` policy 与落后状态 | 拒绝或提示先 `git pull --rebase`；无 upstream 时仅提示首次 push 设置 upstream |

这些 hooks 同样作用于人手输入的 `git commit` / `git push`，不是只对 Agent 生效。

若目标仓库已有内容不同的同名 hook，安装器会备份为 `*.pre-xian-commit.bak`，再写入 xian-commit 的 hook。备份 hook **不会自动串联执行**；请按目标项目的实际需求手动组合两者逻辑后再使用。

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

| 命令 | 是否写入目标仓库 | 用途 |
| --- | --- | --- |
| `sh /path/to/xian-commit/install.sh` / `sh /path/to/xian-commit/install.sh all` | 是 | 安装全部 Agent 资产、policy 与 hooks |
| `sh /path/to/xian-commit/install.sh update` | 是 | 更新同一套受管理资源，保留现有 config |
| `sh /path/to/xian-commit/install.sh hooks` | 是 | 仅安装四个 Git hooks |
| `sh /path/to/xian-commit/install.sh skill` | 是 | 仅安装 Codex/Claude Code Skill、prompt、参考资料与 policy |
| `sh /path/to/xian-commit/install.sh verify` | 否 | 检查安装完整性并做 hook smoke test |
| `sh /path/to/xian-commit/install.sh status` | 否 | 显示已安装资源与源文件是否一致 |
| `sh /path/to/xian-commit/install.sh uninstall` | 是 | 移除受管理资源；保留 config 和不同内容的 hooks |

## Agent 与平台兼容性

| 对象 | 支持方式 |
| --- | --- |
| Codex | 安装项目级 `.codex/skills/xian-commit`，并安装 hooks |
| Claude Code | 安装项目级 `.claude/skills/xian-commit`，并安装 hooks |
| 其他 Coding Agents | 可独立使用 hooks，或手动集成仓库根目录的 [SKILL.md](SKILL.md)；不宣称原生支持 |
| Ubuntu | CI 已验证 |
| macOS | CI 已验证 |

当前 CI 仅在 Ubuntu 与 macOS 运行；未声明 Windows 支持。

## 边界与限制

`xian-commit` 不做代码 review、业务验证或质量 gate、release 管理、版本号更新，也不生成 changelog。它不替业务或 Harness 判断“功能是否完成”，只帮助把已经确认范围的改动以安全、可解释的 Git 方式交付。

它也不会自动修改目标项目的 `.gitignore`，不会替你判断备份 hook 应如何编排，更不会绕过 Git 的远端权限、分支保护或冲突处理。

## 开发与贡献

本地测试见 [tests/run_tests.sh](tests/run_tests.sh)：

```sh
sh tests/run_tests.sh
```

CI 在 `ubuntu-latest` 与 `macos-latest` 上运行 shell 语法检查、测试与安装 smoke test。欢迎围绕可复现问题提交聚焦的 Issues 与 PRs。

请勿在公开 Issue 中粘贴凭据、私有仓库内容或可被直接滥用的漏洞利用细节。

## License

MIT，见 [LICENSE](LICENSE)。
