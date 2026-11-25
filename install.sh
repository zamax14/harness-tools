#!/usr/bin/env bash
# harness-tools installer: deploys skills, agents, rules, output styles and workflows
# into ~/.claude (user scope) or <project>/.claude (project scope), linked or copied,
# tracked or hidden from the project's git.
set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KINDS=(skills agents rules output-styles workflows)
MANIFEST_NAME=".harness-tools"
EXCLUDE_BEGIN="# >>> harness-tools"
EXCLUDE_END="# <<< harness-tools"

# ---------- output ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  B=$'\e[1m' D=$'\e[2m' R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' C=$'\e[36m' N=$'\e[0m'
else
  B="" D="" R="" G="" Y="" C="" N=""
fi
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
hdr()  { printf '\n%s%s%s\n' "$B" "$*" "$N"; }

usage() {
  cat <<EOF
${B}harness-tools installer${N}

${B}Usage${N}
  install.sh [install|uninstall|list|status] [options] [kind/name | name ...]

${B}Commands${N}
  install     install items (default)
  uninstall   remove items installed by this tool (all of them if none given)
  list        list available items and whether they are installed at the target
  status      show what is installed at the target and whether it is healthy

${B}Options${N}
  -s, --scope user|project   user → ~/.claude   project → <dir>/.claude
  -p, --project DIR          project root (implies --scope project; default: \$PWD)
  -m, --mode link|copy       default: link, or copy when tracked
  -t, --track                commit the files with the project
  -u, --untrack              hide them via .git/info/exclude (default)
  -a, --all                  select every item
  -n, --dry-run              show what would happen, change nothing
  -f, --force                overwrite items not installed by this tool
  -y, --yes                  no prompts (required for non-interactive use)
  -h, --help                 this help

${B}Examples${N}
  install.sh                                   interactive
  install.sh -s user -a -y                     everything into ~/.claude, symlinked
  install.sh -p ~/code/app -t gitflow release  copy two skills into a project, tracked
  install.sh uninstall -p ~/code/app -y        remove everything installed there
EOF
}

# ---------- state ----------
CMD=install SCOPE="" PROJECT="" MODE="" TRACK="" ALL=0 DRY=0 FORCE=0 YES=0
ITEMS=() SELECTED=() ROWS=()

parse_args() {
  if [[ $# -gt 0 && "$1" =~ ^(install|uninstall|list|status)$ ]]; then CMD=$1; shift; fi
  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--scope)   SCOPE=${2:?--scope needs a value}; shift ;;
      -p|--project) PROJECT=${2:?--project needs a value}; SCOPE=project; shift ;;
      -m|--mode)    MODE=${2:?--mode needs a value}; shift ;;
      -t|--track)   TRACK=1 ;;
      -u|--untrack) TRACK=0 ;;
      -a|--all)     ALL=1 ;;
      -n|--dry-run) DRY=1 ;;
      -f|--force)   FORCE=1 ;;
      -y|--yes)     YES=1 ;;
      -h|--help)    usage; exit 0 ;;
      -*)           die "unknown option: $1 (see --help)" ;;
      *)            SELECTED+=("$1") ;;
    esac
    shift
  done
  [[ -z $SCOPE || $SCOPE =~ ^(user|project)$ ]] || die "--scope must be user or project"
  [[ -z $MODE || $MODE =~ ^(link|copy)$ ]] || die "--mode must be link or copy"
}

interactive() { [[ $YES -eq 0 && -t 0 && -t 1 ]]; }

ask() { # ask "question" default -> echoes answer
  local reply; read -rp "$(printf '%s?%s %s %s[%s]%s ' "$C" "$N" "$1" "$D" "$2" "$N")" reply
  echo "${reply:-$2}"
}

