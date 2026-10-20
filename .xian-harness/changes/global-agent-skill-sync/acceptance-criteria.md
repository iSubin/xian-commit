<!-- xian-harness:generated-view.v1
view: acceptance-criteria.md
authority: contract-revision
rendererId: change-contract-markdown.v1
contractRevision: rev-0002
renderHash: sha256:b7e0cba09fe28f8c001b2af5483a383847b3ae1fdf37abe3fa13dd934f4639a7
editPolicy: submit-contract-patch
editCommand: xian-harness change contract-patch global-agent-skill-sync --file <candidate.json> --target <target-project> --json
-->
# Acceptance Criteria: global-agent-skill-sync

## Business Acceptance

- [ ] **AC-001** 用户级同步将 xian-commit 与所有 xian-* skills 以软链注册到 ~/.agents/skills 及 Qoder/Codex/Claude 全局目录；重复执行幂等，不覆盖非受管路径。
- [ ] **AC-002** status/verify/uninstall 只处理本工具管理的软链；冲突或外部实体保持不动并明确报告。
- [ ] **AC-003** 全局 xian-commit skill 在缺少 .xian-commit/.xian-harness 的仓库中降级为通用提交规范，不声称 hooks 生效；工程级安装行为不变。
- [ ] **AC-004** 中英文 README 说明用户级安装、目标目录、守卫、版本漂移边界和卸载方式。

## Technical Acceptance

- [ ] **AC-005** Generated contract views, tasks, and verification mappings remain consistent with the captured facts.

## Verification Commands

- [ ] **VC-001** `sh scripts/test/run.sh sync-global`
- [ ] **VC-002** `sh scripts/test/run.sh install`
- [ ] **VC-003** `sh -n sync-global.sh`
- [ ] **VC-004** `sh -n install.sh`
- [ ] **VC-005** `rg -n "sync-global|用户级|user-level" README.md README_EN.md`
- [ ] **VC-006** `git diff --check`

## 关联事实源

| 类型 | 文件 | 用途 |
|---|---|---|
| Contract Revision | [contract-revisions/rev-0002.json](./contract-revisions/rev-0002.json) | 记录 canonical contract content。 |
| Contract State | [contract-state.json](./contract-state.json) | 记录当前 draft / accepted / frozen revision projection。 |
| Contract Patch Log | [contract-patches.jsonl](./contract-patches.jsonl) | 记录 append-only contract patch facts。 |
| Generated View | [acceptance-criteria.md](./acceptance-criteria.md) | 由 .xian-harness/changes/global-agent-skill-sync/contract-revisions/rev-0002.json 确定性生成。 |
| Verify Result | [verify/attempts](./verify/attempts) | 记录命令证据与 Evidence DAG。 |
| Gate Result | [gate/attempts](./gate/attempts) | 记录质量门禁裁决。 |

## 验证规则引用

| 规则 ID | 来源 | 负责 Skill | 执行载体 | 覆盖验收项 |
|---|---|---|---|---|
| `VC-001` | contract revision | `xian-verify` | `sh scripts/test/run.sh sync-global` | AC-001, AC-002, AC-003, AC-004, AC-005 |
| `VC-002` | contract revision | `xian-verify` | `sh scripts/test/run.sh install` | AC-001, AC-002, AC-003, AC-004, AC-005 |
| `VC-003` | contract revision | `xian-verify` | `sh -n sync-global.sh` | AC-001, AC-002, AC-003, AC-004, AC-005 |
| `VC-004` | contract revision | `xian-verify` | `sh -n install.sh` | AC-001, AC-002, AC-003, AC-004, AC-005 |
| `VC-005` | contract revision | `xian-verify` | `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | AC-001, AC-002, AC-003, AC-004, AC-005 |
| `VC-006` | contract revision | `xian-verify` | `git diff --check` | AC-001, AC-002, AC-003, AC-004, AC-005 |

## 验收覆盖矩阵

| 验收项 | 事实源 | 验证规则 / 命令 | 验证证据 | 门禁 / 发布证据 |
|---|---|---|---|---|
| AC-001 | contract revision | `VC-001` / `sh scripts/test/run.sh sync-global` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-001` / `sh scripts/test/run.sh sync-global` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-001` / `sh scripts/test/run.sh sync-global` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-001` / `sh scripts/test/run.sh sync-global` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-001` / `sh scripts/test/run.sh sync-global` | verify/attempts | gate/attempts |
| AC-001 | contract revision | `VC-002` / `sh scripts/test/run.sh install` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-002` / `sh scripts/test/run.sh install` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-002` / `sh scripts/test/run.sh install` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-002` / `sh scripts/test/run.sh install` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-002` / `sh scripts/test/run.sh install` | verify/attempts | gate/attempts |
| AC-001 | contract revision | `VC-003` / `sh -n sync-global.sh` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-003` / `sh -n sync-global.sh` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-003` / `sh -n sync-global.sh` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-003` / `sh -n sync-global.sh` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-003` / `sh -n sync-global.sh` | verify/attempts | gate/attempts |
| AC-001 | contract revision | `VC-004` / `sh -n install.sh` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-004` / `sh -n install.sh` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-004` / `sh -n install.sh` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-004` / `sh -n install.sh` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-004` / `sh -n install.sh` | verify/attempts | gate/attempts |
| AC-001 | contract revision | `VC-005` / `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-005` / `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-005` / `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-005` / `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-005` / `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts | gate/attempts |
| AC-001 | contract revision | `VC-006` / `git diff --check` | verify/attempts | gate/attempts |
| AC-002 | contract revision | `VC-006` / `git diff --check` | verify/attempts | gate/attempts |
| AC-003 | contract revision | `VC-006` / `git diff --check` | verify/attempts | gate/attempts |
| AC-004 | contract revision | `VC-006` / `git diff --check` | verify/attempts | gate/attempts |
| AC-005 | contract revision | `VC-006` / `git diff --check` | verify/attempts | gate/attempts |

## 跨 Agent 推进

- 新 Agent 进入本 change 时，应先读取 contract revision `rev-0002`、本生成视图和 verify/gate 输出。
- 如需修改验收或验证规则，运行 `xian-harness change contract-patch global-agent-skill-sync --file <candidate.json> --target <target-project> --json`；接受 patch 后会自动重新生成 Markdown 视图。
