#!/bin/sh
# Manual sync + status for all declared Oursky handbooks.
# Usage: handbook-sync-status.sh [--regen]
#
# Captures per-handbook SHA before calling hooks/sync-handbook.sh (reused as-is),
# then compares to the post-sync SHA so the user can see which handbooks moved.
# With --regen, also runs skills/handbook-authoring/generate.sh afterwards.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CACHE_ROOT="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"
HANDBOOKS_JSON="${PLUGIN_ROOT}/handbooks.json"

REGEN=0
if [ "${1:-}" = "--regen" ]; then REGEN=1; fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'handbook-sync: jq is required\n' >&2; exit 1
fi

if [ ! -f "$HANDBOOKS_JSON" ]; then
    printf 'handbook-sync: %s not found\n' "$HANDBOOKS_JSON" >&2; exit 1
fi

# ── Temp dir for per-handbook before-SHAs ─────────────────────────────────────
TMPDIR_S="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_S"' EXIT

# ── Capture SHA before sync ───────────────────────────────────────────────────
jq -r '.handbooks[].id' "$HANDBOOKS_JSON" | while IFS= read -r id; do
    target="${CACHE_ROOT}/${id}"
    if [ -d "${target}/.git" ]; then
        git -C "$target" rev-parse --short HEAD 2>/dev/null \
            > "${TMPDIR_S}/${id}.before" \
            || printf 'unknown' > "${TMPDIR_S}/${id}.before"
    else
        printf 'none' > "${TMPDIR_S}/${id}.before"
    fi
done

# ── Run sync (reuse hook as-is; suppress its JSON output) ────────────────────
printf 'Syncing handbooks...\n'
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" HANDBOOK_CACHE_DIR="$CACHE_ROOT" \
    sh "${PLUGIN_ROOT}/hooks/sync-handbook.sh" >/dev/null

# ── Print status table ────────────────────────────────────────────────────────
printf '\n'
printf '%-12s  %-34s  %-8s  %-10s  %s\n' \
    "ID" "LABEL" "SHA" "DATE" "STATUS"
printf -- '%.0s-' 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 \
         1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 \
         1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 \
         1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8
printf '\n'

jq -r '.handbooks[] | "\(.id)\t\(.label)"' "$HANDBOOKS_JSON" | \
while IFS="$(printf '\t')" read -r id label; do
    target="${CACHE_ROOT}/${id}"

    before_sha=""
    if [ -f "${TMPDIR_S}/${id}.before" ]; then
        before_sha="$(cat "${TMPDIR_S}/${id}.before")"
    fi

    if [ -d "${target}/.git" ]; then
        after_sha="$(git -C "$target" rev-parse --short HEAD 2>/dev/null \
            || printf 'unknown')"
        commit_date="$(git -C "$target" log -1 --format='%cs' 2>/dev/null \
            || printf '?')"

        if [ -z "$before_sha" ] || [ "$before_sha" = "none" ]; then
            status="[CLONED]"
        elif [ "$before_sha" != "$after_sha" ]; then
            status="[UPDATED]  was ${before_sha}"
        else
            status="already current"
        fi
    else
        after_sha="-"
        commit_date="-"
        status="[SYNC FAILED]"
    fi

    printf '%-12s  %-34s  %-8s  %-10s  %s\n' \
        "$id" "$label" "$after_sha" "$commit_date" "$status"
done

# ── Optionally regenerate skills ──────────────────────────────────────────────
if [ "$REGEN" = "1" ]; then
    printf '\nRegenerating skills...\n\n'
    HANDBOOK_CACHE_DIR="$CACHE_ROOT" \
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
        bash "${PLUGIN_ROOT}/skills/handbook-authoring/generate.sh"
    printf '\nNote: generate.sh never rewrites an existing description: line.\n'
fi
