<div align="center">

# harness-tools

**My Claude Code harness — skills, agents, rules and more — versioned in one repo
and installed anywhere with one interactive command.**

![bash](https://img.shields.io/badge/bash-5%2B-4EAA25?logo=gnubash&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-skills-D97757?logo=anthropic&logoColor=white)
![deps](https://img.shields.io/badge/dependencies-none-blue)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

</div>

---

## Why

Claude Code reads its customizations from `.claude/` folders — global in `~/.claude`, or per
project. Keeping them there means they are scattered, unversioned and stuck on one machine.

This repo is the single source of truth. The installer puts each piece where it belongs:
**user-wide or per project, linked or copied, tracked by the project's git or hidden from it.**

## Quick start

```bash
git clone https://github.com/zamax14/harness-tools.git
cd harness-tools
./install.sh
```

```text
  ╭─────────────────────────────────────────╮
  │  harness-tools                          │
  │  Claude Code harness installer          │
  ╰─────────────────────────────────────────╯
  6 items · skills

✓ What do you want to do? Install
✓ Where? This project
✓ Git? Untracked
✓ How? Link
? Components  ↑↓ move · space toggle · a all · enter confirm
  ❯ ● skills/gitflow          Commit all pending work in atomic commits and…
    ● skills/release          Cut a release - merge to main, bump version…
    ○ skills/orquesta         Architect-led multi-agent orchestration of a…
    ○ skills/avance           Status table of running subagents, backgrou…
```

Arrow keys (or `j`/`k`) to move, `space` to toggle, `enter` to confirm, `q`/`Esc` to go back.

## What's inside

### Skills

Every skill is **user-invoked only** (`disable-model-invocation: true`): Claude never triggers
them on its own, and they cost no context until you type the command.

| Command | What it does |
|---|---|
| `/gitflow [instructions]` | Groups pending changes into atomic Conventional Commits and integrates them into `develop` → `main` → `master` (first that exists). Free-form instructions override the defaults, like `/compact`. |
| `/release [version]` | Merges to main, bumps the version (next semver from commits if omitted), writes `CHANGELOG.md`, tags and publishes a GitHub release. |
| `/orquesta <goal>` | Starts in plan mode: an architect reads the issues or instructions, picks only the roles the goal needs and proposes tasks. After approval, runs one focused subagent per task with review gates. |
| `/avance` | One table with every subagent, background task and remote job (ssh, Slurm, pueue, docker, CI) launched from the conversation — where it runs, status, ETA. |
| `/explora [focus]` | Forked, read-only tour of a repo: purpose, stack, structure, how to run it, state. |
| `/retoma [focus]` | Where the last sessions left off — from git, GitHub, work logs, docs and Claude's memory, trusting the repo over stale notes. |

## How installing works

| Choice | Options | Notes |
|---|---|---|
| **Where** | `~/.claude` · this project · another project | user scope applies to every project |
| **Git** | untracked · tracked | untracked paths go to `.git/info/exclude` — no `.gitignore` diff |
| **How** | link · copy | link = edits here apply instantly; tracked installs always copy, since symlinks into `$HOME` break for teammates |

The installer only touches what it installed. Each target keeps a small manifest
(`.claude/.harness-tools`), so re-running updates, `Status` checks health (broken links, missing
files) and `Uninstall` removes exactly its own items. Existing files it did not create are skipped.

## Layout

The repo mirrors `.claude/`. Drop a file in a kind folder and the installer picks it up.

```text
harness-tools/
├── install.sh                 interactive installer (pure bash, no dependencies)
├── skills/<name>/SKILL.md     → .claude/skills/<name>/
├── agents/<name>.md           → .claude/agents/          (planned)
├── rules/<name>.md            → .claude/rules/           (planned)
├── output-styles/<name>.md    → .claude/output-styles/   (planned)
├── workflows/<name>.js        → .claude/workflows/       (planned)
└── test/install_test.sh
```

## Scripting

No arguments opens the menu; flags run non-interactively (CI, dotfiles bootstrap).

```bash
./install.sh -s user -a                       # everything into ~/.claude, symlinked
./install.sh -p ~/code/app gitflow release    # two skills into a project, untracked
./install.sh -p ~/code/app -t -a              # all into a project, copied and tracked
./install.sh status | list | uninstall [...]  # inspect or remove
./install.sh --help
```

`-n` dry-runs anything; `-f` overwrites files the installer did not create.

## Development

```bash
test/install_test.sh    # throwaway HOME + git repo, asserts install/update/uninstall paths
```

## License

[MIT](LICENSE)
