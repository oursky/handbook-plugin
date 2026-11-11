#!/bin/sh
# Tests for log-skill-usage.sh and skill-usage-report.sh. No network.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/log-skill-usage.sh"
REPORT="$HERE/../scripts/skill-usage-report.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

PLUGIN="$TMP/plugin"
mkdir -p "$PLUGIN/skills/dev-git" "$PLUGIN/skills/dev-web"
: > "$PLUGIN/skills/dev-git/SKILL.md"
: > "$PLUGIN/skills/dev-web/SKILL.md"
CACHE="$TMP/cache/oursky-handbook"
DATA="$TMP/data"
LOG="$DATA/skill-usage.jsonl"

# fire <json payload>; returns hook exit code, appends to $LOG
fire() {
    printf '%s' "$1" | CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PLUGIN_DATA="$DATA" \
        HANDBOOK_CACHE_DIR="$CACHE" HOME="$TMP/home" sh "$HOOK"
}
reset() { rm -rf "$DATA"; }
# lines <skill> <via> -> count of matching log lines
count() { [ -f "$LOG" ] || { echo 0; return; }; jq -c --arg s "$1" --arg v "$2" 'select(.skill==$s and .via==$v)' "$LOG" | wc -l | tr -d ' '; }
total() { [ -f "$LOG" ] || { echo 0; return; }; wc -l < "$LOG" | tr -d ' '; }

# a: Skill call
reset
fire '{"session_id":"s1","tool_name":"Skill","tool_input":{"skill":"handbook:dev-git"},"tool_response":{"success":true}}'; rc=$?
if [ $rc -eq 0 ] && [ "$(count handbook:dev-git skill)" = 1 ] && [ "$(total)" = 1 ]; then
    pass "a: Skill call logs via=skill"
else fail "a: rc=$rc $(cat "$LOG" 2>&1)"; fi

# b: non-handbook Skill ignored
reset
fire '{"session_id":"s1","tool_name":"Skill","tool_input":{"skill":"other:thing"}}'
[ "$(total)" = 0 ] && pass "b: non-handbook Skill ignored" || fail "b: $(cat "$LOG")"

reset
fire "{\"session_id\":\"s1\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$CACHE/dev/git/rebase.md\"},\"tool_response\":{}}"
if [ "$(count handbook:dev-git read)" = 1 ] && [ "$(total)" = 1 ]; then
    pass "c: Read of topic file logs dev-git via=read"
else fail "c: $(cat "$LOG" 2>&1)"; fi

reset
HOME="$TMP/home" ; CACHE_SAVE="$CACHE"; CACHE="$TMP/home/.cache/oursky-handbook"
fire '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"grep -r foo ~/.cache/oursky-handbook/dev/git"}}'
if [ "$(count handbook:dev-git read)" = 1 ] && [ "$(total)" = 1 ]; then
    pass "d: Bash with ~/.cache path logs dev-git via=read"
else fail "d: $(cat "$LOG" 2>&1)"; fi
reset
fire '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"cat $HOME/.cache/oursky-handbook/dev/web/seo.md"}}'
[ "$(count handbook:dev-web read)" = 1 ] && pass "d2: \$HOME form resolves" || fail "d2: $(cat "$LOG" 2>&1)"
CACHE="$CACHE_SAVE"

reset
fire "{\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"diff $CACHE/dev/git/a.md $CACHE/dev/web/b.md; cat $CACHE/dev/git/c.md\"}}"
if [ "$(count handbook:dev-git read)" = 1 ] && [ "$(count handbook:dev-web read)" = 1 ] && [ "$(total)" = 2 ]; then
    pass "e: two topics log two lines"
else fail "e: $(cat "$LOG" 2>&1)"; fi

reset
fire "{\"session_id\":\"s1\",\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"x\",\"path\":\"$CACHE/dev/nonesuch\"}}"
[ "$(count handbook:dev read)" = 1 ] && [ "$(total)" = 1 ] && pass "f: unknown topic logs handbook:dev" || fail "f: $(cat "$LOG" 2>&1)"

reset
fire "{\"session_id\":\"s1\",\"tool_name\":\"Glob\",\"tool_input\":{\"pattern\":\"*.md\",\"path\":\"$CACHE/dev/web\"}}"
[ "$(count handbook:dev-web read)" = 1 ] && pass "g: Glob path logs dev-web" || fail "g: $(cat "$LOG" 2>&1)"

reset
fire '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls -la /tmp"}}'; rc=$?
fire '{"session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
if [ $rc -eq 0 ] && [ "$(total)" = 0 ]; then pass "h: unrelated calls log nothing"; else fail "h: $(cat "$LOG" 2>&1)"; fi

reset
fire "{\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"grep SECRETWORD $CACHE/dev/git\"}}"
if [ -f "$LOG" ] && ! grep -q 'SECRETWORD\|/dev/git\|oursky-handbook' "$LOG"; then
    pass "i: log line holds no command or path"
else fail "i: $(cat "$LOG" 2>&1)"; fi

out=$(printf 'not json' | CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PLUGIN_DATA="$DATA" sh "$HOOK" 2>&1); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ] && pass "j: garbage stdin exits 0 silent" || fail "j: rc=$rc out=$out"

RD="$TMP/rdata"; mkdir -p "$RD"
cat > "$RD/skill-usage.jsonl" <<'LOG'
{"timestamp":"2026-11-01T00:00:00Z","skill":"handbook:dev-git","session_id":"a","success":true}
{"timestamp":"2026-11-02T00:00:00Z","skill":"handbook:dev-git","session_id":"a","success":true,"via":"skill"}
{"timestamp":"2026-11-03T00:00:00Z","skill":"handbook:dev-git","session_id":"a","success":null,"via":"read"}
{"timestamp":"2026-11-04T00:00:00Z","skill":"handbook:dev-web","session_id":"a","success":null,"via":"read"}
LOG
rep=$(CLAUDE_PLUGIN_ROOT="$PLUGIN" HOME="$TMP/home" sh "$REPORT" --data-dir "$RD")
row_git=$(printf '%s\n' "$rep" | grep '^handbook:dev-git ' | tr -s ' ')
row_web=$(printf '%s\n' "$rep" | grep '^handbook:dev-web ' | tr -s ' ')
[ "$row_git" = "handbook:dev-git 2 1 3 2026-11-03" ] && pass "k1: dev-git row 2 skill, 1 read, 3 total" || fail "k1: '$row_git'"
[ "$row_web" = "handbook:dev-web 0 1 1 2026-11-04" ] && pass "k2: dev-web read-only row" || fail "k2: '$row_web'"
printf '%s\n' "$rep" | grep -q 'Via skill.*Via read.*Total' && pass "k3: header columns" || fail "k3: header"
never=$(printf '%s\n' "$rep" | sed -n '/Never fired/,$p')
if ! printf '%s' "$never" | grep -q 'dev-git\|dev-web'; then pass "k4: read-only skills not in Never fired"; else fail "k4: $never"; fi

rep=$(CLAUDE_PLUGIN_ROOT="$PLUGIN" HOME="$TMP/home" sh "$REPORT" --data-dir "$RD" --since 1d)
printf '%s\n' "$rep" | grep -q 'No invocations in window' && pass "l: --since drops old lines" || fail "l: $rep"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ $FAIL -eq 0 ]
