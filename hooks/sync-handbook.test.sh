#!/bin/sh
# Self-contained tests for sync-handbook.sh. No network required.
# Creates local bare repos and temp dirs; cleans up on exit.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-handbook.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# ── Helper: write handbooks.json with N triples of (id url label) ─────────────
# Usage: write_handbooks_json <plugin_root> id url label [id url label ...]
write_handbooks_json() {
    plugin_root="$1"; shift
    entries=""
    while [ $# -ge 3 ]; do
        id="$1"; url="$2"; label="$3"; shift 3
        entry="$(printf '{"id":"%s","url":"%s","topic_root":"guides/","depth":1,"label":"%s"}' \
            "$id" "$url" "$label")"
        if [ -z "$entries" ]; then
            entries="$entry"
        else
            entries="${entries},${entry}"
        fi
    done
    printf '{"handbooks":[%s]}\n' "$entries" > "${plugin_root}/handbooks.json"
}

# ── Helper: initialise a local bare repo with one commit ──────────────────────
_work_serial=0
make_bare_repo() {
    dest="$1"
    git init --bare "$dest" >/dev/null 2>&1
    _work_serial=$((_work_serial + 1))
    WORK="$TMPDIR_BASE/_work${_work_serial}"
    git clone "$dest" "$WORK" >/dev/null 2>&1
    printf '# Handbook\nHello.\n' > "$WORK/README.md"
    git -C "$WORK" add README.md >/dev/null 2>&1
    git -C "$WORK" -c user.email="t@t" -c user.name="t" commit -m "init" >/dev/null 2>&1
    git -C "$WORK" push origin HEAD:main >/dev/null 2>&1
    git -C "$dest" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1
    rm -rf "$WORK"
}

# ── Set up two bare repos ─────────────────────────────────────────────────────
BARE_REPO="$TMPDIR_BASE/bare.git"
BARE_REPO2="$TMPDIR_BASE/bare2.git"
make_bare_repo "$BARE_REPO"
make_bare_repo "$BARE_REPO2"

# ── Shared plugin root for single-handbook cases ──────────────────────────────
PLUGIN_SINGLE="$TMPDIR_BASE/plugin_single"
mkdir -p "$PLUGIN_SINGLE"
write_handbooks_json "$PLUGIN_SINGLE" dev "$BARE_REPO" "Engineering handbook"

# ── Case (a): first run clones ────────────────────────────────────────────────
CACHE_A="$TMPDIR_BASE/cache_a"
OUT=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_SINGLE" HANDBOOK_CACHE_DIR="$CACHE_A" sh "$SCRIPT" 2>/dev/null)
if [ -f "${CACHE_A}/dev/README.md" ] && printf '%s' "$OUT" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case a: first run clones, file exists, JSON emitted"
else
    fail "case a: first run clone or JSON output wrong (out='$OUT', file=$(ls "${CACHE_A}/dev/README.md" 2>/dev/null || echo missing))"
fi

# ── Case (b): second run after new commit fast-forwards ───────────────────────
_work_serial=$((_work_serial + 1))
WORK_B="$TMPDIR_BASE/_work${_work_serial}"
git clone "$BARE_REPO" "$WORK_B" >/dev/null 2>&1
printf '# Update\nMore content.\n' > "$WORK_B/EXTRA.md"
git -C "$WORK_B" add EXTRA.md >/dev/null 2>&1
git -C "$WORK_B" -c user.email="t@t" -c user.name="t" commit -m "add extra" >/dev/null 2>&1
git -C "$WORK_B" push origin HEAD:main >/dev/null 2>&1
rm -rf "$WORK_B"

OUT2=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_SINGLE" HANDBOOK_CACHE_DIR="$CACHE_A" sh "$SCRIPT" 2>/dev/null)
if [ -f "${CACHE_A}/dev/EXTRA.md" ] && printf '%s' "$OUT2" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case b: second run fast-forwards, new file present"
else
    fail "case b: fast-forward failed (extra=$(ls "${CACHE_A}/dev/EXTRA.md" 2>/dev/null || echo missing), out='$OUT2')"
fi

# ── Case (c): bad URL exits 0, warns, stale cache intact ─────────────────────
PLUGIN_C="$TMPDIR_BASE/plugin_c"
mkdir -p "$PLUGIN_C"
write_handbooks_json "$PLUGIN_C" dev "/nonexistent/path/does/not/exist.git" "Engineering handbook"
ERR_C=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_C" HANDBOOK_CACHE_DIR="$CACHE_A" sh "$SCRIPT" 2>&1 >/dev/null)
RC_C=$?
if [ $RC_C -eq 0 ] && printf '%s' "$ERR_C" | grep -qi 'failed' && [ -f "${CACHE_A}/dev/README.md" ]; then
    pass "case c: bad URL exits 0, warning to stderr, stale cache intact"
else
    fail "case c: exit=$RC_C, stderr='$ERR_C', readme=$(ls "${CACHE_A}/dev/README.md" 2>/dev/null || echo missing)"
fi

# ── Case (d): pre-existing non-git id-subdir + bad URL exits 0, sentinel intact
CACHE_D="$TMPDIR_BASE/cache_d"
mkdir -p "${CACHE_D}/dev"
printf 'sentinel' > "${CACHE_D}/dev/sentinel.txt"
PLUGIN_D="$TMPDIR_BASE/plugin_d"
mkdir -p "$PLUGIN_D"
write_handbooks_json "$PLUGIN_D" dev "/nonexistent/path.git" "Engineering handbook"
RC_D=0
CLAUDE_PLUGIN_ROOT="$PLUGIN_D" HANDBOOK_CACHE_DIR="$CACHE_D" sh "$SCRIPT" >/dev/null 2>/dev/null \
    || RC_D=$?
if [ $RC_D -eq 0 ] && [ "$(cat "${CACHE_D}/dev/sentinel.txt")" = "sentinel" ]; then
    pass "case d: pre-existing non-git id-subdir, bad URL exits 0, sentinel intact"
else
    fail "case d: exit=$RC_D, sentinel=$(cat "${CACHE_D}/dev/sentinel.txt" 2>/dev/null || echo missing)"
fi

# ── Case (e): pre-existing non-git id-subdir + valid URL — sentinel intact, warning printed
CACHE_E="$TMPDIR_BASE/cache_e"
mkdir -p "${CACHE_E}/dev"
printf 'sentinel' > "${CACHE_E}/dev/sentinel.txt"
PLUGIN_E="$TMPDIR_BASE/plugin_e"
mkdir -p "$PLUGIN_E"
write_handbooks_json "$PLUGIN_E" dev "$BARE_REPO" "Engineering handbook"
RC_E=0
WARN_E=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_E" HANDBOOK_CACHE_DIR="$CACHE_E" sh "$SCRIPT" 2>&1 >/dev/null) \
    || RC_E=$?
if [ $RC_E -eq 0 ] \
   && [ "$(cat "${CACHE_E}/dev/sentinel.txt")" = "sentinel" ] \
   && printf '%s' "$WARN_E" | grep -q 'refusing to touch it'; then
    pass "case e: pre-existing non-git id-subdir, valid URL exits 0, sentinel intact, warning printed"
else
    fail "case e: exit=$RC_E, sentinel=$(cat "${CACHE_E}/dev/sentinel.txt" 2>/dev/null || echo missing), warn='$WARN_E'"
fi

# ── Case (f): multi-handbook clone — two entries, both fresh ─────────────────
CACHE_F="$TMPDIR_BASE/cache_f"
PLUGIN_F="$TMPDIR_BASE/plugin_f"
mkdir -p "$PLUGIN_F"
write_handbooks_json "$PLUGIN_F" \
    dev "$BARE_REPO"  "Engineering handbook" \
    pm  "$BARE_REPO2" "PM workflow handbook"
OUT_F=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_F" HANDBOOK_CACHE_DIR="$CACHE_F" sh "$SCRIPT" 2>/dev/null)
if [ -f "${CACHE_F}/dev/README.md" ] \
   && [ -f "${CACHE_F}/pm/README.md" ] \
   && printf '%s' "$OUT_F" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case f: multi-handbook clone — both dev and pm cloned, JSON emitted"
else
    fail "case f: dev=$(ls "${CACHE_F}/dev/README.md" 2>/dev/null || echo missing), pm=$(ls "${CACHE_F}/pm/README.md" 2>/dev/null || echo missing), out='$OUT_F'"
fi

# ── Case (g): multi-handbook ff-pull — both already cloned, pm updated ────────
_work_serial=$((_work_serial + 1))
WORK_G="$TMPDIR_BASE/_work${_work_serial}"
git clone "$BARE_REPO2" "$WORK_G" >/dev/null 2>&1
printf '# PM Update\n' > "$WORK_G/PM_EXTRA.md"
git -C "$WORK_G" add PM_EXTRA.md >/dev/null 2>&1
git -C "$WORK_G" -c user.email="t@t" -c user.name="t" commit -m "add pm extra" >/dev/null 2>&1
git -C "$WORK_G" push origin HEAD:main >/dev/null 2>&1
rm -rf "$WORK_G"

OUT_G=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_F" HANDBOOK_CACHE_DIR="$CACHE_F" sh "$SCRIPT" 2>/dev/null)
if [ -f "${CACHE_F}/pm/PM_EXTRA.md" ] && printf '%s' "$OUT_G" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case g: multi-handbook ff-pull — pm updated, new file present"
else
    fail "case g: pm_extra=$(ls "${CACHE_F}/pm/PM_EXTRA.md" 2>/dev/null || echo missing), out='$OUT_G'"
fi

# ── Case (h): partial failure — one bad URL (has stale cache), one good URL ───
# Assert: good handbook synced AND bad handbook's stale cache survives intact.
CACHE_H="$TMPDIR_BASE/cache_h"
# Pre-seed dev with a stale checkout so there is something to preserve.
git clone "$BARE_REPO" "${CACHE_H}/dev" >/dev/null 2>&1
PLUGIN_H="$TMPDIR_BASE/plugin_h"
mkdir -p "$PLUGIN_H"
write_handbooks_json "$PLUGIN_H" \
    dev "/nonexistent/broken.git" "Engineering handbook" \
    pm  "$BARE_REPO2"            "PM workflow handbook"
ERR_H=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_H" HANDBOOK_CACHE_DIR="$CACHE_H" sh "$SCRIPT" 2>&1 >/dev/null)
RC_H=$?
if [ $RC_H -eq 0 ] \
   && [ -f "${CACHE_H}/pm/README.md" ] \
   && [ -d "${CACHE_H}/dev/.git" ] \
   && printf '%s' "$ERR_H" | grep -q 'dev'; then
    pass "case h: partial failure — pm synced, dev stale cache survived, warning emitted for dev"
else
    fail "case h: exit=$RC_H, pm=$(ls "${CACHE_H}/pm/README.md" 2>/dev/null || echo missing), dev_git=$(ls -d "${CACHE_H}/dev/.git" 2>/dev/null || echo missing), err='$ERR_H'"
fi

# ── Case (i): legacy flat-checkout warning — exactly one warning, checkout intact
CACHE_I="$TMPDIR_BASE/cache_i"
git clone "$BARE_REPO" "$CACHE_I" >/dev/null 2>&1   # v0.1.0-style flat checkout at cache root
PLUGIN_I="$TMPDIR_BASE/plugin_i"
mkdir -p "$PLUGIN_I"
write_handbooks_json "$PLUGIN_I" dev "$BARE_REPO" "Engineering handbook"
WARN_I=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_I" HANDBOOK_CACHE_DIR="$CACHE_I" sh "$SCRIPT" 2>&1 >/dev/null)
WARN_COUNT=$(printf '%s' "$WARN_I" | grep -c 'legacy v0.1.0' || true)
if [ -d "${CACHE_I}/.git" ] \
   && [ -f "${CACHE_I}/README.md" ] \
   && [ "$WARN_COUNT" -eq 1 ]; then
    pass "case i: legacy flat-checkout — exactly one warning, checkout still intact"
else
    fail "case i: warn_count=$WARN_COUNT (want 1), git=$(ls -d "${CACHE_I}/.git" 2>/dev/null || echo missing), readme=$(ls "${CACHE_I}/README.md" 2>/dev/null || echo missing), warn='$WARN_I'"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
