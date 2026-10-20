<!-- xian-harness:generated-view.v1
view: design.md
authority: contract-revision
rendererId: change-contract-markdown.v1
contractRevision: rev-0002
renderHash: sha256:e62dd1e81e70059fb3e907d03a7e9a25e41d1673c8fd7729e2e8f9d612061cfd
editPolicy: submit-contract-patch
editCommand: xian-harness change contract-patch global-agent-skill-sync --file <candidate.json> --target <target-project> --json
-->
# Design: global-agent-skill-sync

## Approach

Compile the normalized capture input directly into the accepted contract revision, then render generated views from that revision.

## Options Considered

| option | decision | rationale |
| --- | --- | --- |
| Compile capture facts directly into rev-0001 | accepted | Keeps the canonical contract and compatibility views on one deterministic input path. |

## Acceptance Mapping

| acceptanceId | taskIds | verificationRuleIds |
| --- | --- | --- |
| AC-001 | TASK-001 | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |
| AC-002 | TASK-001 | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |
| AC-003 | TASK-001 | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |
| AC-004 | TASK-001 | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |
| AC-005 | TASK-001 | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |

## Risk And Rollback

No rollback plan recorded.

## Trade-offs

No trade-offs recorded.
