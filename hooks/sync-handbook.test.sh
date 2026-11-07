#!/bin/sh
# Self-contained tests for sync-handbook.sh. No network required.
# Creates local bare repos and temp dirs; cleans up on exit.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-handbook.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PASS=0
FAIL=0

# Cases a-q exercise the pull itself, so they pull in the foreground. Cases r-u
# unset this to test the default behaviour.
HANDBOOK_SYNC_FOREGROUND=1; export HANDBOOK_SYNC_FOREGROUND

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# ── Helper: write handbooks.json with N triples of (id url label) ─────────────
# Usage: write_handbooks_json <plugin_root> id url label [id url label ...]
write_handbooks_json() {
    plugin_root="$1"; shift
    entries=""
    while [ $# -ge 3 ]; do
        id="$1"; url="$2"; label="$3"; shift 3
        entry="$(printf '{"id":"%s","url":"%s","topic_root":"./","depth":1,"label":"%s"}' \
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

# ── Team-skills cases (j–n) ──────────────────────────────────────────────────
# Fixture mirrors oursky/handbook: team-skills/install.sh plus team folders, and
# archive/ + files/ trees that the sparse clone must leave out. file:// is used
# so --depth/--filter behave as they do over https.
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures"
TS_BARE="$TMPDIR_BASE/handbook.git"
git init --bare "$TS_BARE" >/dev/null 2>&1
git -C "$TS_BARE" config uploadpack.allowFilter true
git -C "$TS_BARE" config uploadpack.allowAnySHA1InWant true
TS_WORK="$TMPDIR_BASE/_ts_work"
git clone "$TS_BARE" "$TS_WORK" >/dev/null 2>&1
mkdir -p "$TS_WORK/team-skills/engineering/engineering-foo" \
         "$TS_WORK/team-skills/marketing/marketing-bar" \
         "$TS_WORK/archive" "$TS_WORK/files"
cp "$FIXTURES/team-skills-install.sh" "$TS_WORK/team-skills/install.sh"
chmod +x "$TS_WORK/team-skills/install.sh"
printf -- '---\nname: engineering-foo\ndescription: foo\n---\n' > "$TS_WORK/team-skills/engineering/engineering-foo/SKILL.md"
printf -- '---\nname: marketing-bar\ndescription: bar\n---\n' > "$TS_WORK/team-skills/marketing/marketing-bar/SKILL.md"
printf 'big' > "$TS_WORK/archive/huge.bin"
printf 'img' > "$TS_WORK/files/pic.png"
printf '# Handbook\n' > "$TS_WORK/README.md"
git -C "$TS_WORK" add -A >/dev/null 2>&1
git -C "$TS_WORK" -c user.email="t@t" -c user.name="t" commit -m init >/dev/null 2>&1
git -C "$TS_WORK" push origin HEAD:main >/dev/null 2>&1
git -C "$TS_BARE" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1
TS_URL="file://$TS_BARE"

PLUGIN_TS="$TMPDIR_BASE/plugin_ts"
mkdir -p "$PLUGIN_TS"
printf '{"handbooks":[{"id":"handbook","url":"%s","team_skills":"team-skills","label":"Company handbook"}]}\n' \
    "$TS_URL" > "$PLUGIN_TS/handbooks.json"

# run_ts <cache> <targets> [env...] — sets OUT_TS, ERR_TS, RC_TS.
run_ts() {
    cache="$1"; targets="$2"; shift 2
    RC_TS=0
    ERR_FILE="$TMPDIR_BASE/ts_err"
    OUT_TS=$(env "$@" CLAUDE_PLUGIN_ROOT="$PLUGIN_TS" HANDBOOK_CACHE_DIR="$cache" \
        OURSKY_SKILL_TARGETS="$targets" sh "$SCRIPT" 2>"$ERR_FILE") || RC_TS=$?
    ERR_TS=$(cat "$ERR_FILE")
}

# ── Case (j): sparse clone, default team linked ──────────────────────────────
CACHE_J="$TMPDIR_BASE/cache_j"; SK_J="$TMPDIR_BASE/home_j/skills"
mkdir -p "$TMPDIR_BASE/home_j"
run_ts "$CACHE_J" "$SK_J" A=1
if [ $RC_TS -eq 0 ] \
   && [ -L "$SK_J/engineering-foo" ] \
   && [ ! -e "$SK_J/marketing-bar" ] \
   && [ ! -e "$CACHE_J/handbook/archive" ] \
   && [ ! -e "$CACHE_J/handbook/files" ] \
   && [ -f "$CACHE_J/handbook/README.md" ] \
   && printf '%s' "$OUT_TS" | grep -q 'team skills: engineering (1 linked)'; then
    pass "case j: sparse clone skips archive/files, default team engineering linked"
else
    fail "case j: rc=$RC_TS link=$(ls "$SK_J" 2>&1) archive=$(ls "$CACHE_J/handbook" 2>&1) out='$OUT_TS' err='$ERR_TS'"
fi

# ── Case (k): second run on an existing sparse cache pulls and re-links ──────
_work_serial=$((_work_serial + 1))
git -C "$TS_WORK" pull -q origin main >/dev/null 2>&1
mkdir -p "$TS_WORK/team-skills/engineering/engineering-new"
printf -- '---\nname: engineering-new\ndescription: new\n---\n' > "$TS_WORK/team-skills/engineering/engineering-new/SKILL.md"
git -C "$TS_WORK" add -A >/dev/null 2>&1
git -C "$TS_WORK" -c user.email="t@t" -c user.name="t" commit -m new >/dev/null 2>&1
git -C "$TS_WORK" push origin HEAD:main >/dev/null 2>&1
run_ts "$CACHE_J" "$SK_J" A=1
if [ $RC_TS -eq 0 ] && [ -L "$SK_J/engineering-new" ] \
   && printf '%s' "$OUT_TS" | grep -q 'engineering (2 linked)'; then
    pass "case k: pull on sparse cache picks up new skill and links it"
else
    fail "case k: rc=$RC_TS link=$(ls "$SK_J" 2>&1) out='$OUT_TS' err='$ERR_TS'"
fi

# ── Case (l): OURSKY_TEAMS selects another team ──────────────────────────────
CACHE_L="$TMPDIR_BASE/cache_l"; SK_L="$TMPDIR_BASE/home_l/skills"
mkdir -p "$TMPDIR_BASE/home_l"
run_ts "$CACHE_L" "$SK_L" OURSKY_TEAMS=marketing
if [ $RC_TS -eq 0 ] && [ -L "$SK_L/marketing-bar" ] && [ ! -e "$SK_L/engineering-foo" ] \
   && printf '%s' "$OUT_TS" | grep -q 'team skills: marketing (1 linked)'; then
    pass "case l: OURSKY_TEAMS=marketing links marketing only"
else
    fail "case l: rc=$RC_TS link=$(ls "$SK_L" 2>&1) out='$OUT_TS' err='$ERR_TS'"
fi

# ── Case (m): missing team folder warns, hook still exits 0 with JSON ────────
CACHE_M="$TMPDIR_BASE/cache_m"; SK_M="$TMPDIR_BASE/home_m/skills"
mkdir -p "$TMPDIR_BASE/home_m"
run_ts "$CACHE_M" "$SK_M" OURSKY_TEAMS=nosuchteam
if [ $RC_TS -eq 0 ] \
   && printf '%s' "$OUT_TS" | grep -q '"hookEventName":"SessionStart"' \
   && printf '%s' "$OUT_TS" | grep -q 'WARNING no team folder: nosuchteam' \
   && [ -z "$(ls "$SK_M" 2>/dev/null)" ]; then
    pass "case m: missing team folder warns in context, exit 0, nothing linked"
else
    fail "case m: rc=$RC_TS out='$OUT_TS' err='$ERR_TS'"
fi

# ── Case (n): installer failure warns, hook still exits 0 with JSON ──────────
# Break the cached installer in place; the pull leaves a dirty-free file alone
# only if unchanged upstream, so replace it after the clone.
CACHE_N="$TMPDIR_BASE/cache_n"; SK_N="$TMPDIR_BASE/home_n/skills"
mkdir -p "$TMPDIR_BASE/home_n"
run_ts "$CACHE_N" "$SK_N" A=1
printf '#!/bin/sh\necho boom >&2\nexit 3\n' > "$CACHE_N/handbook/team-skills/install.sh"
run_ts "$CACHE_N" "$SK_N" A=1
if [ $RC_TS -eq 0 ] \
   && printf '%s' "$OUT_TS" | grep -q '"hookEventName":"SessionStart"' \
   && printf '%s' "$OUT_TS" | grep -q 'WARNING install.sh exited 3: boom' \
   && printf '%s' "$ERR_TS" | grep -q 'WARNING'; then
    pass "case n: installer failure warns in context and stderr, exit 0"
else
    fail "case n: rc=$RC_TS out='$OUT_TS' err='$ERR_TS'"
fi

CACHE_O="$TMPDIR_BASE/cache_o"
mkdir -p "$CACHE_O"
git clone -q "$BARE_REPO" "$CACHE_O/dev" >/dev/null 2>&1
git -C "$CACHE_O/dev" remote set-url origin git@github.com:oursky/handbook-dev.git
PLUGIN_O="$TMPDIR_BASE/plugin_o"; mkdir -p "$PLUGIN_O"
write_handbooks_json "$PLUGIN_O" dev "https://github.com/oursky/handbook-dev.git" "Engineering handbook"
OUT_O=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_O" HANDBOOK_CACHE_DIR="$CACHE_O" sh "$SCRIPT" 2>/dev/null)
URL_O=$(git -C "$CACHE_O/dev" remote get-url origin)
git -C "$CACHE_O/dev" remote set-url origin git@github.com:oursky/other.git
OUT_O2=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_O" HANDBOOK_CACHE_DIR="$CACHE_O" sh "$SCRIPT" 2>/dev/null)
URL_O2=$(git -C "$CACHE_O/dev" remote get-url origin)
if [ "$URL_O" = "git@github.com:oursky/handbook-dev.git" ] \
   && [ "$URL_O2" = "https://github.com/oursky/handbook-dev.git" ] \
   && printf '%s' "$OUT_O$OUT_O2" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case o: same repo keeps SSH remote; a different repo is repointed"
else
    fail "case o: url1='$URL_O' url2='$URL_O2'"
fi

# ── Case (p): reloadSkills is set only when skills were linked ───────────────
run_ts "$TMPDIR_BASE/cache_p1" "$TMPDIR_BASE/home_p1/skills" A=1
mkdir -p "$TMPDIR_BASE/home_p1"
LINKED_P=$(printf '%s' "$OUT_TS" | jq -r '.hookSpecificOutput.reloadSkills')
run_ts "$TMPDIR_BASE/cache_p2" "$TMPDIR_BASE/home_p2/skills" OURSKY_TEAMS=nosuchteam
MISSING_P=$(printf '%s' "$OUT_TS" | jq -r '.hookSpecificOutput | has("reloadSkills")')
OUT_NONE=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_SINGLE" HANDBOOK_CACHE_DIR="$TMPDIR_BASE/cache_p3" sh "$SCRIPT" 2>/dev/null)
NONE_P=$(printf '%s' "$OUT_NONE" | jq -r '.hookSpecificOutput | has("reloadSkills")')
if [ "$LINKED_P" = "true" ] && [ "$MISSING_P" = "false" ] && [ "$NONE_P" = "false" ]; then
    pass "case p: reloadSkills true when skills linked, absent for missing team and no team_skills"
else
    fail "case p: linked='$LINKED_P' missing_team='$MISSING_P' no_team_skills='$NONE_P'"
fi

# ── Case (q): handbooks sync concurrently, context keeps declared order ──────
# The shim delays each clone (first repo 4 s, second 3 s); sequential would take 7 s.
SHIM_Q="$TMPDIR_BASE/shim_q"; mkdir -p "$SHIM_Q"
REAL_GIT=$(command -v git)
cat > "$SHIM_Q/git" <<SHIM
#!/bin/sh
if [ "\$1" = clone ]; then
    case "\$*" in *bare2.git*) sleep 3 ;; *) sleep 4 ;; esac
fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$SHIM_Q/git"
PLUGIN_Q="$TMPDIR_BASE/plugin_q"; mkdir -p "$PLUGIN_Q"
write_handbooks_json "$PLUGIN_Q" \
    slow "$BARE_REPO"  "Slow handbook" \
    fast "$BARE_REPO2" "Fast handbook"
T0=$(date +%s)
OUT_Q=$(PATH="$SHIM_Q:$PATH" CLAUDE_PLUGIN_ROOT="$PLUGIN_Q" HANDBOOK_CACHE_DIR="$TMPDIR_BASE/cache_q" sh "$SCRIPT" 2>/dev/null)
ELAPSED_Q=$(( $(date +%s) - T0 ))
CTX_Q=$(printf '%s' "$OUT_Q" | jq -r '.hookSpecificOutput.additionalContext')
case "$CTX_Q" in "Slow handbook (slow)"*"Fast handbook (fast)"*) ORDER_Q=ok ;; *) ORDER_Q=bad ;; esac
if [ "$ELAPSED_Q" -lt 6 ] && [ "$ORDER_Q" = ok ] \
   && [ -f "$TMPDIR_BASE/cache_q/slow/README.md" ] && [ -f "$TMPDIR_BASE/cache_q/fast/README.md" ]; then
    pass "case q: two delayed clones run concurrently (${ELAPSED_Q}s), context in declared order"
