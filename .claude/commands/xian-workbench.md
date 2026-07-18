# /xian-workbench

Load skill: `xian-workbench`

Purpose: generate or inspect Workbench-ready protocol snapshots for a change.

Deterministic tool path:

```bash
xian-harness workbench snapshot <change-id> --json
xian-harness workbench status <change-id> --json
xian-harness workbench render <change-id> --json
```

Rules:

- Workbench reads protocol state; it does not replace `xian-gate`.
- Use `snapshot.json` as the UI or Agent SDK state contract.
- Use `index.html` only as a local static preview of the snapshot.
- Route repair, archive, human decision, or unblock actions by `nextAction`.
