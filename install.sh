#!/usr/bin/env bash
# harness-tools installer: deploys skills, agents, rules, output styles and workflows
# into ~/.claude (user scope) or <project>/.claude (project scope), linked or copied,
# tracked or hidden from the project's git.
#
# Run with no arguments for the interactive menu; flags are for scripting (see --help).
set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KINDS=(skills agents rules output-styles workflows)
MANIFEST_NAME=".harness-tools"
EXCLUDE_BEGIN="# >>> harness-tools"
EXCLUDE_END="# <<< harness-tools"

# ---------- output ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  B=$'\e[1m' D=$'\e[2m' R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' C=$'\e[36m' M=$'\e[35m' N=$'\e[0m'
else
  B="" D="" R="" G="" Y="" C="" M="" N=""
fi
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
hdr()  { printf '\n%s%s%s\n' "$B" "$*" "$N"; }

usage() {
  cat <<EOF
${B}harness-tools installer${N}

  ${C}./install.sh${N}                 open the interactive menu

${B}Scripting${N}
  install.sh [install|uninstall|list|status] [options] [kind/name | name ...]

  -s, --scope user|project   user → ~/.claude   project → <dir>/.claude
  -p, --project DIR          project root (implies --scope project)
  -m, --mode link|copy       default: link, or copy when tracked
  -t, --track                commit the files with the project
  -u, --untrack              hide them via .git/info/exclude (default)
  -a, --all                  select every item
  -n, --dry-run              show what would happen, change nothing
  -f, --force                overwrite items not installed by this tool
  -h, --help                 this help

${B}Examples${N}
  install.sh -s user -a                        everything into ~/.claude, symlinked
  install.sh -p ~/code/app -t gitflow release  copy two skills into a project, tracked
  install.sh uninstall -p ~/code/app           remove everything installed there
EOF
}

# ---------- state ----------
CMD=install SCOPE="" PROJECT="" MODE="" TRACK="" ALL=0 DRY=0 FORCE=0
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
      -y|--yes)     ;; # ponytail: accepted for old scripts, flags never prompt anyway
      -h|--help)    usage; exit 0 ;;
      -*)           die "unknown option: $1 (see --help)" ;;
      *)            SELECTED+=("$1") ;;
    esac
    shift
  done
  [[ -z $SCOPE || $SCOPE =~ ^(user|project)$ ]] || die "--scope must be user or project"
  [[ -z $MODE || $MODE =~ ^(link|copy)$ ]] || die "--mode must be link or copy"
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

describe() { # id [max chars] -> one-line description (skill frontmatter), may be empty
  local f="$REPO_DIR/$1" max=${2:-70}; [[ -d $f ]] && f="$f/SKILL.md"
  ((max > 0)) || return 0
  [[ -f $f ]] && sed -n 's/^description: *//p' "$f" | head -1 | cut -c1-"$max" || true
}