else
    fail "case q: elapsed=${ELAPSED_Q}s (want <6), order=$ORDER_Q, ctx='$CTX_Q'"
fi

# ── Background refresh cases (r–u) ───────────────────────────────────────────
now_ms() { date +%s%3N; }

# wait_for <command...> — poll up to 10 s for the command to succeed.
wait_for() {
    i=0
    while [ $i -lt 100 ]; do
        "$@" && return 0
        sleep 0.1; i=$((i + 1))
    done
    return 1
}

push_file() {
    _work_serial=$((_work_serial + 1))
    W="$TMPDIR_BASE/_work${_work_serial}"
    git clone "$1" "$W" >/dev/null 2>&1
    printf 'x\n' > "$W/$2"
    git -C "$W" add "$2" >/dev/null 2>&1
    git -C "$W" -c user.email="t@t" -c user.name="t" commit -m "add $2" >/dev/null 2>&1
    git -C "$W" push origin HEAD:main >/dev/null 2>&1
    rm -rf "$W"
}

# run_bg <plugin> <cache> [env...] — default mode; sets OUT_BG, RC_BG, MS_BG.
run_bg() {
    plugin="$1"; cache="$2"; shift 2
    T0=$(now_ms); RC_BG=0
    OUT_BG=$(env -u HANDBOOK_SYNC_FOREGROUND "$@" CLAUDE_PLUGIN_ROOT="$plugin" \
        HANDBOOK_CACHE_DIR="$cache" sh "$SCRIPT" 2>/dev/null) || RC_BG=$?
    MS_BG=$(( $(now_ms) - T0 ))
}

