# Project Next Decision

- Status: empty
- Active change: none
- Selected change: none
- Recommended action: delivery-close
- Recommended role: orchestrator
- Governance route: none
- Reason: Workspace has dirty or untracked files; inspect ownership before opening a new demand.
- Reason code: dirty-workspace-close
- Confidence: medium
- Next action: Attribute dirty worktree changes and close local delivery before opening a new demand.
- Direction source: project-recommendation
- Current situation: Project has no non-terminal changes available to continue; 1 terminal history change(s) are folded.
- Recommended target: project-level next work
- Minimum next step: Attribute dirty worktree changes and close local delivery before opening a new demand.
- Next skill: xian-commit

## Process Debt

- [soft-debt] Workspace has 7 dirty and 1 untracked file(s)
- [background] Rendered document freshness drift is advisory; review doc-sync only when planning docs work.

## Recommended Skills

- $xian-commit (codex-skill)

## Recommended Commands

- git status --short (shell-command; executable=true; available=true)

## Closeout Readiness

- Status: blocked
- Next state: attribute-worktree-before-closeout
- Reason: Workspace has dirty or untracked files, so closeout must first attribute local delivery changes.
- Commit suggested: false
- Commit message: none
- Tag suggested: false
- Release suggested: false

## Evidence

- docs/xian-harness/project/project-status.json
- docs/xian-harness/project/doc-sync-report.json
- docs/xian-harness/project/project-status.json

## Next Commands

- git status --short

## Fallback Commands

- git status --short --branch
- git diff --stat

## Commands

- git status --short

## Project Documents

| Document | Role | Status | Title |
|---|---|---|---|
| docs/README.md | Project Documentation Index | present | 文档索引 |
| docs/项目说明.md | Project Brief | present | 项目说明 |
| docs/项目基线.md | Project Baseline | present | 项目基线 |
| docs/项目开发纪律.md | Project Discipline | present | 项目开发纪律 |
| docs/项目情况.md | Project Situation | present | 项目情况 |
| docs/项目状态.md | Project Status | present | 项目状态 |
| docs/需求文档.md | Requirement | present | 需求文档 |
| docs/待办清单.md | Todo List | present | 待办清单 |

## Workspace Continuity

| Fact | Value |
|---|---|
| Source control | git |
| Git present | yes |
| Branch | master |
| Upstream | origin/master |
| Ahead / behind | 2 /  |
| Git root | . |
| Pathspec | . |
| Modified or staged files | 7 |
| Untracked files | 1 |
| Risk level | dirty |
| Commit staging | path-scoped |
| Push policy | explicit-only |
| Rule source | AGENTS.md and active profile |

Git workspace has 7 modified/staged and 1 untracked file(s) under the selected target path.

## Project Situation

| Fact | Value |
|---|---|
| Baseline | present |
| Baseline risk count | 2 |
| TODO count | 0 |
| FIXME count | 0 |
| Scanned files | 3 |
| Risk level | attention |

Project baseline has 2 risk item(s), and code scan found 0 TODO/FIXME signal(s).

### Baseline Risks

| Severity | Risk | Evidence | Mitigation |
|---|---|---|---|
| P1 | Git hooks can be silently bypassed by path-resolution mistakes | baseline-calibration | Use Git-resolved shared hook paths, reject core.hooksPath, parse staged names as NUL-delimited data, and retain regression coverage. |
| P2 | External hook managers require manual integration | baseline-calibration | Fail fast on core.hooksPath and document ownership, backup, and manual chaining behavior. |

### Code Signals

| Type | Path | Line | Text |
|---|---|---|---|
| none | none |  | none |

## Change Decisions

| Change | Status | Phase | Action | Role | Blocked Reason |
|---|---|---|---|---|---|
| none | empty | none | create-change | orchestrator | |

## Archived Context

Folded 1 archived/closed change(s) from main decisions. Use `--include-archived` to list them in main decisions.
