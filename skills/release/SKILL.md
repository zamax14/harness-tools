---
description: Cut a release - merge to main, bump version, changelog, git tag and GitHub release
argument-hint: "[version, e.g. 1.4.0] [extra instructions]"
disable-model-invocation: true
---

Cut a release of this repo.

Arguments (may be empty): $ARGUMENTS

Current state:
!`git status --short 2>&1 || true`
!`git branch --show-current 2>&1 || true`
!`gh release list --limit 3 2>&1 || true`
!`git describe --tags --abbrev=0 2>&1 || true`

## Version
- If the arguments contain a version, use it.
- Otherwise take the latest GitHub release (fallback: latest git tag; none: `0.1.0`) and compute the next natural semver from conventional commits since it: breaking change (`!` or `BREAKING CHANGE`) -> major, any `feat` -> minor, otherwise patch. Keep the existing tag style (`v1.2.3` vs `1.2.3`).

## Steps
1. Abort if the working tree has uncommitted changes; tell the user to run `/gitflow` first.
2. If `develop` exists, merge `develop` into `main`/`master` (`--no-ff`). Invoking this command authorizes that merge.
3. Bump the version in any version file present (package.json, pyproject.toml, Cargo.toml, etc.).
4. Prepend a section to `CHANGELOG.md` (create it if missing): `## vX.Y.Z - YYYY-MM-DD`, commits since the last release grouped by type (Features, Fixes, Other), one line each.
5. Commit `chore(release): vX.Y.Z`, tag it, push branch and tag.
6. `gh release create <tag> --title <tag> --notes "<that changelog section>"`.
7. If `develop` exists, merge main back into develop and push.
8. Never force-push. If CI or a push fails, stop and report.
9. Reply in the user's language: version, release URL, changelog section.