BARE_R="$TMPDIR_BASE/bare_r.git"; make_bare_repo "$BARE_R"
PLUGIN_R="$TMPDIR_BASE/plugin_r"; mkdir -p "$PLUGIN_R"
write_handbooks_json "$PLUGIN_R" dev "$BARE_R" "Engineering handbook"
CACHE_R="$TMPDIR_BASE/cache_r"

# ── Case (r): a missing checkout still clones in the foreground ──────────────
run_bg "$PLUGIN_R" "$CACHE_R" A=1
if [ $RC_BG -eq 0 ] && [ -f "$CACHE_R/dev/README.md" ] \
   && [ -f "$CACHE_R/dev/.git/handbook-synced" ] \
   && printf '%s' "$OUT_BG" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case r: missing checkout clones before the hook returns (${MS_BG} ms)"
else
    fail "case r: rc=$RC_BG out='$OUT_BG'"
fi

# ── Case (s): a fresh checkout makes no network call ─────────────────────────
# The remote now points at a path that does not exist, so any fetch would fail
# and warn; a fresh checkout must not even try.
PLUGIN_S="$TMPDIR_BASE/plugin_s"; mkdir -p "$PLUGIN_S"
write_handbooks_json "$PLUGIN_S" dev "/nonexistent/fresh.git" "Engineering handbook"
git -C "$CACHE_R/dev" remote set-url origin "/nonexistent/fresh.git"
touch -d '1 minute ago' "$CACHE_R/dev/.git/handbook-synced"
ERR_S="$TMPDIR_BASE/err_s"
T0=$(now_ms)
OUT_S=$(env -u HANDBOOK_SYNC_FOREGROUND CLAUDE_PLUGIN_ROOT="$PLUGIN_S" HANDBOOK_CACHE_DIR="$CACHE_R" \
    sh "$SCRIPT" 2>"$ERR_S"); RC_S=$?
