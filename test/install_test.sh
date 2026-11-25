#!/usr/bin/env bash
# Self-check for install.sh in a throwaway HOME and git repo. Run: test/install_test.sh
set -euo pipefail
INSTALL="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" NO_COLOR=1; mkdir -p "$HOME"
PROJ="$TMP/proj"; git init -q "$PROJ"
EXCL="$PROJ/.git/info/exclude"
run() { "$INSTALL" "$@" -y >/dev/null; }
pass=0; check() { if eval "$2"; then pass=$((pass + 1)); else echo "FAIL: $1"; exit 1; fi; }

run -s user -a
check "user install links" '[[ -L $HOME/.claude/skills/gitflow ]]'
check "manifest written" 'grep -q "skills/gitflow link" $HOME/.claude/.harness-tools'
run -s user -a
check "idempotent" '[[ $(wc -l <$HOME/.claude/.harness-tools) -eq $(ls -d "$(dirname "$INSTALL")"/skills/*/ | wc -l) ]]'

run -p "$PROJ" -m copy gitflow
check "untracked copy" '[[ -f $PROJ/.claude/skills/gitflow/SKILL.md && ! -L $PROJ/.claude/skills/gitflow ]]'
check "exclude block" 'grep -qx "/.claude/skills/gitflow" $EXCL'
check "git ignores it" '[[ -z $(git -C $PROJ status --porcelain) ]]'

mkdir -p "$PROJ/.claude/skills/release"
run -p "$PROJ" release
check "foreign skipped" '[[ ! -L $PROJ/.claude/skills/release ]] && ! grep -q skills/release $PROJ/.claude/.harness-tools'
rmdir "$PROJ/.claude/skills/release"

run uninstall -p "$PROJ"
check "uninstall clean" '[[ ! -e $PROJ/.claude/skills/gitflow && ! -e $PROJ/.claude/.harness-tools ]] && ! grep -q harness-tools $EXCL'

! "$INSTALL" -p "$PROJ" -t -m link -a -y >/dev/null 2>&1
check "tracked+link refused" '[[ ! -e $PROJ/.claude/.harness-tools ]]'
run -p "$PROJ" -t -a
check "tracked copy, no exclude" '[[ -f $PROJ/.claude/skills/retoma/SKILL.md ]] && ! grep -q harness-tools $EXCL'
run uninstall -p "$PROJ" retoma
check "tracked uninstall adds no exclude" '! grep -q harness-tools $EXCL && [[ ! -e $PROJ/.claude/skills/retoma ]]'

echo "ok: $pass checks passed"
