#!/usr/bin/env node
// Claude Stop Hook adapter. Shared checklist text lives in ../../hooks/stop-core.cjs.

const fallbackChecklistMessage = `## xian Stop Checklist

结束前确认：

- 当前 change 的 tasks 是否更新。
- 验证 evidence 是否落盘。
- open issues 是否记录。
- 需要用户决策的事项是否明确写出。
- 不要用对话历史替代 .xian-harness/ 或 docs/xian-harness/ 的事实源。`;

let formatClaudeStopOutput = () => JSON.stringify({ additionalContext: fallbackChecklistMessage });
try {
  ({ formatClaudeStopOutput } = require('../../hooks/stop-core.cjs'));
} catch {
  // Shared hook helpers are optional. Stop must remain fail-open during partial uninstall.
}

process.stdout.write(formatClaudeStopOutput());
