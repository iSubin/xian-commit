# /xian-archive

Load skill: `xian-archive`

Purpose: close and archive a verified, reviewed, gate-passed change with release acceptance and Workbench evidence.

Rules:

- Do not archive with open P0/P1 issues.
- Do not archive without `docs/xian-harness/releases/{change-id}/release-acceptance.md`.
- Do not archive without `docs/xian-harness/workbench/{change-id}/snapshot.json`.
- Run `xian-harness archive run <change-id> --target <target-project> --json` for deterministic archive.
- Sync specs when 规格协议 is used.
- Write closeout or archive summary.
