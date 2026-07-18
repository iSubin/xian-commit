---
name: xian-batch
description: Use when the user asks to batch-process parked changes, list parked changes in execution order, or generate a /goal instruction for serially completing multiple Harness changes.
---

# xian-batch

## 用途

`xian-batch` 是 goal-driven（目标驱动）的 L1 serial goal runtime（L1 串行目标运行时）人类前端，也是 parked change pool（已停放变更池）的排序器和 `/goal` 指令生成器。

它只做三件事：

1. 读取当前项目 parked change pool。
2. 按依赖、风险、执行成本和用户目标排序。
3. 输出 copy-ready（可直接复制使用）的 `/goal` 指令，让 `/goal` 依次驱动这些 change。

`xian-batch` 不执行 change，不新增 batch runtime（批处理运行时），不创建第二套状态源，也不替代每个 change 自己的 lifecycle（生命周期）。
执行态由 `docs/xian-harness/goals/{goal-id}/goal.json` 和 `xian-harness goal open/status/next/close` 承载；方向建议态由 `xian-harness continue`、`xian-open` 和 `xian-next` 仲裁。parked change 在被用户选择前保持 candidate-only（仅候选），任何执行都必须一次只推进一个 active change（当前活动变更）。
`goal.json.children[]` 是 child order authority（子任务顺序权威）：`goal next`、`goal status` 和 `goal close` 必须消费同一顺序事实。若 lifecycle evidence（生命周期证据）显示 later child 先于 earlier child 完成，runtime 必须报告 `child-order-split-brain`，并阻止 goal close，除非 goal 中存在显式 `orderDeviationOverrides`（顺序偏差接受事实）。

governed/lite 默认仍以 `docs/xian-harness/changes/{change-id}/change.md` 为 change 事实源，并保持 `open -> verify -> gate -> close` 的轻量默认路径；audit 只在用户要求、风险升级或证据不足时显式升级。

## 触发条件

当用户出现以下意图时使用：

- “列出 parked change 并按执行顺序排序”。
- “给我一个 goal 可执行指令”。
- “一次性做这批 parked change”。
- “批量构建 / 批量推进 parked 池子里的任务”。
- “把这些 change 做成 `/goal` 能驱动的指令”。

普通单个 change 开发、单个 bugfix、单次继续执行，优先交给对应 lifecycle skill，不进入 `xian-batch`。

## 协议输入

必须优先读取：

- `xian-harness change list --parked --target <target-project> --json`
- `docs/xian-harness/changes/<change-id>/.change-state.json`
- `docs/xian-harness/changes/<change-id>/change.md`

可选读取：

- `docs/xian-harness/changes/<change-id>/acceptance-criteria.md`
- `docs/xian-harness/changes/<change-id>/proposal.md`
- `docs/xian-harness/project/project-status.json`
- `xian-harness continue --target <target-project> --json`

`docs/待办清单.md` 是 generated surface（生成视图），不能当作 parked change 的唯一事实源。

## 执行流程

1. 读取 parked change pool 和当前 active change。
2. 如果已有 active change，只输出先收口当前 change 的建议，不重新拆分 goal。
3. 如果没有 active change，把 parked changes 按依赖、风险、执行成本和用户目标排序。
4. 输出 candidate-only 列表和 copy-ready `/goal` 指令；`/goal` 指令必须是高密度执行说明，不是简单 change id 清单。
5. 明确 `/goal` 或后续 lifecycle 执行时一次只推进一个 change，每个 change 独立完成 activate -> implement -> verify -> check/gate -> close/finalize -> commit。
6. 当输出 copy-ready `/goal` 指令时，只输出 `/goal` 指令块，不追加 next-skill handoff。

在 goal 执行开始前，对全部列出的 parked children 做一次 read-only contract preflight（只读契约预检）：检查 placeholder、AC-to-command mapping、Project Source Delta 和当前阶段应具备的 phase facts。预检不得激活第二个 change，也不得预写 future phase facts；失败的 child 在激活前先暂停并归类。