MS_S=$(( $(now_ms) - T0 ))
sleep 1
if [ $RC_S -eq 0 ] && [ ! -s "$ERR_S" ] && [ "$MS_S" -lt 1500 ] \
   && printf '%s' "$OUT_S" | grep -q 'Engineering handbook (dev)' \
   && [ "$(date -r "$CACHE_R/dev/.git/handbook-synced" +%s)" -lt $(( $(date +%s) - 30 )) ]; then
    pass "case s: checkout fetched 1 minute ago is served with no network call (${MS_S} ms)"
else
    fail "case s: rc=$RC_S ms=$MS_S err='$(cat "$ERR_S")' out='$OUT_S'"
fi

# ── Case (t): a stale checkout returns at once; the pull lands afterwards ────
# A git shim sleeps 3 s inside pull, so a foreground pull could not return fast.
SHIM_T="$TMPDIR_BASE/shim_t"; mkdir -p "$SHIM_T"
cat > "$SHIM_T/git" <<SHIM
#!/bin/sh
case "\$*" in *" pull "*) sleep 3 ;; esac
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$SHIM_T/git"
git -C "$CACHE_R/dev" remote set-url origin "$BARE_R"
push_file "$BARE_R" LATE.md
touch -d '11 minutes ago' "$CACHE_R/dev/.git/handbook-synced"
run_bg "$PLUGIN_R" "$CACHE_R" "PATH=$SHIM_T:$PATH"
LATE_IMMEDIATE=no; [ -f "$CACHE_R/dev/LATE.md" ] && LATE_IMMEDIATE=yes
T1=$(now_ms)
if wait_for test -f "$CACHE_R/dev/LATE.md"; then LANDED=yes; else LANDED=no; fi
LAND_MS=$(( $(now_ms) - T1 ))
if [ $RC_BG -eq 0 ] && [ "$MS_BG" -lt 1500 ] && [ "$LATE_IMMEDIATE" = no ] && [ "$LANDED" = yes ] \
   && printf '%s' "$OUT_BG" | grep -q '"hookEventName":"SessionStart"'; then
    pass "case t: stale checkout returned in ${MS_BG} ms, background pull landed ${LAND_MS} ms later"
