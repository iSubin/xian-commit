# Goal 任务运行手册

Template Contract: xian-harness/docs/goal-runbook

## Template Quality Contract

| 项 | 内容 |
|---|---|
| Fact Sources | `docs/项目开发纪律.md`、`docs/项目基线.md`、`.xian-harness/state.yaml`、`xian-harness continue` 输出、change-local evidence。 |
| Owner Role | Orchestrator / Workbench Operator / Doc Steward。 |
| Verification Commands | `xian-harness continue --target <target-project> --json`、`xian-harness guard <change-id> --target <target-project> --for archive --json`。 |
| Evidence Paths | `docs/xian-harness/goal-runbook.md`、`docs/xian-harness/workbench/project/next-decision.json`。 |

本文是 Harness / Agent 运行资产，不是业务项目文档。它默认放在 `docs/xian-harness/` 下，避免污染目标项目的业务需求、设计、交付和验收文档目录。

本文定义 Codex /goal 如何配合 `xian-harness continue` 从头到尾推进一个需求。`/goal` 负责长程执行目标；`xian-harness continue` 负责每一步的事实驱动下一步决策。

## 标准 /goal 提示词

```text
/goal
目标：基于 xian-agent-harness 完成 <change-id> 从需求接入到 archive 的完整闭环。

执行纪律：
1. 先读取 AGENTS.md、CLAUDE.md、docs/项目开发纪律.md、docs/项目基线.md。
2. 如果目标项目尚未初始化，先执行 pack install 和 baseline create。
3. 创建或确认 active change 后，每一轮都先运行 xian-harness continue --target <target-project> --json。
4. 按 continue 输出的 recommendedAction、recommendedRole、recommendedSkills 和 commands 推进。
5. 不凭聊天上下文跳步；所有状态变更必须落到 .change-state.json 和 .change-transition.log。
6. 所有验证必须落到 verify、gate、workbench、release 或 archive 证据目录。
7. 遇到 blocked、human-decision、外部凭证、GUI、sudo 或生产资源风险时暂停并说明。
8. gate 通过后再进入 release / archive；archive 后运行 experience review。
```

## 从头到尾流程

| 阶段 | 目标 | 主要命令 / 事实源 | 退出条件 |
|---|---|---|---|
| 初始化 | 安装 Harness Pack 并建立项目入口事实。 | `xian-harness pack install`、`xian-harness baseline create` | `AGENTS.md`、`CLAUDE.md`、`docs/项目基线.md`、`docs/项目开发纪律.md` 存在。 |
| 打开 | 创建 change 并写清楚业务目标。 | `xian-harness change open`、proposal、acceptance | `acceptance-criteria.md` 能说明完成口径。 |
| 计划 | 把需求拆成可验证任务。 | tasks、design、`xian-harness continue` | 任务、证据、风险和 owner 清楚。 |
| 实现 | 按任务改代码或文档。 | Git diff、tasks、local evidence | 实现完成且没有跳过验收项。 |
| 验证 | 运行测试、构建、smoke 或文档检查。 | `xian-harness verify`、verify evidence | 验证结论可复现。 |
| 门禁 | 独立判断是否可交付。 | `xian-harness check`、quality gate | P0/P1 closed，风险有处置。 |
| 看板 | 生成跨 Agent handoff 状态。 | `xian-harness workbench snapshot/render` | 新 Agent 能从 snapshot 接手。 |
| 归档 | 固化交付理由和经验候选。 | `xian-harness archive`、`xian-harness experience review` | summary、archive、experience disposition 完成。 |

## xian-next 与 continue

- `/xian-next` 是 coding agent 侧命令资产，用于提醒 Agent 读取当前 Harness 状态并路由到下一个 skill。
- `xian-harness continue` 是确定性 CLI，读取本地事实源并输出项目级或 change 级 next decision。
- Codex /goal 中不要把 `/xian-next` 当成状态源；应把 `xian-harness continue --json` 作为下一步判断依据。

## 暂停条件

- `continue` 输出 `blocked` 或 `human-decision`。
- 需要生产凭证、外部账号、GUI 操作、sudo 安装或不可回滚操作。
- 验证命令失败且原因不是当前 Agent 可修复的代码问题。
- 目标项目事实与 `docs/项目基线.md` 明显冲突。

## 最小验收

一次 `/goal` 长程任务完成后，至少应留下：

- `docs/xian-harness/changes/{change-id}/acceptance-criteria.md`
- `docs/xian-harness/changes/{change-id}/verify/verify-result.json`
- `docs/xian-harness/changes/{change-id}/gate/gate-result.json`
- `docs/xian-harness/changes/{change-id}/workbench/snapshot.json`
- `docs/xian-harness/changes/{change-id}/archive/summary.md`
- `docs/xian-harness/workbench/project/next-decision.json`
