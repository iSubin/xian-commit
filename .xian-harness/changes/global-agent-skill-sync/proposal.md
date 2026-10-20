<!-- xian-harness:generated-view.v1
view: proposal.md
authority: contract-revision
rendererId: change-contract-markdown.v1
contractRevision: rev-0002
renderHash: sha256:340d10cefd1ec5672851f914ba00dd8d4478f0fca1d2e9bbe1fc0ccf69db7828
editPolicy: submit-contract-patch
editCommand: xian-harness change contract-patch global-agent-skill-sync --file <candidate.json> --target <target-project> --json
-->
# Proposal: global-agent-skill-sync

## Why

用户在使用 Qoder 时发现其提交规范未由当前工程的 xian-commit skill 驱动；要求让基础型 skills 可被所有全局 Agent 产品发现。

## What Changes

把 xian-commit 及基础 xian-* skills 以用户级软链同步到 Qoder、Codex、Claude Code 的全局 skill 目录，同时保留工程级 hooks/policy 执行边界，并让全局 xian-commit 在缺少项目标记时降级为通用提交规范。

## Options

| option | decision | rationale |
| --- | --- | --- |
| Compile capture facts directly into rev-0001 | accepted | Keeps the canonical contract and compatibility views on one deterministic input path. |

## Project Source Delta

```json
{
  "capabilityDelta": [],
  "boundaryDelta": [],
  "riskDelta": []
}
```

## Non-goals

- No non-goals recorded.

## Impact

No impact summary recorded.