## 默认交付意图

- 批量实现请求默认携带 publish intent；每个 child 独立完成本地 commit，但不得在 child 循环中运行 full suite 或 push。
- 所有 child、review Quality Issues 和最终 commit 收口后，由当前主 Agent 作为 integration coordinator，只在最终发布 Git tree 上运行一次 merge-ready，随后自动完成 status 与 push，无需用户二次确认。

## 确定性工具

- `xian-harness change list --parked --target <target-project> --json`
- `xian-harness continue --target <target-project> --json`
- `xian-harness goal open --target <target-project> --json`
- `xian-harness goal status --target <target-project> --json`
- `xian-harness goal next --target <target-project> --json`
- `xian-harness goal close --target <target-project> --json`

## 必需证据

- parked change 列表和每个 change 的 `.change-state.json`。
- 每个 change 的 `change.md`，用于确认验收、范围和当前状态。
- 当前项目 `activeChange` 状态，防止创建第二个 active change。
- 如存在 goal runtime，读取 `docs/xian-harness/goals/{goal-id}/goal.json` 作为执行态事实源。
- 如 goal 中存在 `orderDeviationOverrides`，必须在输出中说明 actor、reason、acceptedRisk、affectedChildren、evidenceOrder 和 timestamp，不能把顺序偏差静默当成正常完成。

## Batch-Level Shared Checks

批量执行可以规划 shared checks（共享检查），但 shared checks 只是一次性最终确认或 fresh snapshot（新鲜快照）引用，不是 batch-wide gate（批次级门禁）。

允许作为 shared checks 的典型对象：

- `git diff --check`
- `npm --prefix xian-agent-harness test -- --run test/product-surface.test.ts`
- `xian-harness pack status --profile base --target <target-project> --json`
- `xian-harness docs status --target <target-project> --json` 或等价文档状态检查

约束：

- 每个 child change（子变更）仍必须保留自己的 verify/gate/finalize 事实。
- Build 期间只运行 child-local targeted development tests；源码、contract、phase facts 和 required build review 稳定后，每个 child 默认只运行一次 formal Verify。
- 第二次 Gate 仍失败时暂停 batch 并分类根因，不机械刷新 evidence 或重复 formal Verify。
- 跨 child 的昂贵 external/shared check 放在依赖链末端执行一次；它不能替代任何 child-local failure signal。
- shared checks 只能补充或复用 fresh facts，不能替代 change-local failure signal（变更本地失败信号）。
- 任一 child change 的 verify、gate、archive 或 commit 失败时，batch 立即暂停并报告，不得用 shared checks 继续推进。
- shared checks 的引用必须包含命令、生成时间、目标项目和证据路径；stale（过期）或跨项目 facts 不得复用。
- goal close 本身不调用 merge-ready；goal completion 不证明 full suite 已运行。
- `xian-batch` 只有承担 integration coordinator 职责时，才在所有 child、review Quality Issues（审查质量问题）和最终 commit 收口后显式进入 merge-ready boundary。普通 child、goal next、goal close 和 shared checks 都不得触发 full。

## 排序规则

排序必须说明理由。默认按以下顺序裁决：

1. 修复当前流程断点或阻塞真实开发的 change。
2. 会降低后续 change 摩擦的基础能力。
3. 会影响状态源、证据、verify/gate/close、pack、skill contract 的协议类 change。
4. 用户已明确要求优先验证的真实项目体验问题。
5. 相互独立的小 UX/文档收口 change。
6. 纯后续增强或可延后的 P2/P3。

如果存在依赖关系，依赖优先于单纯 priority（优先级）。

## 输出契约

输出必须包含：

- 当前 parked change 总数。
- 排序后的 change 列表。
- 每个 change 的排序理由。
- copy-ready `/goal` 指令。
- `/goal` 指令中的每个 child 必须包含：目标、排序理由、acceptance 摘要、验证命令、风险。

输出不得包含：

