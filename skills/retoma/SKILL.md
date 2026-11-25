---
description: Recap where previous sessions left off, from git, GitHub, bitacoras, docs and memory
argument-hint: "[focus]"
disable-model-invocation: true
context: fork
agent: general-purpose
---

Reconstruct where work on this repo was left, from documented previous work. Read-only: change nothing.

Focus (may be empty): $ARGUMENTS

Sources (use what exists):
!`git log --oneline -15 2>&1 || true`
!`git status --short 2>&1 | head -20 || true`
- Branches with unmerged work (`git branch -a --no-merged`).
- GitHub: open PRs, recently closed PRs, open issues, latest CI runs (`gh pr list`, `gh issue list`, `gh run list`).
- Logs and notes: `bitacora*.md` / `BITACORA.md` (read the "Estado actual" section and latest entries first; don't read huge files whole), CHANGELOG, plans, TODO/progress files, docs.
- Claude's auto memory for this project under `~/.claude/projects/<this project>/memory/`.

When sources disagree, trust the repo and GitHub over notes and memory, and flag the stale note.

Reply in Spanish, concise, in the chat:
- **Último trabajo**: what was done most recently and when.
- **En curso**: unfinished work (branches, open PRs, WIP).
- **Pendiente / siguiente paso**: what was planned next.
- **Bloqueos**: what is waiting on someone.
- **Notas desactualizadas**: only if found.
