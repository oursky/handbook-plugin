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
jq -r '.handbooks[] | "\(.id)\t\(.url)\t\(.label)"' "$HANDBOOKS_JSON" | \
while IFS="$(printf '\t')" read -r id url label; do
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
            if run git clone --depth 1 --quiet "$url" "$TMPCLONE" 2>/dev/null; then
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
done

# Build the additionalContext string from accumulated status lines.
context=$(tr '\n' '; ' < "$STATUS_FILE" | sed 's/; $//')
if [ -z "$context" ]; then
    context="No handbooks declared in ${HANDBOOKS_JSON}"
fi

jq -cn --arg ctx "$context" \
    '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