# ---------- target ----------
setup_target() {
  SCOPE=${SCOPE:-user}
  if [[ $SCOPE == user ]]; then
    ROOT="$HOME/.claude"; GIT_EXCLUDE=""; TRACK=""
  else
    PROJECT=$(cd "${PROJECT:-$PWD}" 2>/dev/null && pwd) || die "project directory not found"
    ROOT="$PROJECT/.claude"
    if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
      GIT_EXCLUDE=$(cd "$PROJECT" && realpath -m "$(git rev-parse --git-path info/exclude)")
      if [[ $CMD != install ]]; then # keep whatever the install chose
        grep -qxF "$EXCLUDE_BEGIN" "$GIT_EXCLUDE" 2>/dev/null && TRACK=0 || TRACK=1
      fi
      TRACK=${TRACK:-0}
    else
      [[ -n $TRACK ]] && warn "$PROJECT is not a git repo; tracking option ignored"
      GIT_EXCLUDE=""; TRACK=""
    fi
  fi
  if [[ $CMD == install ]]; then
    [[ -z $MODE && $TRACK == 1 ]] && MODE=copy
    MODE=${MODE:-link}
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
row() { ROWS+=("$1|$2|$3|$4"); } # id | color | text | mode

install_item() {
  local id=$1 src="$REPO_DIR/$1" dest="$ROOT/$1" action
  if [[ -e $dest || -L $dest ]]; then
    if is_ours "$id" "$dest"; then action=updated
    elif [[ $FORCE -eq 1 ]]; then action=replaced
    else row "$id" "$Y" "skipped: exists, not ours (--force)" "-"; return 0; fi
  else action=installed; fi
  [[ $DRY -eq 1 ]] && { row "$id" "$D" "would be $action" "$MODE"; return 0; }
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  if [[ $MODE == link ]]; then ln -s "$src" "$dest"; else cp -R "$src" "$dest"; fi
  manifest_set "$id" "$MODE"
  row "$id" "$G" "$action" "$MODE"
}

uninstall_item() {
  local id=$1 dest="$ROOT/$1"
  is_ours "$id" "$dest" || { row "$id" "$Y" "skipped: not installed by harness-tools" "-"; return 0; }
  [[ $DRY -eq 1 ]] && { row "$id" "$D" "would be removed" "-"; return 0; }
  rm -rf "$dest"; manifest_set "$id" ""
  row "$id" "$G" "removed" "-"
}

health() { # id -> colored ok | missing | broken link
  local dest="$ROOT/$1"
  if [[ -L $dest && ! -e $dest ]]; then echo "${R}broken link${N}"
  elif [[ -e $dest ]]; then echo "${G}ok${N}"
  else echo "${R}missing${N}"; fi
}

summary() {
  [[ ${#ROWS[@]} -gt 0 ]] || return 0
  hdr "Done ${D}→ $ROOT${N}"
  local r id color text mode
  for r in "${ROWS[@]}"; do
    IFS='|' read -r id color text mode <<<"$r"
    printf '  %-26s %s%-40s%s %s%s%s\n' "$id" "$color" "$text" "$N" "$D" "$mode" "$N"
  done
  [[ $DRY -eq 1 ]] && warn "dry run: nothing was changed"
  return 0
}

show_status() {
  hdr "Installed at ${C}$ROOT${N}"
  [[ -f $MANIFEST ]] || { echo "  ${D}nothing installed by harness-tools${N}"; return 0; }
  local id mode
  while read -r id mode; do printf '  %-26s %-6s %s\n' "$id" "$mode" "$(health "$id")"; done <"$MANIFEST"
}

run() { # execute CMD on ids ("$@") against the configured target
  local id
  for id in "$@"; do
    if [[ $CMD == install ]]; then install_item "$id"; else uninstall_item "$id"; fi
  done
  sync_exclude
  summary
}

# ---------- interactive menu ----------
cursor_hide() { printf '\e[?25l'; }
cursor_show() { printf '\e[?25h'; }

read_key() { # -> KEY: up down enter space all quit other
  local k rest
  IFS= read -rsn1 k || { KEY=quit; return; }
  case $k in
    $'\e') IFS= read -rsn2 -t 0.05 rest || true
           case $rest in '[A') KEY=up ;; '[B') KEY=down ;; '') KEY=quit ;; *) KEY=other ;; esac ;;
    '')    KEY=enter ;;
    ' ')   KEY=space ;;
    k)     KEY=up ;;
    j)     KEY=down ;;
    a)     KEY=all ;;
    q)     KEY=quit ;;
    *)     KEY=other ;;
  esac
}

menu_select() { # title option... -> PICK (index); Esc/q -> PICK=-1
  local title=$1; shift
  local -a opts=("$@"); local i=0 n=$# j
  printf '%s?%s %s%s%s  %s↑↓ enter%s\n' "$C" "$N" "$B" "$title" "$N" "$D" "$N"
  while true; do
    for j in "${!opts[@]}"; do
      if ((j == i)); then printf '  %s❯ %s%s\e[K\n' "$C" "${opts[j]}" "$N"
      else printf '    %s\e[K\n' "${opts[j]}"; fi
    done
    read_key
    case $KEY in
      up)    i=$(((i - 1 + n) % n)) ;;
      down)  i=$(((i + 1) % n)) ;;
      enter) break ;;
      quit)  i=-1; break ;;
    esac
    printf '\e[%dA' "$n"
  done
  printf '\e[%dA\e[J' $((n + 1))
  if ((i < 0)); then printf '%s✗%s %s\n' "$D" "$N" "$title"
  else printf '%s✓%s %s %s%s%s\n' "$G" "$N" "$title" "$C" "${opts[i]%%  *}" "$N"; fi
  PICK=$i
}

