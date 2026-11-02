#!/usr/bin/env bash
# install.sh — link team skills from this handbook into your AI coding tools.
#
# Usage (run from anywhere):
#   team-skills/install.sh --list              show teams and the skills each one has
#   team-skills/install.sh sales marketing     install exactly these teams (saved in local/my-teams)
#   team-skills/install.sh                     re-sync using the saved teams (run after git pull)
#   team-skills/install.sh --uninstall         remove every link this script created
#   team-skills/install.sh --copy <team>...    copy instead of symlink, for tools that ignore symlinks
#
# Safe to run any time. It only touches entries it created itself.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILLS_DIR="$REPO/team-skills"
TEAMS_FILE="$REPO/local/my-teams"
MARKER=".oursky-handbook-skill"   # placed inside copied skills so we can recognise them later

# Where each tool looks for user-level skills. Only targets whose parent folder exists
# (i.e. the tool is installed) are used. Override with OURSKY_SKILL_TARGETS if needed.
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGETS="${OURSKY_SKILL_TARGETS:-$HOME/.claude/skills $CODEX_HOME/skills $XDG_CONFIG_HOME/opencode/skills}"

usage() { sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
die()   { echo "error: $*" >&2; exit 1; }
warn()  { echo "warning: $*" >&2; }

list_teams() {
  local d t
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    t="$(basename "$d")"
    case "$t" in _*) continue ;; esac
    echo "$t"
  done
}

# Print the full path of every valid skill folder in a team, one per line.
team_skills() {
  local team="$1" d name fm_name
  [ -d "$SKILLS_DIR/$team" ] || die "no team folder team-skills/$team — run with --list to see teams"
  for d in "$SKILLS_DIR/$team"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    name="$(basename "$d")"
    if [ ! -f "$d/SKILL.md" ]; then
      warn "team-skills/$team/$name has no SKILL.md, skipped"; continue
    fi
    case "$name" in "$team-"*) ;; *)
      warn "team-skills/$team/$name must be named $team-<something>, skipped"; continue ;;
    esac
    fm_name="$(sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1 | tr -d '"'"'"' ')"
    if [ "$fm_name" != "$name" ]; then
      warn "team-skills/$team/$name/SKILL.md says name: '$fm_name', expected '$name', skipped"; continue
    fi
    echo "$d"
  done
}

# True if this entry was created by us: a symlink into team-skills/, or a copy with our marker.
is_ours() {
  local p="$1" t
  if [ -L "$p" ]; then
    t="$(readlink "$p")"
    case "$t" in "$SKILLS_DIR"/*) return 0 ;; esac
    return 1
  fi
  [ -d "$p" ] && [ -f "$p/$MARKER" ]
}

# sync <link|copy> [skill-path...]  — make every target contain exactly these skills of ours.
sync() {
  local mode="$1"; shift
  local wanted=("$@")
  local target parent existing w dest n_targets=0

  for target in $TARGETS; do
    parent="$(dirname "$target")"
    if [ ! -d "$parent" ]; then
      echo "skip  $target  (tool not installed)"
      continue
    fi
    mkdir -p "$target"
    n_targets=$((n_targets + 1))

    # Remove every entry we created. Wanted ones are recreated below: cheap, and it fixes
    # a link whose repo path moved or a copy that is out of date.
    for existing in "$target"/* "$target"/.[!.]*; do
      { [ -e "$existing" ] || [ -L "$existing" ]; } || continue
      is_ours "$existing" || continue
      rm -rf "$existing"
    done

    for w in ${wanted[@]+"${wanted[@]}"}; do
      dest="$target/$(basename "$w")"
      if [ -e "$dest" ] || [ -L "$dest" ]; then
        warn "$dest already exists and was not created by this script; left alone"
        continue
      fi
      if [ "$mode" = copy ]; then
        cp -R "$w" "$dest"
        : > "$dest/$MARKER"
      else
        ln -s "$w" "$dest"
      fi
    done
    echo "ok    $target"
  done

  [ "$n_targets" -gt 0 ] || warn "no AI tool folders found under \$HOME; nothing installed"
}

# ---------------------------------------------------------------------------------------

mode=link action=sync teams=()
while [ $# -gt 0 ]; do
  case "$1" in
    --copy)      mode=copy ;;
    --list)      action=list ;;
    --uninstall) action=uninstall ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "unknown option $1 (try --help)" ;;
    *)           teams+=("$1") ;;
  esac
  shift
done

case "$action" in
  list)
    installed=""
    [ -f "$TEAMS_FILE" ] && installed="$(grep -v '^#' "$TEAMS_FILE" | tr '\n' ' ')"
    for t in $(list_teams); do
      mark=""
      case " $installed " in *" $t "*) mark="   (installed)" ;; esac
      echo "$t$mark"
      team_skills "$t" | sed 's|.*/|    |'
    done
    exit 0
    ;;

  uninstall)
    sync link
    rm -f "$TEAMS_FILE"
    echo "Removed every skill this script had installed."
    exit 0
    ;;
esac

# sync: decide which teams, save the choice, then link.
if [ ${#teams[@]} -gt 0 ]; then
  for t in "${teams[@]}"; do
    [ -d "$SKILLS_DIR/$t" ] || die "no team folder team-skills/$t — run with --list to see teams"
  done
  mkdir -p "$(dirname "$TEAMS_FILE")"
  {
    echo "# Teams whose skills are installed on this machine. Edit, then run team-skills/install.sh."
    [ "$mode" = copy ] && echo "# mode: copy"
    printf '%s\n' "${teams[@]}"
  } > "$TEAMS_FILE"
elif [ -f "$TEAMS_FILE" ]; then
  grep -q '^# mode: copy' "$TEAMS_FILE" && mode=copy
  teams=()
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    teams+=("$line")
  done < "$TEAMS_FILE"
else
  echo "Which team's skills do you want? Available teams:"
  list_teams | sed 's/^/  /'
  echo
  echo "Run:  team-skills/install.sh <team> [<team>...]"
  exit 1
fi

wanted=()
for t in ${teams[@]+"${teams[@]}"}; do
  while IFS= read -r s; do
    [ -n "$s" ] && wanted+=("$s")
  done < <(team_skills "$t")
done

sync "$mode" ${wanted[@]+"${wanted[@]}"}
echo
echo "Installed ${#wanted[@]} skill(s) for: ${teams[*]+${teams[*]}}  (saved in local/my-teams)"
echo "Start a new session in your AI tool to see them."