else
    fail "case t: rc=$RC_BG ms=$MS_BG immediate=$LATE_IMMEDIATE landed=$LANDED"
fi

# ── Case (u): concurrent runs on a stale checkout leave it intact ────────────
push_file "$BARE_R" LATER.md
wait_for test -f "$CACHE_R/dev/.git/handbook-synced" # settle case t's job
sleep 3.5
touch -d '11 minutes ago' "$CACHE_R/dev/.git/handbook-synced"
PIDS=""
T0=$(now_ms)
for _ in 1 2 3 4; do
    env -u HANDBOOK_SYNC_FOREGROUND PATH="$SHIM_T:$PATH" CLAUDE_PLUGIN_ROOT="$PLUGIN_R" \
        HANDBOOK_CACHE_DIR="$CACHE_R" sh "$SCRIPT" >/dev/null 2>&1 &
    PIDS="$PIDS $!"
done
# shellcheck disable=SC2086
wait $PIDS
MS_U=$(( $(now_ms) - T0 ))
wait_for test -f "$CACHE_R/dev/LATER.md"
sleep 3.5
FSCK_U=ok; git -C "$CACHE_R/dev" fsck --no-progress >/dev/null 2>&1 || FSCK_U=bad
STATUS_U=$(git -C "$CACHE_R/dev" status --porcelain)
LOCKS_U=$(find "$CACHE_R/dev/.git" -name '*.lock' -size +0 2>/dev/null | wc -l)
if [ "$FSCK_U" = ok ] && [ -z "$STATUS_U" ] && [ -f "$CACHE_R/dev/LATER.md" ] && [ "$MS_U" -lt 2500 ] \
   && [ "$(git -C "$CACHE_R/dev" rev-parse HEAD)" = "$(git -C "$BARE_R" rev-parse main)" ]; then
    pass "case u: 4 concurrent runs returned in ${MS_U} ms, checkout intact and up to date"
else
    fail "case u: fsck=$FSCK_U status='$STATUS_U' locks=$LOCKS_U ms=$MS_U"
fi

# ── Case (v): a stale mkdir lock is broken when flock is absent ──────────────
# A PATH without flock forces the mkdir lock; a lock dir 5 minutes old must not
# block the pull forever.
NOFLOCK_V="$TMPDIR_BASE/noflock_v"; mkdir -p "$NOFLOCK_V"
for tool in sh git jq find touch date sleep mktemp rm mv mkdir rmdir cat tr sed grep dirname basename timeout printf env; do
    src=$(command -v "$tool" 2>/dev/null) && [ -x "$src" ] && ln -sf "$src" "$NOFLOCK_V/$tool"
done
push_file "$BARE_R" NOFLOCK.md
mkdir "$CACHE_R/dev/.git/handbook-sync.lock.d"
touch -d '5 minutes ago' "$CACHE_R/dev/.git/handbook-sync.lock.d"
touch -d '11 minutes ago' "$CACHE_R/dev/.git/handbook-synced"
env -u HANDBOOK_SYNC_FOREGROUND PATH="$NOFLOCK_V" CLAUDE_PLUGIN_ROOT="$PLUGIN_R" \
    HANDBOOK_CACHE_DIR="$CACHE_R" "$NOFLOCK_V/sh" "$SCRIPT" >/dev/null 2>&1
if wait_for test -f "$CACHE_R/dev/NOFLOCK.md" && wait_for test ! -d "$CACHE_R/dev/.git/handbook-sync.lock.d"; then
    pass "case v: stale mkdir lock broken, pull landed, lock released"
else
    fail "case v: file=$(ls "$CACHE_R/dev/NOFLOCK.md" 2>&1) lock=$(ls -d "$CACHE_R/dev/.git/handbook-sync.lock.d" 2>&1)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
