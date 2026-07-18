# CLAUDE.md - xian Base Harness

本文件是安装到非垂直专用目标项目后的 Claude Code 入口规则模板。

## 语言

默认使用中文与用户沟通。工程锚点、命令、文件名、类名、接口名保持英文原文。

## 产品特性保全

- 技术兼容性修复不得直接牺牲既有产品特性；删除字段、状态、证据、提示或协议入口前，必须说明原用途，并提供等价替代实现与验证。

## 默认交付意图

- 用户要求实现、修复、执行或完成具体 change 时，采用默认 publish intent（发布意图）：当前主 Agent 应无人值守完成 `archive -> commit -> merge-ready -> status -> push`，无需用户二次确认提交或推送。
- `push.mode=explicit-only` 只禁止 post-commit hook 自动 push；它不要求人类再次授权。最终 Git tree clean 且 review / Gate 已通过后，由当前主 Agent 显式承担 integration coordinator（集成协调者）职责。
- 只读、评审、分析、设计、parked，以及用户明确给出的 `no-commit/no-push` 请求不进入默认发布路径；生产部署、密钥操作、远端分支分叉和无法归因的 dirty worktree 仍按各自安全边界暂停。
- 普通 commit 和每个 batch child 不运行 full suite；单个任务或批量任务只在最终发布 Git tree 上运行一次 merge-ready，然后消费 valid status 并 push。

## 时间与时区

默认时区为 `Asia/Shanghai`（UTC+08:00）。

- 面向用户、Markdown 文档、handoff、evidence 摘要和人工可读记录的时间，统一使用 `yyyy-MM-dd HH:mm:ss（Asia/Shanghai）`。
- JSON、YAML、trace、state、gate-result 等机器可读字段，统一使用 ISO 8601，并带时区偏移，例如 `2026-06-20T21:30:15+08:00`。
- 不要在同一处手工维护两套时间。机器状态文件只存 ISO；面向用户的文档和交接文本只写人工可读格式。
- 若同一产物必须同时包含两种格式，必须由同一次系统时间生成，避免漂移。
- 禁止只写“今天、昨天、刚才”等相对时间；如需使用相对时间，必须同时附绝对时间。
- 不确定当前时间时，先用 `TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'` 确认，不凭模型记忆判断。

## Skill-first 工作方式

Claude Code 在本项目中工作时，必须先评估并加载匹配的通用治理技能：

1. 读取当前任务意图。
2. 判断是否命中 `xian-*` skill。
3. 读取当前 change 状态和相关文档。
4. 再执行代码修改、工具调用或验证。

如果目标项目已存在 `docs/项目开发纪律.md`，Claude Code 必须把它作为项目级目录治理规则读取；如果用户使用 `/goal` 或要求长程执行，应同时读取 `docs/xian-harness/goal-runbook.md`，并让 `xian-harness continue --json` 驱动下一步。

匹配示例：

| 用户意图 | 应优先加载 |
|---|---|
| 新需求、开新 change | `xian-open` |
| 写需求或验收 | `xian-spec` |
| 技术方案 | `xian-design` |
| 实施计划 | `xian-plan` |
| 实现代码 | `xian-build` |
| 验证与证据 | `xian-verify` |
| 质量门禁 | `xian-gate` |
| 归档交付 | `xian-archive` |

## Harness 分层

```text
通用 Harness: 需求、设计、计划、验证、审查、归档
垂直 Harness: 技术栈规则、代码规范、业务模板、交付方式
确定性工具: 扫描、校验、生成、测试、写状态
```

## 质量原则

- Builder Agent 可以自测，但不能批准自己的代码通过。
- Verifier Agent 或质量门禁流程必须独立生成验证证据。
- 质量结论必须写入 `docs/xian-harness/quality-gates/` 或等价协议产物。

## 工作区隔离

- 串行 change 默认 `serial-trunk`（串行主线）：在当前主工作区的本地默认分支持续小粒度 commit，不自动创建 feature branch 或 worktree。
- 采用 `serial-trunk` 且已安装 xian-commit 时，项目必须使用 `push.mode=explicit-only`；中间 commit 只保存在本地，最终 Git tree 通过 merge-ready 后才显式 push。
- 只有真实并行、用户明确要求、无法归因的 dirty worktree 或长时间高风险实验，才使用 `parallel-isolated`（并行隔离）：创建 worktree 与本地临时 branch，默认不推远端。
- 工作区隔离是本地执行纪律，不新增 change phase，不新增 tracked worktree registry，也不新增强制治理文档。
- 创建、删除或 prune worktree 等 worktree 拓扑变化不得触发 verify evidence 失效、full verify 或项目投影刷新。
- 只有 Git tree matches verified tree（Git 文件树匹配已验证文件树）时，才允许复用 commit-bound evidence；真实代码树变化必须重新验证。

## 禁止事项

- 禁止绕过 Skill 直接实现。
- 禁止把 CLI 作为主流程入口。
- 禁止口头确认替代本地 evidence。
- 禁止在未处理 P0/P1 issue 时归档。
