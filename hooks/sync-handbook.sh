#!/bin/sh
# Sync all declared Oursky handbooks into a local cache at SessionStart.
# Reads handbooks.json from ${CLAUDE_PLUGIN_ROOT}; adding a new entry there
# requires no edit to this script (AC-1).
# Never exits non-zero — a sync failure must not break sessions.
#
# A session never waits on the network for a checkout it already has. A checkout
# synced within HANDBOOK_REFRESH_MINUTES (default 10) is served as is. An older
# one is served as is too, and pulled in a detached background job under a lock,
# so the next session sees the update. Only a missing checkout clones in the
# foreground. HANDBOOK_SYNC_FOREGROUND=1 pulls every checkout and waits.

CACHE_ROOT="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HANDBOOKS_JSON="${PLUGIN_ROOT}/handbooks.json"
REFRESH_MINUTES="${HANDBOOK_REFRESH_MINUTES:-10}"
case "$REFRESH_MINUTES" in ''|*[!0-9]*) REFRESH_MINUTES=10 ;; esac

# Wrap git in a timeout if the command exists.
if command -v timeout >/dev/null 2>&1; then
    run() { timeout 20 "$@"; }
else
    run() { "$@"; }
fi

GIT_TERMINAL_PROMPT=0; export GIT_TERMINAL_PROMPT

repo_path() {
    printf '%s' "$1" | sed -e 's#^https://github.com/##' -e 's#^git@github.com:##' -e 's#\.git$##' -e 's#/$##'
}

ssh_url() { printf 'git@github.com:%s.git' "$(repo_path "$1")"; }

# Clone into $2. A handbook that ships team skills is mostly image archives, so
# it is fetched blobless and sparse (files/ at any depth, but never inside
# team-skills); the others stay plain shallow clones.
clone_once() {
    if [ "$3" = "-" ]; then
        run git clone --depth 1 --quiet "$1" "$2" 2>/dev/null
        return
    fi
    run git clone --depth 1 --filter=blob:none --no-checkout --quiet "$1" "$2" 2>/dev/null \
        && run git -C "$2" sparse-checkout set --no-cone '/*' '!/archive/' '!files/' '/team-skills/' 2>/dev/null \
        && run git -C "$2" checkout --quiet 2>/dev/null
}

clone_handbook() {
    clone_once "$1" "$2" "$3" && return 0
    rm -rf "$2"
    case "$1" in https://github.com/*) clone_once "$(ssh_url "$1")" "$2" "$3" ;; *) return 1 ;; esac
}

# Link the teams' skills with the handbook's own installer; echoes one status
# fragment. A failure becomes a warning in the fragment, never a hook failure.
install_team_skills() {
    dir="$1/$2"
    installer="$dir/install.sh"
    teams="${OURSKY_TEAMS:-engineering}"
    if [ ! -x "$installer" ]; then
        printf 'team skills: WARNING %s not found in checkout' "$installer"
        return
    fi
    have="" missing=""
    for t in $teams; do
        if [ -d "$dir/$t" ]; then have="$have $t"; else missing="$missing $t"; fi
    done
    note=""
    [ -n "$missing" ] && note=" (WARNING no team folder:${missing})"
    if [ -z "$have" ]; then
        printf 'team skills: WARNING nothing to install%s' "$note"
        return
    fi
    # shellcheck disable=SC2086
    if out=$(run "$installer" $have 2>&1); then
        n=$(printf '%s\n' "$out" | sed -n 's/^Installed \([0-9]*\) skill.*/\1/p')
        w=$(printf '%s\n' "$out" | grep -c '^warning:')
        [ "$w" -gt 0 ] && note="$note (WARNING installer: $w warning(s))"
        # The function runs in a subshell, so signal the reload through a file.
        [ "${n:-0}" -gt 0 ] && printf 1 > "$RELOAD_FILE"
        printf 'team skills:%s (%s linked)%s' "$have" "${n:-?}" "$note"
    else
        rc=$?
        printf 'team skills: WARNING install.sh exited %s: %s%s' "$rc" \
            "$(printf '%s' "$out" | tail -n 1)" "$note"
    fi
}

# A checkout is fresh when its stamp, touched after each successful sync, is
# younger than REFRESH_MINUTES. A missing stamp counts as stale.
is_fresh() {
    [ -n "$(find "$1/.git/handbook-synced" -mmin "-$REFRESH_MINUTES" 2>/dev/null)" ]
}

# Take the per-checkout lock; the lock is released when the job ends. With flock
# the kernel drops it on any exit, so it can never go stale. Without flock a
# mkdir lock older than two minutes (hook timeout is 20 s) is broken.
take_lock() {
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$1/.git/handbook-sync.lock" && flock -n 9
        return
    fi
    lock="$1/.git/handbook-sync.lock.d"
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
        rmdir "$lock" 2>/dev/null
    fi
    mkdir "$lock" 2>/dev/null && trap 'rmdir "$lock" 2>/dev/null' EXIT
}

# pull_checkout <target> <team_skills> <relink>
# Fast-forward one checkout under its lock. Returns 0 on success, 1 on a failed
# pull, 2 when another job holds the lock. With relink=1 a moved HEAD relinks
# the team skills, for the detached job that nobody is waiting on.
pull_checkout() {
    take_lock "$1" || return 2
    before=$(git -C "$1" rev-parse HEAD 2>/dev/null)
    run git -C "$1" pull --ff-only --quiet 2>/dev/null || return 1
    touch "$1/.git/handbook-synced" 2>/dev/null
    if [ "$3" = 1 ] && [ "$2" != "-" ] && [ "$before" != "$(git -C "$1" rev-parse HEAD 2>/dev/null)" ]; then
        RELOAD_FILE=/dev/null install_team_skills "$1" "$2" >/dev/null
    fi
    return 0
}