menu_multi() { # title preselected(0/1 string, one char per option) option... -> PICKS (indices)
  local title=$1 pre=$2; shift 2
  local -a opts=("$@") on=(); local i=0 n=$# j count
  for j in "${!opts[@]}"; do on[j]=${pre:j:1}; done
  printf '%s?%s %s%s%s  %s↑↓ move · space toggle · a all · enter confirm%s\n' "$C" "$N" "$B" "$title" "$N" "$D" "$N"
  while true; do
    for j in "${!opts[@]}"; do
      local box="${D}○${N}"; [[ ${on[j]} == 1 ]] && box="${G}●${N}"
      if ((j == i)); then printf '  %s❯%s %s %s%s%s\e[K\n' "$C" "$N" "$box" "$B" "${opts[j]}" "$N"
      else printf '    %s %s\e[K\n' "$box" "${opts[j]}"; fi
    done
    read_key
    case $KEY in
      up)    i=$(((i - 1 + n) % n)) ;;
      down)  i=$(((i + 1) % n)) ;;
      space) on[i]=$((1 - on[i])) ;;
      all)   local any=0; for j in "${!on[@]}"; do [[ ${on[j]} == 0 ]] && any=1; done
             for j in "${!on[@]}"; do on[j]=$any; done ;;
      enter) break ;;
      quit)  for j in "${!on[@]}"; do on[j]=0; done; break ;;
    esac
    printf '\e[%dA' "$n"
  done
  PICKS=(); for j in "${!on[@]}"; do [[ ${on[j]} == 1 ]] && PICKS+=("$j"); done
  count=${#PICKS[@]}
  printf '\e[%dA\e[J' $((n + 1))
  printf '%s✓%s %s %s%d selected%s\n' "$G" "$N" "$title" "$C" "$count" "$N"
}

