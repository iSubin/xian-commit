# Change: fix-install-update-safety

## Intent

修复 xian-commit 已有工程重复更新时的两个可靠性问题：首次安装保留的原始 hook 备份会被后续更新覆盖，以及 `verify` 的硬编码 `docs` smoke message 会与项目自定义 `message.types` 冲突。同时在中英文 README 补齐首次安装、已有工程更新、覆盖/保留边界和异常处理，让开源用户能安全升级工程级安装。

## Scope

Changed paths:

  - install.sh
  - tests/test_install.sh
  - README.md
  - README_EN.md

Out of scope:

- 不修改 pre-commit / commit-msg 业务规则。
- 不处理 merge/revert、`ls-remote` refspec、测试默认分支等其他 review 项。
- 不新增 user 级或全局安装方式。
- 不自动串联 Husky 或其他 `core.hooksPath` 管理器。

## Plan

- [x] T-001（AC-001、AC-002）在 `tests/test_install.sh` 增加重复安装保留原始备份、自定义 `message.types` 下 `verify` 通过的回归测试，并确认旧实现失败。
- [x] T-002（依赖 T-001；AC-001、AC-002）以最小改动修复 `install.sh`，不改变现有安装命令与 policy schema；定向测试通过后才进入文档更新。
- [x] T-003（AC-003）同步 `README.md` 与 `README_EN.md` 的首次安装、已有工程更新和边界说明，并执行关键词检查。
- [x] T-004（依赖 T-001 至 T-003；AC-004）运行受影响 installer 回归、脚本语法、双语文档锚点和 `git diff --check`；完整套件由提交后的 merge-ready 作为集成交付证据单次执行。

Rollback point:

- T-002 可独立回退 `install.sh` 与对应测试；它不迁移用户数据，不修改 policy schema，也不改变卸载协议。
- T-003 是纯文档改动，可独立回退。
- 无待确认的人类决策；用户已经授权修复与 publish intent，若出现远端分叉或无法归因的 dirty worktree 才暂停。

Solution choice:

- 备份选择“首次备份稳定保留”，已存在 `.pre-xian-commit.bak` 时不覆盖。时间戳多版本备份会扩大生命周期、卸载和文档边界，不适合本次聚焦修复。
- `verify` 选择临时宽松 policy 仅验证 hook 可执行与可解析，项目自定义 policy 的业务校验仍由真实 commit 和独立 hook 测试负责。

## Acceptance

Gate 前 AC 只写 verify/check 可证明的事实；不要把 `close.json`、`archive-result.json` 或 close/archive 已完成写成已勾选 AC。终态证据由 close/archive action 后证明。

- [x] **AC-001** 已存在的 `.pre-xian-commit.bak` 在重复安装/更新后内容不变，目标 hook 仍更新为当前 xian-commit 版本。
  Verify: `sh tests/test_install.sh "$PWD"`
- [x] **AC-002** 当目标项目的 `message.types` 不包含 `docs` 时，`install.sh verify` 仍能完成安装资源 smoke 验证。
  Verify: `sh tests/test_install.sh "$PWD"`
- [x] **AC-003** 中英文 README 均包含工程级首次安装、已有工程更新、保留/覆盖规则、`core.hooksPath` 处理和会话重开提示。
  Verify: `rg -n "更新已有工程|Update an existing project|core\.hooksPath|\.xian-commit/config" README.md README_EN.md`
- [x] **AC-004** 受影响 installer 回归、脚本语法与 diff 检查通过；完整套件由最终 merge-ready 提供集成交付证据。
  Verify: `sh -n install.sh`

## Risk

Mode: governed
Risk: elevated

确认边界：修复只证明 xian-commit 管理的备份不被二次覆盖，以及 `verify` 不受目标项目提交类型集影响；不能证明外部 hook 管理器已自动串联，也不能替代真实 commit 对项目 policy 的校验。

不变量：

- 用户的首个原始 hook 备份一旦存在，后续更新不得覆盖。
- `verify` 只验证安装产物健康，不把目标项目的自定义提交类型误判为安装失败。
- 目标项目的 `.xian-commit/config` 在安装和更新中保持不覆盖。

## Result

Status: pending
