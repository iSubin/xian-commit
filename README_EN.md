# xian-commit

[简体中文](README.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**A Git delivery governance Skill for AI Coding Agents such as Codex, Claude Code, and Qoder.**

xian-commit keeps Agents on standard `git` while adding configurable, deterministic checks at three points:

- **Staged scope**: blocks sensitive files, temporary files, and project-defined deny paths;
- **Commit messages**: validates type, Chinese title, body, duplicate prefixes, and emoji;
- **Push boundaries**: allows automatic non-force pushes only when safety conditions hold, and rechecks behind status, protected branches, and `never` policy before pushing.

It consists of an Agent Skill, project policy, and four Git hooks: the Skill owns the workflow and judgment, policy stores rules, and hooks enforce them at Git invocation points.

> **Installation scope**: `install.sh` acts only on the current target repository. `sync-global.sh` only exposes the Skill for user-level discovery; it does not install hooks or policy. Every repository that needs hooks must be installed separately.
>
> **Security boundary**: these are client-side guardrails, not server-side enforcement. `git commit --no-verify` can still bypass the hooks. Configure branch protection, permissions, and CI on the remote as the authoritative boundary.

## Contents

- [Why xian-commit](#why-xian-commit)
- [Quick start](#quick-start)
- [The four Git guardrails](#the-four-git-guardrails)
- [Configuration](#configuration)
- [Multiple Agents and platforms](#multiple-agents-and-platforms)
- [Recommended project integration](#recommended-project-integration)
- [How it works](#how-it-works)
- [How it differs from common tools](#how-it-differs-from-common-tools)
- [Repository layout](#repository-layout)
- [Scope and limitations](#scope-and-limitations)
- [Development and contributing](#development-and-contributing)

## Why xian-commit

AI Coding Agents can write code, but they still make expensive mistakes at the final delivery step: staging runtime artifacts or secrets, writing duplicate titles such as `feat: feat ...`, or pushing after the upstream has diverged.

xian-commit separates the responsibilities:

- The Agent Skill attributes changes, plans commits, and writes commit messages;
- Policy stores rules only, not runtime state or verbal authorization;
- Git hooks perform deterministic local boundary checks;
- A remote push is the final external side effect, handled from policy and Git facts.

It focuses on how changes enter Git safely and explainably, not on whether a feature is complete.

## Quick start

### Requirements

- Git;
- A POSIX-compatible shell plus standard Unix tools such as `awk`, `sed`, `xargs`, and `mktemp`;
- Perl for Chinese-title and emoji checks;
- Optional: Node.js, only for the local Agent discovery test.

CI runs on Ubuntu and macOS; Windows support is not claimed.

### Option 1: Full project-level installation

Use this when the Agent should discover xian-commit through a project-level Skill. Clone this repository elsewhere, then install from the target repository:

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

The default installation writes:

- Project-level Skills for Codex and Claude Code;
- The commit-message prompt and `references/` helper scripts;
- `policy.example.conf` and `.xian-commit/config` if it does not already exist;
- All four Git hooks.

An existing `.xian-commit/config` is preserved. Hooks take effect on the next `git commit` or `git push`. If a Codex or Claude Code session is already open, reopen it so project-level Skills are rescanned.

### Option 2: Global Skill plus per-repository hooks (recommended for multiple Agents or repositories)

Use this when several projects should share one Skill without copying a project-level Skill into each repository:

```sh
# 1. Register the user-level Skill (once)
sh /path/to/xian-commit/sync-global.sh install
sh /path/to/xian-commit/sync-global.sh verify

# 2. Install hooks in each target repository
cd /path/to/your-project
sh ~/.agents/skills/xian-commit/references/check-project.sh
sh ~/.agents/skills/xian-commit/install.sh hooks
sh ~/.agents/skills/xian-commit/references/check-project.sh
```

`hooks` installs only the four hooks. It does not copy the Skill or create/modify `.xian-commit/config`. Without configuration, automatic pushes stay off; an existing config, including `auto-safe`, still applies. If you did not install globally, replace `~/.agents/skills/xian-commit` with the actual source path.

You can also ask the Agent directly:

> Use xian-commit to install Git hooks for this project. Check existing hooks first, preserve existing configuration, verify the installation, and do not commit or push.

The Skill performs a read-only check first and skips installation when the result is already `hooks=current`. It writes only for initial setup, an update, or a repair, and explains conflicts before replacing anything.

### Verify the installation

| Check | Applies to | What it does |
| --- | --- | --- |
| `install.sh verify` | Full installation | Checks Skills, prompt, references, config, and hooks, then runs `commit-msg` / `pre-commit` smoke tests; not for hooks-only setups |
| `references/check-project.sh` | Any installation | Checks policy, Git's effective hooks path, and all four hooks' content and executable bits; require `hooks=current` |
| `sync-global.sh verify` | Global Skill | Checks user-level links and resources only; it does not verify Agent loading |

`hooks=unverified` is not a pass, even when the check script exits with code 0. `check-project.sh` compares content and permissions; it does not run a real commit.

### Update and uninstall

- **Full installation**: update the source checkout first (preferably `git pull --ff-only`), then run `install.sh status`, `install.sh update`, and `install.sh verify` in the target repository. `update` preserves the existing config. If `pull` fails because of local changes or divergence, resolve the source checkout state first; do not force-overwrite the installation source.
- **Hooks-only**: run `check-project.sh` first. If it still reports `hooks=current`, skip reinstalling; README or ordinary application-code changes do not require a hook reinstall.
- **Global Skill**: after the source checkout changes, links point to the new content immediately. Run `sync-global.sh install` / `verify` and reopen Agent sessions.
- **Uninstall**: `install.sh uninstall` removes managed resources while preserving config and hooks whose content was modified by the user. `sync-global.sh uninstall` removes only user-level links managed by this tool.

**Overwrite and conflict rules**: when a same-named hook with different content is first encountered, it is backed up as `*.pre-xian-commit.bak`; that first backup is never overwritten, and the backup is not chained automatically. If `core.hooksPath` is set, `install.sh` modes `all`, `update`, `hooks`, and `verify` fail explicitly to avoid overwriting managers such as Husky. Linked worktrees share hooks by default, so installation affects other worktrees of the same repository.

### Command reference

`install.sh` commands operate on the current target Git repository. User-level discovery is managed separately by `sync-global.sh`, and the two can be used together. Script names in the table omit the source path; run them as `/path/to/xian-commit/...` or through the global hub path.

| Command | Writes to target repository | Purpose |
| --- | --- | --- |
| `sh install.sh` / `sh install.sh all` | Yes | Installs all Agent assets, policy, and hooks |
| `sh install.sh update` | Yes | Updates the same managed resources while preserving config |
| `sh install.sh hooks` | Yes | Installs only the four Git hooks |
| `sh install.sh skill` | Yes | Installs only the Codex/Claude Code Skill, prompt, references, and policy (including first-time config) |
| `sh install.sh verify` | No | Checks a full installation and runs smoke tests; not for hooks-only |
| `sh install.sh status` | No | Shows whether installed resources match the source |
| `sh install.sh uninstall` | Yes | Removes managed resources while preserving config and differing hooks |
| `sh sync-global.sh install` | No (writes user-level links) | Registers or refreshes the user-level Skill |
| `sh sync-global.sh status` | No | Shows user-level link status |
| `sh sync-global.sh verify` | No | Checks links, resources, and the ownership manifest |
| `sh sync-global.sh uninstall` | No (removes user-level links) | Removes only user-level links managed by this tool |

## The four Git guardrails

| Hook | What it intercepts or runs | Rejection or fallback behavior |
| --- | --- | --- |
| `pre-commit` | Checks staged paths and blocks sensitive files, temporary files, and project deny rules | Rejects the commit and suggests `git reset HEAD <files>` to unstage them |
| `commit-msg` | Validates type, Chinese title, body, duplicate types, and emoji; exempts Merge/Revert messages only while the corresponding Git operation state is valid | Rejects ordinary non-compliant commits; fix the message and commit again |
| `post-commit` | Performs a non-force push when all `auto-safe` conditions hold | Skips when conditions are insufficient; reports push failures while keeping the local commit successful |
| `pre-push` | Checks the currently checked-out ordinary branch and its upstream for protected branches, `never` policy, and behind status | Rejects or suggests `git pull --rebase`; without an upstream, only suggests setting one on the first push |

These hooks also apply to `git commit` and `git push` entered by people, not only to Agents.

**Default message rules**: allowed types are `feat fix refactor docs test chore`; the title must contain Chinese; a body is required; duplicate type prefixes and emoji are rejected.

**Strict Merge/Revert boundary**: exemption applies only while the corresponding merge/revert operation state exists and is valid. After the operation finishes, `git commit --amend --no-edit` with the default `Merge ...` / `Revert "..."` message is rejected; amend with a message that complies with policy instead. Amending an ordinary compliant message with `--no-edit` is unaffected. This intentional restriction prevents ordinary commits from impersonating those operations; do not bypass it with `--no-verify`.

**Path checks**: path checks handle nested directories, Chinese characters, spaces, and newline-containing filenames, and allow deletion of already tracked sensitive files. By default they block `.xian-relay*`, `*.env`, `*.tmp`, `*.swp`, `*.pem`, `id_rsa`, `.DS_Store`, and similar paths. Deleting a file does not remove secrets from Git history; exposed credentials still need rotation.

## Configuration

The target project's rule file is `.xian-commit/config`; see [policy.example.conf](policy.example.conf) for its format. It stores rules only: do not record change status, Agent plans, or one-time push authorization in it.

| Key | Default | Purpose |
| --- | --- | --- |
| `push.mode` | `auto-safe` | `auto-safe`, `explicit-only`, or `never` |
| `branch.protected` | empty | Branch globs rejected or skipped |
| `path.allow` | empty | Staged-path globs allowed before deny checks |
| `path.deny` | empty | Additional staged-path globs to reject |
| `message.types` | `feat fix refactor docs test chore` | Allowed commit types |
| `message.title_language` | `zh` | `zh` requires a Chinese title; `any` skips the check |
| `message.body_required` | `true` | Whether a body after the title is required |

`push.mode` values:

- `auto-safe`: post-commit performs a non-force push only when all safety conditions hold;
- `explicit-only`: disables automatic pushes; an Agent pushes only after the current user explicitly asks;
- `never`: pre-push rejects pushes on the currently checked-out ordinary branch; legacy value `disabled` is accepted as an alias.

A config created by a full installation defaults to `auto-safe`. Without a config, post-commit behaves as `explicit-only`. An `auto-safe` push requires all of the following: a commit created in the current run, a clean tracked/staged worktree, an upstream, a readable remote head, local history ahead only (not behind or diverged), and an unprotected current branch. Untracked files alone do not block auto-safe. If any condition fails, no automatic push occurs; if the push itself fails, the local commit remains successful.

`path.allow` takes effect before the built-in denylist and `path.deny`, which suits protocol-evidence paths explicitly owned by a project. Ordinary `*.log` files are not rejected by default; use `path.deny` for stricter rules.

pre-push evaluates only the currently checked-out ordinary branch and its upstream: detached HEAD is passed through, and arbitrary remote target refs in `git push` are not resolved. Therefore, `branch.protected` and `never` are client-side guardrails, not substitutes for server-side branch protection.

## Multiple Agents and platforms

| Product | Project-level support | User-level entry |
| --- | --- | --- |
| Codex | `.codex/skills/xian-commit` + hooks | `~/.codex/skills/xian-commit` |
| Claude Code | `.claude/skills/xian-commit` + hooks | `~/.claude/skills/xian-commit` |
| Qoder CN | hooks/policy installed by `install.sh` | `~/.qoder-cn/skills/xian-commit` |
| Qoder / Qoder CLI | hooks/policy installed by `install.sh` | `~/.qoder/skills/xian-commit` |
| QoderWork | hooks/policy installed by `install.sh` | `~/.qoderwork/skills/xian-commit` |
| Other Coding Agents | Can use hooks independently | Reuse the hub if the product reads `~/.agents/skills` |

Qoder products do not share a single directory: see the [Qoder CLI documentation](https://docs.qoder.com/cli/Skills) and [QoderWork documentation](https://docs.qoder.com/qoderwork/skills). Directory adapters are not a claim of runtime certification for every product version.

`install.sh` installs project-level Skills only for Codex and Claude Code. Qoder products use the user-level entries in the table above; confirm discovery on the actual product version.

### User-level sync details

The shared hub is `~/.agents/skills/xian-commit`; the whole directory links to the source checkout, preserving a real `SKILL.md` instead of a file symlink that some scanners ignore. All five product entries above are created by default. Links are created even when the product is not installed, but that does not install the product itself. Use `--agents codex,claude,qoder-cn` to select a subset, and repeat the same selection for subsequent `install/status/verify` commands.

- Ownership is recorded in `~/.agents/xian-commit-sync.tsv`. After moving the source checkout, run `install` from its new location to repair owned links. Missing source files make `verify` fail, but `uninstall` still works from any intact copy using the recorded inventory.
- Reducing `--agents` reconciles only recorded entries that the user has not replaced. Conflicting real directories or foreign links stop installation before writes. Existing same-target manual links are marked `borrowed` and survive uninstall. If borrowed product links still depend on the shared hub, uninstall preserves the hub and asks for manual cleanup before retrying.
- Older versions have no reliable ownership inventory. After checking the existing `xian-commit` links, run `install --adopt-legacy` once before moving or uninstalling. Only `xian-commit` is adopted; other `xian-*` entries exported by older versions require separate inspection.
- `--home /path/to/home` supports an isolated installation; `--dry-run` writes nothing to the target.

### Agent discovery smoke test

A successful `sync-global.sh verify` proves only that links and resources are accessible. Reopen a product session, explicitly invoke `xian-commit` in a temporary project without a project-level Skill, and ask for the Skill's actual source path and project guard result without committing or pushing. That is the runtime discovery smoke test for the product version in use.

Optional local automated check (requires Node.js and the respective CLIs):

```sh
node scripts/check-agent-discovery.mjs codex claude
```

It reads initialization discovery lists in an empty temporary directory, without sending a model prompt or executing Git delivery. In Qoder CN, search for `xian-commit` under Extensions → Installed → Skills. These checks verify discovery, not whether the model actually follows the rules.

Discovery does not guarantee automatic invocation. Explicitly invoke the Skill, or add a Git-delivery routing rule to the product's supported user instructions. This script does not rewrite those instructions.

## Recommended project integration

The installer manages only xian-commit's own Skill, prompt, policy, and hooks. It **does not automatically modify the target project's `AGENTS.md` or `CLAUDE.md`**. Those files belong to the target project and often contain architecture, testing, and business constraints, so rewriting them from an installer would be unsafe.

Recommended sequence:

1. Ask the Skill to install and check hooks in the target repository. Choose full installation and `verify` only when project-level Skills and policy are also needed.
2. If `.xian-commit/config` exists, review whether its `auto-safe`, `explicit-only`, or `never` setting fits the team's workflow. Hooks-only without configuration does not automatically push.
3. Reopen the Codex, Claude Code, or Qoder session so project-level Skills or user-level sync results are rescanned.
4. Exercise the setup with one small commit. Confirm the hook messages, commit format, and push boundary before rolling it out to the team.

If the Agent reliably discovers the global or project-level Skill, no entry-file change is required. If the repository should make the Git delivery entry point explicit, add a short routing rule to its existing project instructions. The paths below assume a full project-level installation. Global Skill users should instead say “Use the xian-commit Skill and follow existing project policy,” without referencing a nonexistent project-level copy.

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

A default full installation uses `push.mode=auto-safe`: it pushes automatically only when every safety condition holds. If conditions are insufficient, or no config exists, no automatic push occurs. A remote push is the final external side effect; a failed push does not roll back a completed local commit.

## How it differs from common tools

| Tool | Official focus | What xian-commit focuses on |
| --- | --- | --- |
| [Husky](https://typicode.github.io/husky/) | Manages native Git hooks and can run checks at commit/push time | Agent-oriented change attribution, commit-message policy, staged-path protection, and safe push boundaries |
| [Commitizen](https://commitizen-tools.github.io/commitizen/) | Commit conventions plus version, changelog, and release automation | Does not manage versions, changelogs, or releases |
| [pre-commit](https://pre-commit.com/) | Manages multi-language pre-commit hooks | Does not replace that ecosystem; concentrates on Git rules at the final stage of Agent delivery |

They can coexist in one repository, but xian-commit claims neither replacement nor automatic interoperability or hook orchestration.

## Repository layout

```text
hooks/               Four Git hooks
install.sh           Project-level install, update, verify, uninstall
sync-global.sh       User-level Skill sync
SKILL.md             Agent workflow and delivery boundaries
prompts/             Commit-message rules
references/          Helper scripts such as check-project.sh
scripts/             Agent discovery smoke test
tests/               Shell regression tests
policy.example.conf  Policy template
```

## Scope and limitations

- It does not perform code review, business verification or quality gates, release management, version bumps, or changelog generation.
- It does not decide whether a feature is complete; it only helps deliver already-confirmed changes through Git safely and explainably.
- It does not automatically modify a target project's `.gitignore`, decide how backup hooks should be orchestrated, or bypass Git remote permissions, branch protection, or conflict resolution.
- User-level sync only helps Agent products discover Skills; hooks, policy, and project state still come from the project-level installation in each target repository.
- It does not require an external Harness or change lifecycle.

## Development and contributing

Run local tests with [tests/run_tests.sh](tests/run_tests.sh):

```sh
sh tests/run_tests.sh
```

CI runs shell syntax checks, tests, and an installation smoke test on `ubuntu-latest` and `macos-latest`. Focused Issues and PRs for reproducible problems are welcome.

Do not paste credentials, private repository content, or directly exploitable vulnerability details into public Issues.

## License

MIT; see [LICENSE](LICENSE).
