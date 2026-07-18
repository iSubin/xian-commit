# Claude Hooks

本目录保存 Claude Code hooks 模板。通用逻辑优先放在 `../../hooks/`，本目录只保留 Claude Code 输出信封和必要适配。

## 第一阶段 Hook

- `session-start`: 读取入口规则、经验摘要、当前 change 状态。
- `pre-tool-use`: 检查危险命令、跨会话冲突、越界修改。
- `stop`: 汇总状态、提示未完成证据、沉淀经验。
- `hook-metrics`: 当前仍复用 `.codex/hooks/hook-metrics.cjs`。base pack 安装时同时包含 `.claude` 和 `.codex` 两棵 hook 树；若后续支持单 runtime 安装，应先把 metrics 抽到 `../../hooks/` 公共库。

## 原则

Hook 不负责生成业务代码。Hook 负责让 Agent 不能绕开 Harness 协议。
