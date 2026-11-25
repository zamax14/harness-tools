---
description: Commit all pending work in atomic commits and integrate it into develop (or main/master)
argument-hint: "[free-form instructions, e.g. 'to staging', 'only the api changes']"
disable-model-invocation: true
---

Integrate the pending work of this repo.

User instructions (may be empty): $ARGUMENTS

Current state:
!`git status --short 2>&1 || true`
!`git branch --show-current 2>&1 || true`
!`git branch -a --format='%(refname:short)' 2>&1 | head -40 || true`

## Rules
- Instructions above override every default below (target branch, scope, PR vs merge, etc.).
- Default target branch: `develop` if it exists locally or on the remote, else `main`, else `master`.
- Follow `~/.claude/rules/git-commits.md` for every commit (single-line conventional messages, atomic commits, no co-authors).
- Invoking this command authorizes committing and pushing to the target branch for this run only.
- Never force-push. Never rewrite published history.
- Do not commit secrets (.env, credentials, keys); if any are pending, stop and tell the user.

## Steps
1. Review the full diff and group changes into atomic logical commits.
2. If on a feature branch: commit there, push it, then merge into the target (`--no-ff`) and push the target. If the remote rejects a direct push (protected branch), open a PR with `gh pr create` instead.
3. If already on the target branch: commit there and push.
4. If the merge conflicts, resolve only trivial conflicts; otherwise stop and report.
5. Reply in the user's language with: commits created (one line each), target branch, and PR URL if one was opened.