# ---------- items ----------
discover() {
  local kind entry
  for kind in "${KINDS[@]}"; do
    [[ -d "$REPO_DIR/$kind" ]] || continue
    for entry in "$REPO_DIR/$kind"/*; do
      [[ -e $entry ]] || continue
      case $kind in
        skills)    [[ -d $entry ]] || continue ;;
        workflows) [[ -f $entry && $entry == *.js ]] || continue ;;
        *)         [[ -f $entry && $entry == *.md ]] || continue ;;
      esac
      ITEMS+=("$kind/$(basename "$entry")")
    done
  done
}

resolve() { # "name" or "kind/name" -> item id
  local want=$1 id matches=()
  for id in "${ITEMS[@]}"; do
    [[ $id == "$want" || ${id#*/} == "$want" || ${id#*/} == "$want".md || ${id#*/} == "$want".js ]] && matches+=("$id")
  done
  [[ ${#matches[@]} -eq 1 ]] || die "'$want' matches ${#matches[@]} items (use kind/name; see list)"
  echo "${matches[0]}"
}

pick() { # numbered toggle menu over ITEMS -> SELECTED
  local -a on=() i n input
  for i in "${!ITEMS[@]}"; do on[i]=0; done
  while true; do
    hdr "Components ${D}(numbers toggle, a = all, n = none, Enter = done)${N}"
    for i in "${!ITEMS[@]}"; do
      local mark=" "; [[ ${on[i]} -eq 1 ]] && mark="${G}x${N}"
      printf '  [%s] %2d  %s\n' "$mark" $((i + 1)) "${ITEMS[i]}"
    done
    read -rp "> " input
    [[ -z $input ]] && break
    for n in $input; do
      case $n in
        a) for i in "${!ITEMS[@]}"; do on[i]=1; done ;;
        n) for i in "${!ITEMS[@]}"; do on[i]=0; done ;;
        *) [[ $n =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#ITEMS[@]} ]] && on[n-1]=$((1 - on[n-1])) || warn "ignored: $n" ;;
      esac
    done
  done
  for i in "${!ITEMS[@]}"; do [[ ${on[i]} -eq 1 ]] && SELECTED+=("${ITEMS[i]}"); done
  return 0
}

# ---------- target ----------
setup_target() {
  if [[ -z $SCOPE ]] && interactive; then
    [[ $(ask "Scope: (u)ser ~/.claude or (p)roject" u) == p* ]] && SCOPE=project || SCOPE=user
  fi
  SCOPE=${SCOPE:-user}

  if [[ $SCOPE == user ]]; then
    ROOT="$HOME/.claude"; GIT_EXCLUDE=""; TRACK=""
  else
    [[ -z $PROJECT ]] && interactive && PROJECT=$(ask "Project directory" "$PWD")
    PROJECT=$(cd "${PROJECT:-$PWD}" 2>/dev/null && pwd) || die "project directory not found"
    ROOT="$PROJECT/.claude"
    if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
      GIT_EXCLUDE=$(cd "$PROJECT" && realpath -m "$(git rev-parse --git-path info/exclude)")
      if [[ $CMD != install ]]; then # keep whatever the install chose
        grep -qxF "$EXCLUDE_BEGIN" "$GIT_EXCLUDE" 2>/dev/null && TRACK=0 || TRACK=1
      elif [[ -z $TRACK ]] && interactive; then
        [[ $(ask "Track in the project's git? (y/N)" n) == y* ]] && TRACK=1 || TRACK=0
      fi
      TRACK=${TRACK:-0}
    else
      [[ -n $TRACK ]] && warn "$PROJECT is not a git repo; --track/--untrack ignored"
      GIT_EXCLUDE=""; TRACK=""
    fi
  fi

  if [[ $CMD == install ]]; then
    if [[ -z $MODE ]]; then
      if [[ $TRACK == 1 ]]; then MODE=copy
      elif interactive; then [[ $(ask "Mode: (l)ink or (c)opy" l) == c* ]] && MODE=copy || MODE=link
      else MODE=link; fi
    fi
    [[ $TRACK == 1 && $MODE == link ]] && die "tracked + link would commit symlinks into your \$HOME; use --mode copy"
  fi
  MANIFEST="$ROOT/$MANIFEST_NAME"
}

manifest_has()  { [[ -f $MANIFEST ]] && awk -v id="$1" '$1 == id { f = 1 } END { exit !f }' "$MANIFEST"; }
manifest_ids()  { [[ -f $MANIFEST ]] && awk '{ print $1 }' "$MANIFEST" || true; }
manifest_mode() { awk -v id="$1" '$1 == id { print $2 }' "$MANIFEST"; }
manifest_set() { # id mode|"" (empty removes)
  local tmp; tmp=$(mktemp)
  [[ -f $MANIFEST ]] && awk -v id="$1" '$1 != id' "$MANIFEST" >"$tmp"
  [[ -n $2 ]] && echo "$1 $2" >>"$tmp"
  if [[ -s $tmp ]]; then mkdir -p "$ROOT"; mv "$tmp" "$MANIFEST"; else rm -f "$tmp" "$MANIFEST"; fi
}

is_ours() { # id dest
  manifest_has "$1" && return 0
  [[ -L $2 && $(readlink "$2") == "$REPO_DIR/"* ]]
}

sync_exclude() { # rewrite our block in .git/info/exclude from the manifest
  [[ -n $GIT_EXCLUDE && $DRY -eq 0 ]] || return 0
  local tmp id; tmp=$(mktemp)
  [[ -f $GIT_EXCLUDE ]] && awk -v b="$EXCLUDE_BEGIN" -v e="$EXCLUDE_END" \
    '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$GIT_EXCLUDE" >"$tmp"
  if [[ $TRACK == 0 && -f $MANIFEST ]]; then
    { echo "$EXCLUDE_BEGIN"; echo "/.claude/$MANIFEST_NAME"
      for id in $(manifest_ids); do echo "/.claude/$id"; done
      echo "$EXCLUDE_END"; } >>"$tmp"
  fi
  mkdir -p "$(dirname "$GIT_EXCLUDE")"; mv "$tmp" "$GIT_EXCLUDE"
}

# ---------- actions ----------
row() { ROWS+=("$1|$2|$3"); }

install_item() {
  local id=$1 src="$REPO_DIR/$1" dest="$ROOT/$1" action
  if [[ -e $dest || -L $dest ]]; then
    if is_ours "$id" "$dest"; then action=updated
    elif [[ $FORCE -eq 1 ]]; then action=replaced
    else row "$id" "${Y}skipped${N} (exists, not ours; --force)" "-"; return 0; fi
  else action=installed; fi
  [[ $DRY -eq 1 ]] && { row "$id" "would be $action" "$MODE"; return 0; }
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  if [[ $MODE == link ]]; then ln -s "$src" "$dest"; else cp -R "$src" "$dest"; fi
  manifest_set "$id" "$MODE"
  row "$id" "${G}$action${N}" "$MODE"
}

uninstall_item() {
  local id=$1 dest="$ROOT/$1"
  is_ours "$id" "$dest" || { row "$id" "${Y}skipped${N} (not installed by harness-tools)" "-"; return 0; }
  [[ $DRY -eq 1 ]] && { row "$id" "would be removed" "-"; return 0; }
  rm -rf "$dest"; manifest_set "$id" ""
  row "$id" "${G}removed${N}" "-"
}

health() { # id -> ok | missing | broken link
  local dest="$ROOT/$1"
  if [[ -L $dest && ! -e $dest ]]; then echo "${R}broken link${N}"
  elif [[ -e $dest ]]; then echo "${G}ok${N}"
  else echo "${R}missing${N}"; fi
}

summary() {
  [[ ${#ROWS[@]} -gt 0 ]] || return 0
  hdr "Summary ${D}($ROOT)${N}"
  local r; for r in "${ROWS[@]}"; do
    IFS='|' read -r a b c <<<"$r"
    printf '  %-28s %-42s %s\n' "$a" "$b" "$c"
  done
  [[ $DRY -eq 1 ]] && warn "dry run: nothing was changed"
  return 0
}

# ---------- main ----------
main() {
  parse_args "$@"
  discover

  case $CMD in
    list)
      setup_target
      hdr "Available ${D}(repo: $REPO_DIR, target: $ROOT)${N}"
      local id; for id in "${ITEMS[@]}"; do
        if manifest_has "$id"; then printf '  %s✓%s %-28s %s\n' "$G" "$N" "$id" "$(manifest_mode "$id")"
        else printf '    %s\n' "$id"; fi
      done
      return ;;
    status)
      setup_target
      hdr "Installed at $ROOT"
      [[ -f $MANIFEST ]] || { echo "  nothing installed by harness-tools"; return; }
      while read -r id mode; do printf '  %-28s %-6s %s\n' "$id" "$mode" "$(health "$id")"; done <"$MANIFEST"
      return ;;
  esac

  [[ ${#ITEMS[@]} -gt 0 ]] || die "no items found in $REPO_DIR"
  setup_target

  local -a ids=()
  if [[ $CMD == uninstall ]]; then
    if [[ ${#SELECTED[@]} -gt 0 ]]; then local s; for s in "${SELECTED[@]}"; do ids+=("$(resolve "$s")"); done
    else mapfile -t ids < <(manifest_ids); fi
    [[ ${#ids[@]} -gt 0 ]] || { ok "nothing to uninstall at $ROOT"; return; }
  else
    if [[ $ALL -eq 1 ]]; then ids=("${ITEMS[@]}")
    elif [[ ${#SELECTED[@]} -gt 0 ]]; then local s; for s in "${SELECTED[@]}"; do ids+=("$(resolve "$s")"); done
    elif interactive; then pick; ids=("${SELECTED[@]}")
    else die "nothing selected: pass items, --all, or run in a terminal"; fi
    [[ ${#ids[@]} -gt 0 ]] || die "nothing selected"
  fi

  if interactive; then
    hdr "Plan"
    printf '  %-9s %s\n' command "$CMD" target "$ROOT"
    [[ $CMD == install ]] && printf '  %-9s %s\n' mode "$MODE"
    [[ -n $TRACK ]] && printf '  %-9s %s\n' git "$([[ $TRACK == 1 ]] && echo tracked || echo "untracked (.git/info/exclude)")"
    printf '  %-9s %s\n' items "${ids[*]}"
    [[ $(ask "Proceed? (Y/n)" y) == y* ]] || die "aborted"
  fi

  local id; for id in "${ids[@]}"; do
    if [[ $CMD == install ]]; then install_item "$id"; else uninstall_item "$id"; fi
  done
  sync_exclude
  summary
}

main "$@"