- 自动执行承诺。
- `xian-harness batch` 命令。
- `goal run` 或 `goal resume` 命令。
- `batch-state.json` 或新状态文件。
- batch-wide gate（批次级门禁）。
- 会让用户误以为 candidate-only（仅候选）排序已经授权执行的提示。

## /goal 指令高密度模板

生成的 copy-ready `/goal` 指令必须使用以下结构。标题可中文化，但这些结构单元不能缺失。

### Fact Snapshot

- 工作目录。
- 当前 active change（当前活动变更）状态。
- 当前 parked change 总数。
- 只执行列出的 parked changes。
- 不创建第二个 active change，不新增未列出的 change。

### Ordered Child Plan

- 按执行顺序列出 child changes（子变更）。
- 每个 child 必须包含：目标、排序理由、acceptance 摘要、验证命令、风险。
- 说明依赖关系；依赖优先于单纯 priority（优先级）。
- 执行序列必须与 `goal.json.children[]` 保持一致；不得推荐、激活或推进 later child，除非 earlier child 已 closed/rejected，或存在显式 order-deviation override。

### Per-child Execution Card

每个 child change 使用同一张执行卡，便于 goal 执行时逐项恢复上下文：

```text
<序号>. <change-id>
目标：<本 child 要解决的真实问题>
排序理由：<为什么它在当前位置>
Acceptance 摘要：<AC 编号或可验证事实摘要>
验证命令：<change-local verify/check 命令；未知时写“从 change.md / acceptance-criteria.md 读取后确定”>
风险与暂停点：<scope 扩张、外部凭证、dirty worktree、人工决策、未知状态>
```

### Execution Loop

- 每次只激活一个 change。
- 每个 change 独立走 activate -> implement -> verify -> check/gate -> close/finalize -> commit。
- 每个 change 完成后提交一次，并在继续下一项前确认 activeChange 为空。
- 不使用 `git add -A`。
- 不使用 destructive git 命令。
- 不覆盖用户未提交内容。
- 遇到 dirty worktree（当前工作区有未提交变化）、验证失败、scope 扩张、外部凭证、人工决策或未知状态时暂停。

### Shared Final Checks

- shared checks 只作为最终确认或 fresh snapshot（新鲜快照）引用，不能替代每个 child 的 verify/gate/finalize。
- goal close 前必须确认每个 child 有 non-empty acceptance（非空验收）或 accepted-empty rationale（接受空验收理由）。
- goal close 前必须确认没有 blocking `child-order-split-brain` / `goal-integration-split-brain` 诊断。
- goal close 只确认 child lifecycle 与顺序事实；integration coordinator 的 merge-ready 是后续独立边界，不进入每个 child 的执行循环。

### Pause Conditions

- 当前存在 active change。
- 工作区有未归因 dirty worktree。
- 任何 child 的 verify、gate、archive、close 或 commit 失败。
- 用户目标、change scope 或 parked pool 发生变化。
- 需要外部凭证、人工产品决策或接受风险。
- goal runtime 事实与 change lifecycle evidence 出现顺序或完成状态冲突。

### Final Report

- 列出每个 child 的最终状态和 commit hash。
- 汇总验证命令、结果和证据路径。
- 汇总 shared final checks。
- 明确剩余 parked change、遗留风险和未完成 follow-up。
- 明确是否达到 goal completion 标准。

## 参考样例

