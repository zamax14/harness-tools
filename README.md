<div align="center">

# harness-tools

**My Claude Code harness — skills, agents, rules and more — in one repo,
installed into any project or `~/.claude` with one command.**

![bash](https://img.shields.io/badge/bash-5%2B-4EAA25?logo=gnubash&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-harness-D97757?logo=anthropic&logoColor=white)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

</div>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/zamax14/harness-tools/main/install.sh | bash
```

Clones the repo to `~/.local/share/harness-tools` and adds the `harness-tools` command.

## Use

```bash
cd ~/code/my-app
harness-tools            # interactive menu: this project or ~/.claude
harness-tools list       # what's available
harness-tools update     # pull the latest version
```

```text
✓ What do you want to do? Install
✓ Where? This project
✓ Git? Untracked
✓ How? Link
? Components  ↑↓ move · space toggle · a all · enter confirm
  ❯ ● skills/gitflow          Commit all pending work in atomic commits…
    ○ skills/release          Cut a release - merge to main, bump version…
```

- **Where**: the git root you are in, or `~/.claude` for every project.
- **Git**: untracked (hidden via `.git/info/exclude`) or tracked with the project.
- **How**: link (edits here apply instantly) or copy. Tracked installs always copy.

It only touches what it installed, so `Status` and `Uninstall` are safe to run anywhere.
For scripting, see `harness-tools --help`.

## What's inside

The repo mirrors `.claude/`; each folder is a kind, each entry an installable item.
Every item describes itself (a skill's `description`), and `harness-tools list` shows the catalog.

| Folder | Installs to |
|---|---|
| [`skills/`](skills) | `.claude/skills/` |
| `agents/` | `.claude/agents/` |
| `rules/` | `.claude/rules/` |
| `output-styles/` | `.claude/output-styles/` |
| `workflows/` | `.claude/workflows/` |

Skills here are user-invoked only (`disable-model-invocation: true`): they cost no context
until you type the command.

## Hack on it

```bash
git clone https://github.com/zamax14/harness-tools.git && cd harness-tools
./install.sh self-install   # point the command at your clone
test/install_test.sh
```

Add an item by dropping it in its folder; the installer picks it up.

## License

[MIT](LICENSE)
