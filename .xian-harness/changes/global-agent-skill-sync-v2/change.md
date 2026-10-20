<!-- xian-harness:generated-view.v1
view: change.md
authority: contract-revision
rendererId: change-contract-markdown.v1
contractRevision: rev-0004
renderHash: sha256:d5c4d147188e02acf634ef0992aa3b4c24ba36090dd1b4f62caec59fbe24db70
editPolicy: submit-contract-patch
editCommand: xian-harness change contract-patch global-agent-skill-sync-v2 --file <candidate.json> --target <target-project> --json
-->
# Change: global-agent-skill-sync-v2

## Intent

把 xian-commit 及基础 xian-* skills 以用户级软链同步到 Qoder、Codex、Claude Code 的全局 skill 目录，同时保留工程级 hooks/policy 执行边界，并让全局 xian-commit 在缺少项目标记时降级为通用提交规范。

## Source

用户在使用 Qoder 时发现其提交规范未由当前工程的 xian-commit skill 驱动；要求让基础型 skills 可被所有全局 Agent 产品发现。旧 change global-agent-skill-sync 因 Codex reviewer 无法访问 ChatGPT 后端而正式 abandon，产品工作已 stash，本 change 以 Claude reviewer 干净重启同一目标。

## Scope

Changed paths:

  - sync-global.sh
  - SKILL.md
  - scripts/test/run.sh
  - tests/test_sync_global.sh
  - README.md
  - README_EN.md

Out of scope:

- This open does not execute, verify, gate, close, commit, or push the change.
- Implementation details remain owned by the future active change lifecycle.

## Plan

- [ ] Inspect the captured intent, source, scope, acceptance, and verification commands.
- [ ] Implement only the captured scope, then run verify/check/close through the normal lifecycle.

## Acceptance

Gate 前 AC 只写 verify/check 可证明的事实；不要把 `close.json`、`archive-result.json` 或 close/archive 已完成写成已勾选 AC。终态证据由 close/archive action 后证明。

- [ ] AC-001 用户级同步将 xian-commit 与所有 xian-* skills 以软链注册到 ~/.agents/skills 及 Qoder/Codex/Claude 全局目录；重复执行幂等，不覆盖非受管路径。
  Verify: `sh scripts/test/run.sh sync-global`
- [ ] AC-002 status/verify/uninstall 只处理本工具管理的软链；冲突或外部实体保持不动并明确报告。
  Verify: `sh scripts/test/run.sh sync-global`
- [ ] AC-003 全局 xian-commit skill 在缺少 .xian-commit/.xian-harness 的仓库中降级为通用提交规范，不声称 hooks 生效；工程级安装行为不变。
  Verify: `sh scripts/test/run.sh sync-global`
- [ ] AC-004 中英文 README 说明用户级安装、目标目录、守卫、版本漂移边界和卸载方式。
  Verify: `sh scripts/test/run.sh sync-global`
- [ ] AC-005 Generated contract views, tasks, and verification mappings remain consistent with the captured facts. <!-- xian-harness:generated-acceptance -->
  Verify: `sh scripts/test/run.sh sync-global`

## Verification Commands

- [ ] **VC-001** `sh scripts/test/run.sh sync-global`
- [ ] **VC-002** `sh scripts/test/run.sh install`
- [ ] **VC-003** `sh -n sync-global.sh`
- [ ] **VC-004** `sh -n install.sh`
- [ ] **VC-005** `rg -n "sync-global|用户级|user-level" README.md README_EN.md`
- [ ] **VC-006** `git diff --check`

## Risk

Mode: audit
Tier: major
Risk: audit/major

## Result

Status: active