# jq is required to parse handbooks.json.
if ! command -v jq >/dev/null 2>&1; then
    printf 'handbook: jq is required but not installed; sync skipped\n' >&2
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"handbook sync skipped: jq not available"}}\n'
    exit 0
fi

if [ ! -f "$HANDBOOKS_JSON" ]; then
    printf 'handbook: %s not found; sync skipped\n' "$HANDBOOKS_JSON" >&2
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"handbook sync skipped: handbooks.json not found"}}\n'
    exit 0
fi

# AC-3: detect legacy v0.1.0 flat checkout at the cache root — warn exactly
# once and never delete or rewrite it; per-handbook caches go in subdirs.
if [ -d "${CACHE_ROOT}/.git" ]; then
    printf 'handbook: legacy v0.1.0 checkout detected at %s; it will not be modified — per-handbook caches now go in subdirectories\n' \
        "$CACHE_ROOT" >&2
fi

# Each handbook is handled in its own background subshell and writes to its own
# fragment file, so a first-run clone of all repos takes as long as the largest.
STATUS_FILE="$(mktemp)"
RELOAD_FILE="$(mktemp)"
LIST_FILE="$(mktemp)"
trap 'rm -f "$STATUS_FILE" "$STATUS_FILE".* "$RELOAD_FILE" "$LIST_FILE"' EXIT

# sync_one <id> <url> <label> <team_skills> <out-file>
# One failing handbook warns and keeps its stale cache; the others carry on.
sync_one() {
    id="$1" url="$2" label="$3" team_skills="$4" out="$5"
    TARGET="${CACHE_ROOT}/${id}"

    if [ ! -d "${TARGET}/.git" ]; then
        if [ -d "$TARGET" ]; then
            # Subdir exists but is not a git checkout — refuse to touch it.
            printf 'handbook[%s]: %s exists and is not a git checkout; refusing to touch it\n' \
                "$id" "$TARGET" >&2
            sha="no-cache"
        else
            # Fresh clone via atomic tmp-then-mv.
            # rm -rf targets only the temp path, never the cache dir.
            TMPCLONE="${TARGET}.tmp.$$"
            if clone_handbook "$url" "$TMPCLONE" "$team_skills"; then
                if mv "$TMPCLONE" "$TARGET" 2>/dev/null; then
                    touch "$TARGET/.git/handbook-synced" 2>/dev/null
                    sha=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
                else
                    rm -rf "$TMPCLONE"
                    printf 'handbook[%s]: mv failed; no local cache\n' "$id" >&2
                    sha="no-cache"
                fi
            else
                rm -rf "$TMPCLONE"
                printf 'handbook[%s]: clone failed; no local cache\n' "$id" >&2
                sha="no-cache"
            fi
        fi
    else
        # Pull existing checkout.
        have_url=$(git -C "$TARGET" remote get-url origin 2>/dev/null)
        [ "$(repo_path "$have_url")" = "$(repo_path "$url")" ] \
            || git -C "$TARGET" remote set-url origin "$url" 2>/dev/null
        if [ "${HANDBOOK_SYNC_FOREGROUND:-0}" = 1 ]; then
            pull_checkout "$TARGET" "$team_skills" 0
            case $? in
                1) printf 'handbook[%s]: pull failed; using stale cache\n' "$id" >&2 ;;
            esac
        elif ! is_fresh "$TARGET"; then
            # Detached: closed fds so the hook's pipe closes, HUP ignored so the
            # job outlives the session that started it.
            ( trap '' HUP; pull_checkout "$TARGET" "$team_skills" 1 ) </dev/null >/dev/null 2>&1 &
        fi
        sha=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
    fi

    printf '%s (%s) at %s [%s]\n' "$label" "$id" "$TARGET" "$sha" >> "$out"

    if [ "$team_skills" != "-" ] && [ "$sha" != "no-cache" ]; then
        frag=$(install_team_skills "$TARGET" "$team_skills")
        printf '%s\n' "$frag" >> "$out"
        case "$frag" in *WARNING*) printf 'handbook[%s]: %s\n' "$id" "$frag" >&2 ;; esac
    fi
}

# team_skills is last and "-" when absent: tab is whitespace to read, so an
# empty middle field would collapse.
jq -r '.handbooks[] | "\(.id)\t\(.url)\t\(.label)\t\(.team_skills // "-")"' "$HANDBOOKS_JSON" > "$LIST_FILE"
count=0
while IFS="$(printf '\t')" read -r id url label team_skills; do
    count=$((count + 1))
    ( sync_one "$id" "$url" "$label" "$team_skills" "$STATUS_FILE.$count" ) &
done < "$LIST_FILE"
wait

# Join the fragments in handbooks.json order.
i=1
while [ "$i" -le "$count" ]; do
    [ -f "$STATUS_FILE.$i" ] && cat "$STATUS_FILE.$i" >> "$STATUS_FILE"
    i=$((i + 1))
done

# Build the additionalContext string from accumulated status lines.
context=$(tr '\n' '; ' < "$STATUS_FILE" | sed 's/; $//')
if [ -z "$context" ]; then
    context="No handbooks declared in ${HANDBOOKS_JSON}"
fi

# Skills linked during this run are missing from the startup skill list;
# reloadSkills makes Claude Code rescan them once the hooks finish.
reload=false
[ -s "$RELOAD_FILE" ] && reload=true

jq -cn --arg ctx "$context" --argjson reload "$reload" \
    '{"hookSpecificOutput": ({"hookEventName":"SessionStart","additionalContext":$ctx}
        + (if $reload then {"reloadSkills":true} else {} end))}'
