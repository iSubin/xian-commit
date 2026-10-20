# xian-commit

面向用户默认使用中文，保留命令、路径与代码标识原文。

- 先检查代码与 Git 状态，只修改当前任务需要的内容，保留无关变更。
- 本工程不依赖 Harness，不要求 change、reviewer、Gate、archive 或生命周期状态。
- 修复须补回归测试；运行相关 `tests/test_*.sh`，交付前运行 `sh tests/run_tests.sh`。
- Git 交付遵循根目录 `SKILL.md`；不使用 `git add -A`，不绕过 Git hooks。
- 提交和推送按本轮用户授权分别执行，不因“实现完成”自动发布。
