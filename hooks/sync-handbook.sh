#!/bin/sh
# Sync all declared Oursky handbooks into a local cache at SessionStart.
# Reads handbooks.json from ${CLAUDE_PLUGIN_ROOT}; adding a new entry there
# requires no edit to this script (AC-1).
# Never exits non-zero — a sync failure must not break sessions.

CACHE_ROOT="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HANDBOOKS_JSON="${PLUGIN_ROOT}/handbooks.json"

# Wrap git in a timeout if the command exists.
if command -v timeout >/dev/null 2>&1; then
    run() { timeout 20 "$@"; }
else
    run() { "$@"; }
fi

# Clone into $2. A handbook that ships team skills is mostly image archives, so
# it is fetched blobless and sparse (files/ at any depth, but never inside
# team-skills); the others stay plain shallow clones.
clone_handbook() {
    if [ "$3" = "-" ]; then
        run git clone --depth 1 --quiet "$1" "$2" 2>/dev/null
        return
    fi
    run git clone --depth 1 --filter=blob:none --no-checkout --quiet "$1" "$2" 2>/dev/null \
        && run git -C "$2" sparse-checkout set --no-cone '/*' '!/archive/' '!files/' '/team-skills/' 2>/dev/null \
        && run git -C "$2" checkout --quiet 2>/dev/null
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
        printf 'team skills:%s (%s linked)%s' "$have" "${n:-?}" "$note"
    else
        rc=$?
        printf 'team skills: WARNING install.sh exited %s: %s%s' "$rc" \
            "$(printf '%s' "$out" | tail -n 1)" "$note"
    fi
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

# Accumulate per-handbook status lines in a temp file so we can build the
# additionalContext string after the pipe subshell finishes.
STATUS_FILE="$(mktemp)"
trap 'rm -f "$STATUS_FILE"' EXIT

# AC-2: iterate over every declared handbook.
# One failing handbook warns, keeps its stale cache, and does not abort the loop.
# team_skills is last and "-" when absent: tab is whitespace to read, so an
# empty middle field would collapse.
jq -r '.handbooks[] | "\(.id)\t\(.url)\t\(.label)\t\(.team_skills // "-")"' "$HANDBOOKS_JSON" | \
while IFS="$(printf '\t')" read -r id url label team_skills; do
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
        git -C "$TARGET" remote set-url origin "$url" 2>/dev/null
        if run git -C "$TARGET" pull --ff-only --quiet 2>/dev/null; then
            sha=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
        else
            printf 'handbook[%s]: pull failed; using stale cache\n' "$id" >&2
            sha=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || printf 'stale')
        fi
    fi

    printf '%s (%s) at %s [%s]\n' "$label" "$id" "$TARGET" "$sha" >> "$STATUS_FILE"

    if [ "$team_skills" != "-" ] && [ "$sha" != "no-cache" ]; then
        frag=$(install_team_skills "$TARGET" "$team_skills")
        printf '%s\n' "$frag" >> "$STATUS_FILE"
        case "$frag" in *WARNING*) printf 'handbook[%s]: %s\n' "$id" "$frag" >&2 ;; esac
    fi
done

# Build the additionalContext string from accumulated status lines.
context=$(tr '\n' '; ' < "$STATUS_FILE" | sed 's/; $//')
if [ -z "$context" ]; then
    context="No handbooks declared in ${HANDBOOKS_JSON}"
fi

jq -cn --arg ctx "$context" \
    '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