```text
当前 parked change：<N> 个

执行顺序：
1. <change-id>
   原因：...
2. <change-id>
   原因：...

可复制给 /goal 的指令：

/goal
目标：按顺序完成当前项目 parked change 池中的 <N> 个 change。

Fact Snapshot:
- 工作目录：<target-project>
- activeChange：null
- parked change 总数：<N>
- 只执行以下列出的 parked changes；不新增 change。

Ordered Child Plan:
1. <change-id>
   目标：...
   排序理由：...
   Acceptance 摘要：...
   验证命令：...
   风险与暂停点：...
2. <change-id>
   目标：...
   排序理由：...
   Acceptance 摘要：...
   验证命令：...
   风险与暂停点：...

Execution Loop:
- 不创建第二个 active change。
- 只处理上述 change，不新增未列出的 change。
- 每次只激活一个 change。
- 每个 change 独立完成 activate -> implement -> verify -> check/gate -> close/finalize -> commit。
- 不使用 git add -A，不使用 destructive git 命令。
- 发现 dirty worktree、验证失败、scope 扩张、外部凭证、人工决策或未知状态时暂停并报告。

Shared Final Checks:
- 每个 child 的 verify/gate/closeout 事实独立存在。
- docs status、pack status 和必要回归只作为最终确认，不替代 child-local evidence。

Pause Conditions:
- activeChange 不为空。
- child order 与 goal.json.children[] 不一致。
- 出现 blocking child-order-split-brain / goal-integration-split-brain。

Final Report:
- 上述 change 均不再 parked。
- activeChange=null。
- 必要测试、typecheck、docs status、pack status 通过。
- 每个 change 都有独立 commit。
- 最终汇报 commit hash、验证摘要、剩余风险。
```

## 非目标

- 不新增 `xian-harness batch` CLI。
- 不新增 `goal run`。
- 不新增 `goal resume`。
- 不新增 `batch-state.json`。
- 不新增 batch-wide gate。
- 不自动执行 parked changes。
- 不并行写 `.xian-harness/state.yaml` 或 projection log。
- 不替代 `xian-open`、`xian-next`、`xian-verify`、`xian-gate`、`xian-close`、`xian-archive`。

## 交互预算

- 必须：只读取 parked change 池、active change、change.md 和必要 project status，不展开 unrelated evidence。
- 必须：只生成排序和 `/goal` 指令，不在本 skill 内执行 change。
- 必须：发现 dirty worktree（当前工作区有未提交变化）、scope 扩张或外部凭证需求时暂停并报告。
- 表达层中文优先；保留 `goal runtime`、`active change`、`candidate-only` 等英文术语时紧跟中文释义。

## 交接规则

`xian-batch` 有两种输出态，必须先判断用户要哪一种：

- copy-ready `/goal` 输出态：只输出 `/goal` 指令块，不追加 next-skill handoff，也不把 candidate-only（仅候选）列表说成已经授权执行。
- candidate-only（仅候选）排序态：只给排序、理由和下一步建议；如果 runtime `nextAction` 和静态排序冲突，先运行 `$xian-next` 或 `xian-harness continue --json` for arbitration。

当只是 candidate-only 排序且没有输出 `/goal` 指令时，末尾可以用以下轻量格式：

```text
下一步建议：<中文下一步>

`$xian-next`
```

## 约束与原因

- 不直接执行 change。原因：`xian-batch` 只做人类前端排序，执行态必须由单个 change lifecycle 或 goal runtime 写入事实源。
- 不新增 `xian-harness batch`。原因：batch-wide CLI 会形成第二套状态机，和 active change / goal runtime 分叉。
- 不新增 `batch-state.json`。原因：批次状态应复用 `docs/xian-harness/goals/{goal-id}/goal.json`，避免第三个状态源。
- 不新增 batch-wide gate。原因：每个 change 的验收、verify、gate 和 closeout 必须独立可审计。
- 不并行推进多个 active changes。原因：`.xian-harness/state.yaml` 和 projection log 只能可靠表达一个当前执行焦点。
- 不把 candidate-only 列表说成已经授权执行。原因：用户选择和 active change 激活才是执行授权边界。

## 自检清单

- 是否读取了 parked change pool 的当前事实？
- 是否按执行前后给出排序，并说明理由？
- 是否输出了 copy-ready `/goal` 指令？
- 是否明确 `/goal` 执行时一次只激活一个 change？
- 是否明确失败、dirty、scope 扩张和人工决策时暂停？
- 是否没有新增或暗示 `xian-harness batch`、`goal run`、`goal resume`、`batch-state.json` 或 batch-wide gate？
- 是否没有承诺自动执行 parked changes？
