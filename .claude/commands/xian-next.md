# /xian-next

Load skill: `xian-next`

Purpose: inspect current Harness state, surface process debt, and recommend the next action.

Rules:

- Do not implement directly from this command.
- Run or interpret `xian-harness continue --target <target-project> --json` before recommending the route.
- Read active change state before deciding.
- If multiple active changes exist, surface the choices.
- Surface dangling changes, dirty worktree, docs-sync warnings, and pack drift as explicit choices.
- Route to the next concrete skill.
