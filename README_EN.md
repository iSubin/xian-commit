# xian-commit

[简体中文](README.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**xian-commit is an installable Git delivery governance Skill for AI Coding Agents such as Codex, Claude Code, and Qoder.**

It keeps Agents on standard Git while adding configurable, deterministic checks for staged scope, commit messages, and push boundaries. The bundled Git hooks are the Skill's deterministic enforcement layer.

It is not a Node/Python package or a resident service. Runtime prerequisites are Git, a POSIX-compatible shell with standard Unix tools, and Perl for Chinese- and emoji-related commit-message checks.

> **Installation scope: project-level enforcement plus optional user-level discovery.**
> `install.sh` writes the Skill, policy, and hooks into the current target Git repository only. It does not write directly into `~/.codex/skills`, `~/.claude/skills`, or `~/.qoder-cn/skills`. Every project that needs hooks/policy must still be installed separately.
> `sync-global.sh` is optional: it registers only this product's `xian-commit` Skill, not other Skills installed in the source project. It does not install hooks or policy, and does not replace project-level installation. This project does not require Harness.

## Why xian-commit

AI Coding Agents can write code, but still make concrete and expensive mistakes at the last delivery step: staging runtime or sensitive files, writing duplicate-type titles such as `feat: feat ...`, or pushing without first checking whether the upstream has diverged.

`xian-commit` separates these responsibilities:

- The Agent Skill attributes changes, plans commits, and writes commit messages.
- Policy stores rules only—not runtime state or verbal authorization.
- Git hooks enforce deterministic local boundary checks.
- A remote push is the final external side effect, handled from policy and Git facts.

It is for Git delivery by AI Coding Agents—not a general Git client or a business-quality gate.

## Installation and updates

### First installation

Clone this repository first, then install it in **another target Git repository**:

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

The default installation writes the Codex and Claude Code Skills, a commit-message prompt, lifecycle reference scripts, policy, and four hooks. An existing `.xian-commit/config` is preserved; installation and updates never overwrite it.

Hooks activate from the next `git commit` or `git push`. If a Codex or Claude Code session is already open, reopen the session in the target project so project-level Skills are rescanned.

### Update an existing project

Each target project stores its own project-level Skill, policy, and hooks. After the xian-commit source repository changes, update every integrated project separately. Update the local xian-commit source checkout first, then run the installer from the target project:

```sh
git -C /path/to/xian-commit pull --ff-only

cd /path/to/your-project
sh /path/to/xian-commit/install.sh status
sh /path/to/xian-commit/install.sh update
sh /path/to/xian-commit/install.sh verify
```

`status` is read-only and shows which managed resources are missing or differ from the current source version. `update` refreshes the Codex and Claude Code Skills, prompt, references, `policy.example.conf`, and all four hooks. `verify` then checks installation completeness and hook executability. Reopen the Codex or Claude Code session in the target project after updating so the new project-level Skill is loaded.

Overwrite and preservation rules during updates:

- `.xian-commit/config` is the target project's policy. Once created, later installations and updates do not overwrite it.
- Managed Skills, prompts, references, `policy.example.conf`, and hooks are updated to the current xian-commit source version.
- When a different same-named hook is first encountered, the installer saves it as `*.pre-xian-commit.bak`. Repeated installations and updates preserve that original backup. The active hook is still updated to the current xian-commit version, and the backup is not chained automatically.
- Linked worktrees use the shared hooks directory resolved by Git; worktrees of the same main repository do not maintain separate private hook installations.
- If `git config --show-origin --get core.hooksPath` prints a value, installation, updates, and `verify` fail explicitly. Do not blindly remove an existing Husky or similar configuration just to install xian-commit. First choose which tool owns the hooks, then chain the required behaviors manually.

If `git pull --ff-only` fails because of local changes or divergence, resolve the Git state of the xian-commit source checkout first. Do not force-overwrite the installation source.

### User-level installation across Agents (optional)

To expose the same `xian-commit` Skill across products, run:

```sh
sh /path/to/xian-commit/sync-global.sh install
sh /path/to/xian-commit/sync-global.sh verify
```

The shared hub is `~/.agents/skills/xian-commit`; the whole directory links to this checkout, preserving a real `SKILL.md` rather than a file symlink that some scanners ignore. All five product entries below are created by default, even if those products are not installed. Use `--agents codex,claude,qoder-cn` to select a subset, and repeat the selection for subsequent `install/status/verify` commands.

| Product / selector | User-level entry |
| --- | --- |
| Codex / `codex` | `~/.codex/skills/xian-commit` |
| Claude Code / `claude` | `~/.claude/skills/xian-commit` |
| Qoder CN / `qoder-cn` | `~/.qoder-cn/skills/xian-commit` |
| Qoder / Qoder CLI / `qoder` | `~/.qoder/skills/xian-commit` |
| QoderWork / `qoderwork` | `~/.qoderwork/skills/xian-commit` |

Qoder products do not share a single directory: see the [Qoder CLI documentation](https://docs.qoder.com/cli/Skills) and [QoderWork documentation](https://docs.qoder.com/qoderwork/skills). Directory adapters are not a claim of runtime certification for every version.

Common commands:

| Command | Writes | Purpose |
| --- | --- | --- |
| `sh sync-global.sh install` | User-level links and ownership manifest | Registers or refreshes `xian-commit` |
| `sh sync-global.sh status` | No | Shows whether each product entry is current, missing, or conflicting |
| `sh sync-global.sh verify` | No | Checks links, sources and manifest, not actual Agent loading |
| `sh sync-global.sh uninstall` | User-level symlinks | Removes only links managed by this tool and preserves external files |
| `sh sync-global.sh install --dry-run` | No | Previews the sync without writing |

Updates, relocation and removal:

- Updating the source checkout changes linked content immediately. Rerun `install`, then `verify`, and restart Agent sessions. Pin the source version or use project-level copies for a fixed version.
- Ownership is persisted in `~/.agents/xian-commit-sync.tsv`. After moving the source, run `install` from its new location to repair owned links. Missing source files fail verification; `uninstall` still works from any intact copy using the recorded inventory.
- Reducing `--agents` reconciles retired owned entries. Conflicting real directories or foreign links stop installation before writes. Existing same-target manual links are `borrowed`, not silently adopted, and survive uninstall. A shared hub needed by borrowed product links is preserved until those links are manually removed and uninstall is retried.
- Older versions have no reliable ownership inventory. After checking the existing `xian-commit` links, run `install --adopt-legacy` once before moving or uninstalling. Only `xian-commit` is adopted; other `xian-*` entries exported by older versions require separate inspection.
- Use `--home /path/to/home` for an isolated installation; `--dry-run` does not write to the target.

Project guard and real discovery:

- Without `.xian-commit/config`, use generic commit discipline. A config file alone does not prove hooks are active, and another tool's directory is not an installation marker.
- From the target repository, run `sh ~/.agents/skills/xian-commit/references/check-project.sh` to check Git's effective hook path, executable bits and content of all four hooks. `hooks=unverified` is not evidence of active protection.
- A successful `sync-global.sh verify` only proves resource accessibility. Open a new product session in a temporary project without a project-level Skill, explicitly invoke `xian-commit`, and ask for its actual source path and project guard result without committing or pushing. This is the runtime discovery smoke test for that product version.
- Discovery does not guarantee automatic invocation. Explicitly invoke the Skill or add a Git-delivery routing rule to the product's supported user instructions. This script does not rewrite those instructions.

Optional local discovery test (requires Node.js and the respective CLIs, not additional shell runtime dependencies):

```sh
node scripts/check-agent-discovery.mjs codex claude
```

It reads initialization discovery lists in an empty temporary directory, without sending a model prompt or executing Git delivery. In Qoder CN, search for `xian-commit` under Extensions → Installed → Skills. These checks verify discovery, not model invocation; use the smoke test above to check actual invocation.

## Recommended project integration

The installer manages only xian-commit's own Skill, prompt, policy, and hooks. It **does not automatically modify the target project's `AGENTS.md` or `CLAUDE.md`**. Those files belong to the target project and often contain architecture, testing, and business constraints, so rewriting them from an installer would be unsafe.

The recommended integration sequence is:

1. Run the installer and `verify` in the target repository.
2. Review `.xian-commit/config` and choose `auto-safe`, `explicit-only`, or `never` for the team's workflow.
3. Reopen the Codex, Claude Code, or Qoder session so project-level Skills or user-level sync results are rescanned.
4. Exercise the setup with one small commit. Confirm the hook messages, commit format, and push boundary before rolling it out to the team.

If the Agent reliably discovers project-level Skills, no entry-file change is required. If the repository should make the Git delivery entry point explicit, add a short routing rule to its existing project instructions.

For `AGENTS.md` (Codex or general Agents):

```markdown
## Git delivery

For commits, pushes, or delivery closeout, use the project-level
`.codex/skills/xian-commit/SKILL.md`, follow `.xian-commit/config`,
and never bypass the Git hooks.
```

For `CLAUDE.md` (Claude Code):

```markdown
## Git delivery

For commits, pushes, or delivery closeout, use the project-level
`.claude/skills/xian-commit/SKILL.md`, follow `.xian-commit/config`,
and never bypass the Git hooks.
```

The entry file should only tell the Agent when to use xian-commit. The installed `SKILL.md` remains the workflow source of truth, `.xian-commit/config` owns project policy, and Git hooks provide deterministic enforcement. Do not copy the full Skill into `AGENTS.md` or `CLAUDE.md`; duplicated rules are likely to drift after updates.

## How it works

After installation, an Agent still calls `git add`, `git commit`, and `git push`; there is no separate Git command set to learn. The Skill guides change attribution and commit planning, policy supplies project rules, and hooks provide a backstop at Git invocation points.

With the default `push.mode=auto-safe`, an automatic non-force push requires all of the following: a commit created in the current run, a clean tracked/staged worktree, an upstream, a readable remote head, local history ahead only (not behind or diverged), and an unprotected current branch. Untracked files alone do not block auto-safe.

If any condition is not met, no automatic push occurs. If an auto-safe push fails, the local commit remains successful. With no configuration, automatic pushes fall back conservatively to `explicit-only` behavior.

## Four Git guardrails

| Hook | What it intercepts or runs | Rejection or fallback behavior |
| --- | --- | --- |
| `pre-commit` | Checks staged paths and blocks paths matching built-in sensitive-file and temporary-file patterns, plus project deny rules | Rejects the commit and suggests `git reset HEAD <files>` to remove files from the staging area |
| `commit-msg` | Validates type, Chinese title, body, duplicate types, and emoji | Rejects the commit; fix the message as instructed and commit again |
| `post-commit` | Performs a non-force push when all `auto-safe` conditions hold | Skips when conditions are insufficient; reports push failures while keeping the local commit successful |
| `pre-push` | Checks only the currently checked-out ordinary branch and its upstream for protected branches, `never` policy, and behind status | Rejects or suggests `git pull --rebase`; without an upstream, only suggests setting one on the first push |

These hooks also apply to `git commit` and `git push` entered by people; they are not limited to Agents.

Path checks handle nested, non-ASCII, space-containing and newline-containing filenames, reject private-key paths such as `*.pem`, and allow deletion of already tracked sensitive files. Deleting a file does not remove secrets from Git history; exposed credentials still need rotation. Git-generated messages starting with `Merge ` or `Revert "` are exempt from the ordinary message format.

If the target repository already has a same-named hook with different contents, the installer backs it up as `*.pre-xian-commit.bak` and writes the xian-commit hook. Backup hooks are **not automatically chained**; manually compose the two behaviors to suit the target project before use. In a linked worktree, hooks are installed in the shared hooks directory resolved by Git. If `core.hooksPath` is configured, installation, updates, and `verify` fail explicitly to avoid overwriting an existing hook manager such as Husky. Decide which tool owns the hooks first, then either keep the existing configuration and chain the behaviors manually or unset it only after confirming that it is no longer needed.

## How it differs from common tools

| Tool | Official focus | What xian-commit focuses on |
| --- | --- | --- |
| [Husky](https://typicode.github.io/husky/) | Manages native Git hooks and can run checks at commit/push time | Agent-oriented change attribution, commit-message policy, staged-path protection, and safe push boundaries |
| [Commitizen](https://commitizen-tools.github.io/commitizen/) | Commit conventions plus version, changelog, and release automation | Does not manage versions, changelogs, or releases |
| [pre-commit](https://pre-commit.com/) | Manages multi-language pre-commit hooks | Does not replace that ecosystem; concentrates on Git rules at the final stage of Agent delivery |

They can coexist in one repository, but xian-commit claims neither replacement nor automatic interoperability or hook orchestration.

## Configuration

The target project's rule file is `.xian-commit/config`; see [policy.example.conf](policy.example.conf) for its format. It stores rules only: do not record change status, Agent plans, or one-time push authorization in it.

| Key | Default | Purpose |
| --- | --- | --- |
| `push.mode` | `auto-safe` | `auto-safe`, `explicit-only`, or `never` |
| `branch.protected` | empty | Rejects or skips matching branch globs |
| `path.allow` | empty | Staged-path globs allowed before deny checks |
| `path.deny` | empty | Additional staged-path globs to reject |
| `message.types` | `feat fix refactor docs test chore` | Allowed commit types |
| `message.title_language` | `zh` | `zh` requires a Chinese title; `any` skips this check |
| `message.body_required` | `true` | Whether a body after the title is required |

`push.mode` means:

- `auto-safe`: post-commit automatically performs a non-force push only when all safety conditions hold.
- `explicit-only`: disables automatic pushes; an Agent pushes only after the current user explicitly asks to push.
- `never`: pre-push rejects pushes on the currently checked-out ordinary branch; legacy value `disabled` is accepted as an alias for `never`.

`path.allow` takes effect before the built-in denylist and `path.deny`, which suits protocol-evidence paths explicitly owned by a project. Ordinary `*.log` files are not rejected by default; use `path.deny` when stricter rules are needed.

pre-push evaluates only the currently checked-out ordinary branch and its upstream: detached HEAD is passed through, and arbitrary remote target refs in `git push` are not resolved. Therefore, `branch.protected` and `never` are client-side guardrails, not substitutes for server-side branch protection.

## Installation and maintenance commands

The `install.sh` commands operate on the current target Git repository. User-level discovery is managed separately by `sync-global.sh`, and the two can be used together.

| Command | Writes to the target repository | Purpose |
| --- | --- | --- |
| `sh /path/to/xian-commit/install.sh` / `sh /path/to/xian-commit/install.sh all` | Yes | Installs all Agent assets, policy, and hooks |
| `sh /path/to/xian-commit/install.sh update` | Yes | Updates the same managed resources while preserving existing config |
| `sh /path/to/xian-commit/install.sh hooks` | Yes | Installs only the four Git hooks |
| `sh /path/to/xian-commit/install.sh skill` | Yes | Installs only the Codex/Claude Code Skill, prompt, reference material, and policy |
| `sh /path/to/xian-commit/install.sh verify` | No | Checks installation completeness and runs a hook smoke test |
| `sh /path/to/xian-commit/install.sh status` | No | Shows installed resources and whether they match source files |
| `sh /path/to/xian-commit/install.sh uninstall` | Yes | Removes managed resources while preserving config and hooks whose contents differ from the managed versions |
| `sh /path/to/xian-commit/sync-global.sh install` | No (writes user-level symlinks) | Registers `xian-commit` in the shared hub and selected product directories |
| `sh /path/to/xian-commit/sync-global.sh status` | No | Read-only view of user-level link status |
| `sh /path/to/xian-commit/sync-global.sh verify` | No | Checks user-level links, broken links, and conflicts |
| `sh /path/to/xian-commit/sync-global.sh uninstall` | No (removes user-level symlinks) | Removes only user-level links managed by this tool |

## Agent and platform compatibility

| Target | Support method |
| --- | --- |
| Codex | Project-level `.codex/skills/xian-commit` plus hooks; optional user-level entry |
| Claude Code | Project-level `.claude/skills/xian-commit` plus hooks; optional user-level entry |
| Qoder / Qoder CN / QoderWork | Project-level hooks/policy via `install.sh`; distinct user-level directories as listed above, with runtime discovery checked on the product version in use |
| Other Coding Agents | Use the hooks independently, or reuse the user-level hub when the product reads `~/.agents/skills`; automatic recognition by every product is not claimed |
| Ubuntu | Verified in CI |
| macOS | Verified in CI |

Current CI runs only on Ubuntu and macOS; Windows support is not claimed.

## Scope and limitations

`xian-commit` does not perform code review, business verification or quality gates, release management, version bumps, or changelog generation. It does not decide whether a feature is complete; it only helps deliver already-confirmed changes through Git safely and explainably.

It also does not automatically modify a target project's `.gitignore`, decide how backup hooks should be orchestrated, or bypass Git remote permissions, branch protection, or conflict resolution. User-level sync only helps Agent products discover Skills; hooks, policy, and project state still come from the project-level installation in each target repository.

## Development and contributing

Run local tests with [tests/run_tests.sh](tests/run_tests.sh):

```sh
sh tests/run_tests.sh
```

CI runs shell syntax checks, tests, and installation smoke tests on `ubuntu-latest` and `macos-latest`. Focused Issues and PRs for reproducible problems are welcome.

Do not paste credentials, private repository content, or directly exploitable vulnerability details into public Issues.

## License

MIT; see [LICENSE](LICENSE).
