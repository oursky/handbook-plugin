#!/bin/sh
# Sync Oursky handbook repo into a local cache at SessionStart.
# Never exits non-zero — a sync failure must not break sessions.

CACHE_DIR="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"
REPO_URL="${HANDBOOK_REPO_URL:-git@github.com:oursky/handbook-dev.git}"

# Wrap git in a timeout if the command exists.
if command -v timeout >/dev/null 2>&1; then
    run() { timeout 20 "$@"; }
else
    run() { "$@"; }
fi

fail() {
    reason="$1"
    if [ -d "$CACHE_DIR/.git" ]; then
        printf 'handbook: sync failed (%s); using cached copy at %s\n' "$reason" "$CACHE_DIR" >&2
    else
        printf 'handbook: sync failed (%s); no cached copy\n' "$reason" >&2
    fi
    exit 0
}

if [ ! -d "$CACHE_DIR/.git" ]; then
    if [ -d "$CACHE_DIR" ]; then
        printf 'handbook: %s exists and is not a git checkout; refusing to touch it\n' "$CACHE_DIR" >&2
        exit 0
    fi
    TMPCLONE="${CACHE_DIR}.tmp.$$"
    run git clone --depth 1 --quiet "$REPO_URL" "$TMPCLONE" 2>/dev/null \
        || { rm -rf "$TMPCLONE"; fail "clone failed"; }
    mv "$TMPCLONE" "$CACHE_DIR" 2>/dev/null || { rm -rf "$TMPCLONE"; fail "mv failed"; }
else
    git -C "$CACHE_DIR" remote set-url origin "$REPO_URL" 2>/dev/null
    run git -C "$CACHE_DIR" pull --ff-only --quiet 2>/dev/null \
        || fail "pull failed"
fi

sha=$(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Oursky handbook synced at %s (%s). Topic skills route into it."}}\n' \
    "$CACHE_DIR" "$sha"
