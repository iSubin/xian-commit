# Acceptance Criteria: fix-install-update-safety

## Change Goal

修复重复更新覆盖最初 hook 备份、`verify` 受目标工程自定义提交类型干扰的问题，并让开源用户能从中英文 README 恢复完整的工程级安装与更新流程。

## Business Acceptance

- [x] **AC-001** 已存在的 `.pre-xian-commit.bak` 在重复安装或更新后内容不变，目标 hook 仍更新为当前 xian-commit 版本。
- [x] **AC-002** 当目标项目的 `message.types` 不包含 `docs` 时，`install.sh verify` 仍能完成安装资源 smoke 验证。
- [x] **AC-003** 中英文 README 均包含工程级首次安装、已有工程更新、保留与覆盖规则、`core.hooksPath` 处理和会话重开提示。

## Technical Acceptance

- [x] **AC-004** 受影响 installer 回归、脚本语法与 diff 检查通过；完整 shell 测试套件由最终提交后的 merge-ready 提供集成交付证据。

## 关联事实源

| 类型 | 文件 | 用途 |
|---|---|---|
| Change Contract | [change.md](./change.md) | 定义 intent、scope、任务顺序、风险和验证命令。 |
| Change State | [.change-state.json](./.change-state.json) | 记录当前 phase、activation status 与 next action。 |
| Build Facts | [build/build-result.json](./build/build-result.json) | 记录实现覆盖、changed files 与 AC 测试映射。 |
| Harness Policy | [../../../../.xian-harness/harness-protocol.yaml](../../../../.xian-harness/harness-protocol.yaml) | 定义当前 base profile 的生命周期与门禁边界。 |
| Verify Result | [verify/verify-result.json](./verify/verify-result.json) | 记录正式验证命令、结果与 evidence log。 |
| Gate Result | [gate/gate-result.json](./gate/gate-result.json) | 记录验收覆盖与门禁裁决。 |

## 验证规则引用

| 规则 ID | 来源 | 负责 Skill | 执行载体 | 覆盖验收项 |
|---|---|---|---|---|
| `install.update.regression` | Change Contract | `xian-verify` | `sh tests/test_install.sh "$PWD"` | AC-001, AC-002 |
| `readme.lifecycle.docs` | Change Contract | `xian-verify` | `rg -n "更新已有工程\|Update an existing project\|core\\.hooksPath\|\\.xian-commit/config" README.md README_EN.md` | AC-003 |
| `install.syntax` | Change Contract | `xian-verify` | `sh -n install.sh` | AC-004 |
| `change.diff-check` | Change Contract | `xian-verify` | `git diff --check` | AC-004 |

## 验收覆盖矩阵

| 验收项 | 事实源 | 验证规则 / 命令 | 验证证据 | 门禁 / 发布证据 |
|---|---|---|---|---|
| AC-001 | `install.sh`, `tests/test_install.sh` | `install.update.regression` / `sh tests/test_install.sh "$PWD"` | `verify/verify-result.json`, `verify/evidence/` | `gate/gate-result.json` |
| AC-002 | `install.sh`, `tests/test_install.sh` | `install.update.regression` / `sh tests/test_install.sh "$PWD"` | `verify/verify-result.json`, `verify/evidence/` | `gate/gate-result.json` |
| AC-003 | `README.md`, `README_EN.md` | `readme.lifecycle.docs` / README keyword check | `verify/verify-result.json`, `verify/evidence/` | `gate/gate-result.json` |
| AC-004 | final Git tree | `install.syntax`, `change.diff-check`; final integration authority runs at merge-ready | `verify/verify-result.json`, merge-ready receipt | `gate/gate-result.json`, merge-ready status |

## Verification Commands

- [x] **VC-001** `sh tests/test_install.sh "$PWD"`
- [x] **VC-002** `rg -n "更新已有工程|Update an existing project|core\.hooksPath|\.xian-commit/config" README.md README_EN.md`
- [x] **VC-003** `sh -n install.sh`
- [x] **VC-004** `git diff --check`

## 跨 Agent 推进

1. 先读 [.change-state.json](./.change-state.json)，确认 change 仍处于 active lifecycle。
2. 再读 [change.md](./change.md) 与本文件，确认 scope、AC 和命令锚点没有漂移。
3. Builder 完成后检查 [build/build-result.json](./build/build-result.json)，Verifier 按 VC-001 至 VC-004 生成正式 verify evidence。
4. Gatekeeper 消费 verify result 与覆盖矩阵；archive、commit 后由集成协调者执行项目级 merge-ready，并消费 valid status 后 push。
5. 预期产物为 `verify/verify-result.json`、每条命令的 evidence log、`gate/gate-result.json`、archive 结果和 merge-ready receipt；任一必需证据缺失时不得声称交付完成。

## Out Of Scope

- 其他 review 项、user 级安装、全局安装、Husky 或其他 hook 管理器的自动串联。
