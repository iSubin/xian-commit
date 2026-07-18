# /xian-gate

Load skill: `xian-gate`

Purpose: run Agentic Quality Gate and decide pass, needs-fix, fail, needs-human, or blocked.

Deterministic tool path:

```bash
xian-harness check <change-id> --json
xian-harness gate status <change-id> --json
xian-harness gate issues <change-id> --json
```

Rules:

- Builder Agent cannot self-approve.
- Evidence and issues must be read before decision.
- Write gate artifacts under `docs/xian-harness/quality-gates/{change-id}/`.
- A non-`pass` status returns to the repair or human-decision loop instead of archive.
