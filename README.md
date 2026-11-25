# harness-tools

Personal Claude Code harness: skills (and later agents, rules, output styles, workflows),
versioned in one place and deployed with `install.sh`.

## Layout

The repo mirrors `.claude/`. Each top-level entry of a kind folder is one installable item.

| Folder | Item | Installed to |
|---|---|---|
| `skills/` | `<name>/SKILL.md` | `.claude/skills/<name>` |
| `agents/` | `<name>.md` | `.claude/agents/<name>.md` |
| `rules/` | `<name>.md` | `.claude/rules/<name>.md` |
| `output-styles/` | `<name>.md` | `.claude/output-styles/<name>.md` |
| `workflows/` | `<name>.js` | `.claude/workflows/<name>.js` |

## Skills

All are user-invoked only (`disable-model-invocation: true`), so they cost no context until called.

| Command | Does |
|---|---|
| `/gitflow [instructions]` | Atomic commits, then integrate into `develop` → `main` → `master` |
| `/release [version]` | Merge to main, bump version, CHANGELOG, tag and GitHub release |
| `/orquesta <goal>` | Architect plans roles and tasks (plan mode), then runs subagents |
| `/avance` | Status table of subagents, background and remote jobs |
| `/explora [focus]` | Summary of what the repo is and how it is built |
| `/retoma [focus]` | Where previous sessions left off (git, GitHub, bitácoras, memory) |

## Install

```bash
./install.sh                                  # interactive
./install.sh -s user -a -y                    # all, symlinked into ~/.claude
./install.sh -p ~/code/app gitflow            # into a project, hidden from its git
./install.sh -p ~/code/app -t -a              # into a project, copied and tracked
./install.sh status | list | uninstall [...]
./install.sh --help
```

- **link** (default) keeps items pointing at this repo, so edits apply immediately.
  **copy** is used for tracked projects, since symlinks into `$HOME` break for teammates.
- **Untracked** installs are listed in the project's `.git/info/exclude`.
- The tool only touches what it installed (recorded in `<target>/.claude/.harness-tools`);
  existing files are skipped unless `--force`.

New machine:

```bash
gh repo clone harness-tools ~/Documents/Repos/personal/harness-tools
~/Documents/Repos/personal/harness-tools/install.sh -s user -a -y
```

## Test

```bash
test/install_test.sh
```
