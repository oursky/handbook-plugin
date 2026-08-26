#!/bin/sh
# Self-contained tests for sync-handbook.sh. No network required.
# Creates local bare repos and temp dirs; cleans up on exit.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-handbook.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

BARE_REPO="$TMPDIR_BASE/bare.git"
CACHE="$TMPDIR_BASE/cache"
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# ── Set up bare repo with one Markdown file ──────────────────────────────────
git init --bare "$BARE_REPO" >/dev/null 2>&1

WORK="$TMPDIR_BASE/work"
git clone "$BARE_REPO" "$WORK" >/dev/null 2>&1
printf '# Handbook\nHello.\n' > "$WORK/README.md"
git -C "$WORK" add README.md >/dev/null 2>&1
git -C "$WORK" -c user.email="t@t" -c user.name="t" commit -m "init" >/dev/null 2>&1
git -C "$WORK" push origin HEAD:main >/dev/null 2>&1
git -C "$BARE_REPO" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1

# ── Case (a): first run clones ────────────────────────────────────────────────
OUT=$(HANDBOOK_REPO_URL="$BARE_REPO" HANDBOOK_CACHE_DIR="$CACHE" sh "$SCRIPT" 2>/dev/null)
if [ -f "$CACHE/README.md" ] && printf '%s' "$OUT" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case a: first run clones and file exists, JSON emitted"
else
    fail "case a: first run clone or JSON output wrong (out='$OUT', file=$(ls $CACHE/README.md 2>/dev/null || echo missing))"
fi

# ── Case (b): second run after new commit fast-forwards ───────────────────────
printf '# Update\nMore content.\n' > "$WORK/EXTRA.md"
git -C "$WORK" add EXTRA.md >/dev/null 2>&1
git -C "$WORK" -c user.email="t@t" -c user.name="t" commit -m "add extra" >/dev/null 2>&1
git -C "$WORK" push origin HEAD:main >/dev/null 2>&1

OUT2=$(HANDBOOK_REPO_URL="$BARE_REPO" HANDBOOK_CACHE_DIR="$CACHE" sh "$SCRIPT" 2>/dev/null)
if [ -f "$CACHE/EXTRA.md" ] && printf '%s' "$OUT2" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case b: second run fast-forwards and new file present"
else
    fail "case b: fast-forward failed (extra=$(ls $CACHE/EXTRA.md 2>/dev/null || echo missing), out='$OUT2')"
fi

# ── Case (c): bad URL exits 0, prints warning, cache intact ──────────────────
ERR=$(HANDBOOK_REPO_URL="/nonexistent/path/does/not/exist.git" HANDBOOK_CACHE_DIR="$CACHE" sh "$SCRIPT" 2>&1 >/dev/null)
RC=$?
if [ $RC -eq 0 ] && printf '%s' "$ERR" | grep -q 'handbook: sync failed' && [ -f "$CACHE/README.md" ]; then
    pass "case c: bad URL exits 0, warning to stderr, cache intact"
else
    fail "case c: exit=$RC, stderr='$ERR', readme=$(ls $CACHE/README.md 2>/dev/null || echo missing)"
fi

# ── Case (d): pre-existing non-git dir + bad URL exits 0, sentinel intact ────
CACHE_D="$TMPDIR_BASE/cache_d"
mkdir -p "$CACHE_D"
printf 'sentinel' > "$CACHE_D/sentinel.txt"
RC_D=0
HANDBOOK_REPO_URL="/nonexistent/path.git" HANDBOOK_CACHE_DIR="$CACHE_D" sh "$SCRIPT" >/dev/null 2>/dev/null || RC_D=$?
if [ $RC_D -eq 0 ] && [ "$(cat "$CACHE_D/sentinel.txt")" = "sentinel" ]; then
    pass "case d: pre-existing non-git dir, bad URL exits 0, sentinel intact"
else
    fail "case d: exit=$RC_D, sentinel=$(cat "$CACHE_D/sentinel.txt" 2>/dev/null || echo missing)"
fi

# ── Case (e): pre-existing non-git dir + valid URL — sentinel intact, warning ─
CACHE_E="$TMPDIR_BASE/cache_e"
mkdir -p "$CACHE_E"
printf 'sentinel' > "$CACHE_E/sentinel.txt"
RC_E=0
WARN_E=$(HANDBOOK_REPO_URL="$BARE_REPO" HANDBOOK_CACHE_DIR="$CACHE_E" sh "$SCRIPT" 2>&1 >/dev/null) || RC_E=$?
if [ $RC_E -eq 0 ] \
   && [ "$(cat "$CACHE_E/sentinel.txt")" = "sentinel" ] \
   && printf '%s' "$WARN_E" | grep -q 'refusing to touch it'; then
    pass "case e: pre-existing non-git dir, valid URL exits 0, sentinel intact, warning printed"
else
    fail "case e: exit=$RC_E, sentinel=$(cat "$CACHE_E/sentinel.txt" 2>/dev/null || echo missing), warn='$WARN_E'"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