ask_path() { # prompt default -> REPLY_PATH (readline, tab completion)
  cursor_show
  read -e -rp "$(printf '%s?%s %s%s%s ' "$C" "$N" "$B" "$1" "$N")" -i "$2" REPLY_PATH
  cursor_hide
  REPLY_PATH=${REPLY_PATH/#\~/$HOME}
}

banner() {
  local kinds=() k
  for k in "${KINDS[@]}"; do [[ -d $REPO_DIR/$k ]] && kinds+=("$k"); done
  printf '\n  %s╭─────────────────────────────────────────╮%s\n' "$M" "$N"
  printf '  %s│%s  %sharness-tools%s                          %s│%s\n' "$M" "$N" "$B" "$N" "$M" "$N"
  printf '  %s│%s  %sClaude Code harness installer%s          %s│%s\n' "$M" "$N" "$D" "$N" "$M" "$N"
  printf '  %s╰─────────────────────────────────────────╯%s\n' "$M" "$N"
  printf '  %s%d items · %s%s\n\n' "$D" "${#ITEMS[@]}" "${kinds[*]}" "$N"
}

tui() {
  cursor_hide
  trap 'cursor_show' EXIT
  trap 'cursor_show; echo; exit 130' INT
  banner
  local -a actions=(install uninstall status)
  while true; do
    SCOPE="" PROJECT="" MODE="" TRACK="" ROWS=()
    menu_select "What do you want to do?" \
      "Install      add or update components" \
      "Uninstall    remove what this tool installed" \
      "Status       see what is installed where" \
      "Quit"
    ((PICK < 0 || PICK == 3)) && break
    CMD=${actions[PICK]}

    menu_select "Where?" \
      "User          ~/.claude, every project" \
      "This project  $PWD" \
      "Other project choose a directory"
    ((PICK < 0)) && continue
    case $PICK in
      0) SCOPE=user ;;
      1) SCOPE=project PROJECT=$PWD ;;
      2) SCOPE=project
         while true; do
           ask_path "Project directory:" "$PWD/"
           [[ -d $REPLY_PATH ]] && { PROJECT=$REPLY_PATH; break; }
           warn "not a directory: $REPLY_PATH"
         done ;;
    esac

    if [[ $CMD == install && $SCOPE == project ]] && git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
      menu_select "Git?" \
        "Untracked  only you, hidden via .git/info/exclude" \
        "Tracked    committed with the project, for the team"
      ((PICK < 0)) && continue
      TRACK=$PICK
    fi
    if [[ $CMD == install && $TRACK != 1 ]]; then
      menu_select "How?" \
        "Link  symlink to this repo, edits apply instantly" \
        "Copy  standalone files, independent of this repo"
      ((PICK < 0)) && continue
      MODE=$([[ $PICK == 0 ]] && echo link || echo copy)
    fi
    setup_target

    if [[ $CMD == status ]]; then show_status; echo; continue; fi

    local -a ids=() labels=(); local pre="" id
    if [[ $CMD == install ]]; then ids=("${ITEMS[@]}"); else mapfile -t ids < <(manifest_ids); fi
    [[ ${#ids[@]} -gt 0 ]] || { warn "nothing installed by harness-tools at $ROOT"; echo; continue; }
    local width; width=$(( $(tput cols 2>/dev/null || echo 80) - 46 )) # keep rows on one line
    for id in "${ids[@]}"; do
      local tag=""; manifest_has "$id" && tag=" ${D}(installed)${N}"
      labels+=("$(printf '%-24s' "$id")${D}$(describe "$id" "$width")${N}$tag")
      [[ $CMD == uninstall ]] && pre+=1 || pre+=0
    done
    menu_multi "Components" "$pre" "${labels[@]}"
    [[ ${#PICKS[@]} -gt 0 ]] || { warn "nothing selected"; echo; continue; }
    local -a chosen=(); local p; for p in "${PICKS[@]}"; do chosen+=("${ids[p]}"); done

    printf '\n  %s%-8s%s %s\n' "$D" target "$N" "$ROOT"
    [[ -n $MODE && $CMD == install ]] && printf '  %s%-8s%s %s\n' "$D" mode "$N" "$MODE"
    [[ -n $TRACK ]] && printf '  %s%-8s%s %s\n' "$D" git "$N" "$([[ $TRACK == 1 ]] && echo tracked || echo untracked)"
    printf '  %s%-8s%s %s\n\n' "$D" items "$N" "${#chosen[@]}"
    menu_select "Proceed with $CMD?" "Yes" "No, back to menu"
    ((PICK == 0)) || continue
    run "${chosen[@]}"
    echo
  done
  cursor_show
  printf '%sbye%s\n' "$D" "$N"
}

# ---------- main ----------
main() {
  local nargs=$#
  parse_args "$@"
  discover
  [[ ${#ITEMS[@]} -gt 0 ]] || die "no items found in $REPO_DIR"

  if [[ $nargs -eq 0 && -t 0 && -t 1 ]]; then tui; return; fi

  setup_target
  case $CMD in
    status) show_status; return ;;
    list)
      hdr "Available ${D}→ target $ROOT${N}"
      local id; for id in "${ITEMS[@]}"; do
        if manifest_has "$id"; then printf '  %s●%s %-26s %s%s%s\n' "$G" "$N" "$id" "$D" "$(manifest_mode "$id")" "$N"
        else printf '  %s○%s %-26s %s%s%s\n' "$D" "$N" "$id" "$D" "$(describe "$id")" "$N"; fi
      done
      return ;;
  esac

  local -a ids=() ; local s
  if [[ $CMD == uninstall ]]; then
    if [[ ${#SELECTED[@]} -gt 0 ]]; then for s in "${SELECTED[@]}"; do ids+=("$(resolve "$s")"); done
    else mapfile -t ids < <(manifest_ids); fi
    [[ ${#ids[@]} -gt 0 ]] || { ok "nothing to uninstall at $ROOT"; return; }
  else
    if [[ $ALL -eq 1 ]]; then ids=("${ITEMS[@]}")
    elif [[ ${#SELECTED[@]} -gt 0 ]]; then for s in "${SELECTED[@]}"; do ids+=("$(resolve "$s")"); done
    else die "nothing selected: pass items or --all (or run with no arguments for the menu)"; fi
  fi
  run "${ids[@]}"
}

main "$@"
