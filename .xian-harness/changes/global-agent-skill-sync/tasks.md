<!-- xian-harness:generated-view.v1
view: tasks.md
authority: contract-revision
rendererId: change-contract-markdown.v1
contractRevision: rev-0002
renderHash: sha256:05bbebda15fc7aac9bcbaa3b5312b36cb790b40542b09365fa14deaa577aeead
editPolicy: submit-contract-patch
editCommand: xian-harness change contract-patch global-agent-skill-sync --file <candidate.json> --target <target-project> --json
-->
# Tasks: global-agent-skill-sync

## Implementation Tasks

- [ ] 1. Compile captured facts into the canonical contract and generated views.

## Verification Mapping

| Acceptance | Verification Command | Evidence |
|---|---|---|
| AC-001, AC-002, AC-003, AC-004, AC-005 | `sh scripts/test/run.sh sync-global` | verify/attempts |
| AC-001, AC-002, AC-003, AC-004, AC-005 | `sh scripts/test/run.sh install` | verify/attempts |
| AC-001, AC-002, AC-003, AC-004, AC-005 | `sh -n sync-global.sh` | verify/attempts |
| AC-001, AC-002, AC-003, AC-004, AC-005 | `sh -n install.sh` | verify/attempts |
| AC-001, AC-002, AC-003, AC-004, AC-005 | `rg -n "sync-global|用户级|user-level" README.md README_EN.md` | verify/attempts |
| AC-001, AC-002, AC-003, AC-004, AC-005 | `git diff --check` | verify/attempts |
