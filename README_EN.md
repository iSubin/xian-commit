# xian-commit

[简体中文](README.md) · [![CI](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml/badge.svg)](https://github.com/iSubin/xian-commit/actions/workflows/ci.yml) · [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**xian-commit is an installable Git delivery governance Skill for AI Coding Agents such as Codex and Claude Code.**

It keeps Agents on standard Git while adding configurable, deterministic checks for staged scope, commit messages, and push boundaries. The bundled Git hooks are the Skill's deterministic enforcement layer.

It is not a Node/Python package or a resident service. Runtime prerequisites are Git, a POSIX-compatible shell with standard Unix tools, and Perl for Chinese- and emoji-related commit-message checks.

> **Installation scope: xian-commit supports project-level installation only.** The installer writes the Skill, policy, and hooks into the current target Git repository. It does not install into user-level locations such as `~/.codex/skills` or `~/.claude/skills`, and it does not apply globally to other projects. Each project that uses xian-commit must be installed, verified, and updated separately.

## Why xian-commit

AI Coding Agents can write code, but still make concrete and expensive mistakes at the last delivery step: staging runtime or sensitive files, writing duplicate-type titles such as `feat: feat ...`, or pushing without first checking whether the upstream has diverged.

`xian-commit` separates these responsibilities:

- The Agent Skill attributes changes, plans commits, and writes commit messages.
- Policy stores rules only—not runtime state or verbal authorization.
- Git hooks enforce deterministic local boundary checks.
- A remote push is the final external side effect, handled from policy and Git facts.

It is for Git delivery by AI Coding Agents—not a general Git client or a business-quality gate.

## Quick start

Clone this repository first, then install it in **another target Git repository**:

```sh
git clone https://github.com/iSubin/xian-commit.git /path/to/xian-commit
cd /path/to/your-project
sh /path/to/xian-commit/install.sh
sh /path/to/xian-commit/install.sh verify
```

The default installation writes the Codex and Claude Code Skills, a commit-message prompt, lifecycle reference scripts, policy, and four hooks. An existing `.xian-commit/config` is preserved; installation and updates never overwrite it.

Hooks activate from the next `git commit` or `git push`. If a Codex or Claude Code session is already open, reopen the session in the target project so project-level Skills are rescanned.

## Recommended project integration

The installer manages only xian-commit's own Skill, prompt, policy, and hooks. It **does not automatically modify the target project's `AGENTS.md` or `CLAUDE.md`**. Those files belong to the target project and often contain architecture, testing, and business constraints, so rewriting them from an installer would be unsafe.

The recommended integration sequence is:

1. Run the installer and `verify` in the target repository.
2. Review `.xian-commit/config` and choose `auto-safe`, `explicit-only`, or `never` for the team's workflow.
3. Reopen the Codex or Claude Code session so the project-level Skill is rescanned.
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

If the target repository already has a same-named hook with different contents, the installer backs it up as `*.pre-xian-commit.bak` and writes the xian-commit hook. Backup hooks are **not automatically chained**; manually compose the two behaviors to suit the target project before use. In a linked worktree, hooks are installed in the shared hooks directory resolved by Git. If `core.hooksPath` is configured, installation and `verify` fail explicitly to avoid overwriting an existing hook manager such as Husky; unset the configuration or chain the two hook sets manually.

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

All commands below operate on the current target Git repository. User-level and global installation are not supported.

| Command | Writes to the target repository | Purpose |
| --- | --- | --- |
| `sh /path/to/xian-commit/install.sh` / `sh /path/to/xian-commit/install.sh all` | Yes | Installs all Agent assets, policy, and hooks |
| `sh /path/to/xian-commit/install.sh update` | Yes | Updates the same managed resources while preserving existing config |
| `sh /path/to/xian-commit/install.sh hooks` | Yes | Installs only the four Git hooks |
| `sh /path/to/xian-commit/install.sh skill` | Yes | Installs only the Codex/Claude Code Skill, prompt, reference material, and policy |
| `sh /path/to/xian-commit/install.sh verify` | No | Checks installation completeness and runs a hook smoke test |
| `sh /path/to/xian-commit/install.sh status` | No | Shows installed resources and whether they match source files |
| `sh /path/to/xian-commit/install.sh uninstall` | Yes | Removes managed resources while preserving config and hooks whose contents differ from the managed versions |

## Agent and platform compatibility

| Target | Support method |
| --- | --- |
| Codex | Installs the project-level `.codex/skills/xian-commit` and hooks |
| Claude Code | Installs the project-level `.claude/skills/xian-commit` and hooks |
| Other Coding Agents | Use the hooks independently, or manually integrate the root [SKILL.md](SKILL.md); no native support is claimed |
| Ubuntu | Verified in CI |
| macOS | Verified in CI |

Current CI runs only on Ubuntu and macOS; Windows support is not claimed.

## Scope and limitations

`xian-commit` does not perform code review, business verification or quality gates, release management, version bumps, or changelog generation. It does not replace business or Harness decisions about whether a feature is complete; it only helps deliver already-confirmed changes through Git safely and explainably.

It also does not automatically modify a target project's `.gitignore`, decide how backup hooks should be orchestrated, or bypass Git remote permissions, branch protection, or conflict resolution.

## Development and contributing

Run local tests with [tests/run_tests.sh](tests/run_tests.sh):

```sh
sh tests/run_tests.sh
```

CI runs shell syntax checks, tests, and installation smoke tests on `ubuntu-latest` and `macos-latest`. Focused Issues and PRs for reproducible problems are welcome.

Do not paste credentials, private repository content, or directly exploitable vulnerability details into public Issues.

## License

MIT; see [LICENSE](LICENSE).
