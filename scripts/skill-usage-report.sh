#!/bin/sh
# Produce a usage report from skill-usage.jsonl.
# Usage: skill-usage-report.sh [--data-dir <path>] [--since Nd]

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ---------- argument parsing ----------
data_dir_arg=""
since_days=0

while [ $# -gt 0 ]; do
    case "$1" in
        --data-dir)
            data_dir_arg="$2"
            shift 2
            ;;
        --since)
            since_days=$(printf '%s' "$2" | sed 's/[dD]$//')
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ---------- locate log file(s) ----------
# Resolution order:
#   1. --data-dir <path> if non-empty and log exists there
#   2. $CLAUDE_PLUGIN_DATA if non-empty and log exists there
#   3. glob $HOME/.claude/plugins/data/handbook-*/skill-usage.jsonl

log_files=""   # newline-separated list of found log files
sources=""     # human-readable list of paths found

try_dir() {
    d="$1"
    [ -n "$d" ] || return
    f="${d}/skill-usage.jsonl"
    if [ -f "$f" ]; then
        log_files="${log_files}${f}
"
        sources="${sources}  ${f}
"
    fi
}

if [ -n "$data_dir_arg" ]; then
    # Explicit --data-dir takes precedence; try it only (don't also glob).
    try_dir "$data_dir_arg"
else
    # Try env var first.
    try_dir "$CLAUDE_PLUGIN_DATA"
    # Then glob for any handbook install path.
    for f in "$HOME"/.claude/plugins/data/handbook-*/skill-usage.jsonl; do
        [ -f "$f" ] || continue
        # Avoid duplicating a path already found via env var.
        case "
${log_files}" in
            *"
${f}
"*) ;;
            *) log_files="${log_files}${f}
"
               sources="${sources}  ${f}
" ;;
        esac
    done
fi

command -v jq >/dev/null 2>&1 || { printf 'error: jq is required\n'; exit 1; }

# Discover skills from skills/ directory.
skills_dir="${PLUGIN_ROOT}/skills"
all_skills_file=$(mktemp)
trap 'rm -f "$all_skills_file" "$tmpfile" "$fired_file" "$merged_log"' EXIT

if [ -d "$skills_dir" ]; then
    for d in "$skills_dir"/*/; do
        name=$(basename "$d")
        printf 'handbook:%s\n' "$name" >> "$all_skills_file"
    done
fi
sort -o "$all_skills_file" "$all_skills_file"

printf '=== Handbook skill usage report ===\n'

# If no log file found, report clearly and still show never-fired list.
if [ -z "$log_files" ]; then
    if [ -n "$data_dir_arg" ]; then
        printf 'Log file not found in: %s\n' "$data_dir_arg"
    else
        printf 'Log file not found in any known install path.\n'
        printf '(Checked: %s/.claude/plugins/data/handbook-*/skill-usage.jsonl)\n' "$HOME"
    fi
    printf '\nNo invocations recorded yet.\n'
    if [ -s "$all_skills_file" ]; then
        printf '\n--- Never fired ---\n'
        while IFS= read -r s; do
            printf '  %s\n' "$s"
        done < "$all_skills_file"
    fi
    exit 0
fi

printf 'Reading log(s):\n%s\n' "$sources"

# Merge all found logs into one temp file (sorted by timestamp).
merged_log=$(mktemp)
printf '%s' "$log_files" | while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] && cat "$f"
done | sort >> "$merged_log"

# Compute cutoff timestamp for --since filter.
cutoff=""
if [ "$since_days" -gt 0 ] 2>/dev/null; then
    if cutoff=$(date -d "-${since_days} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
        :
    elif cutoff=$(date -v "-${since_days}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
        :
    fi
fi

if [ "$since_days" -gt 0 ] && [ -n "$cutoff" ]; then
    printf 'Window: last %s days (since %s)\n' "$since_days" "$cutoff"
else
    printf 'Window: all time\n'
fi
printf '\n'

# Build filtered log in a temp file.
tmpfile=$(mktemp)
fired_file=$(mktemp)

if [ -n "$cutoff" ]; then
    while IFS= read -r line; do
        ts=$(printf '%s' "$line" | jq -r '.timestamp // ""' 2>/dev/null)
        case "$ts" in
            "") ;;
            *)  [ "$ts" \> "$cutoff" ] || [ "$ts" = "$cutoff" ] && printf '%s\n' "$line" ;;
        esac
    done < "$merged_log" > "$tmpfile"
else
    cp "$merged_log" "$tmpfile"
fi

total=$(wc -l < "$tmpfile" | tr -d ' ')

if [ "$total" -eq 0 ]; then
    printf 'No invocations in window.\n'
else
    printf '%-45s  %6s  %s\n' "Skill" "Count" "Last used"
    printf '%-45s  %6s  %s\n' "-----" "-----" "---------"

    jq -r '.skill' "$tmpfile" 2>/dev/null | sort -u > "$fired_file"

    while IFS= read -r sk; do
        count=$(grep -c "\"skill\":\"${sk}\"" "$tmpfile" 2>/dev/null || printf '0')
        last=$(jq -r --arg sk "$sk" 'select(.skill==$sk) | .timestamp' "$tmpfile" 2>/dev/null | sort | tail -1)
        last_date=$(printf '%s' "$last" | cut -c1-10)
        printf '%-45s  %6s  %s\n' "$sk" "$count" "$last_date"
    done < "$fired_file"
fi

printf '\n--- Never fired ---\n'

jq -r '.skill' "$tmpfile" 2>/dev/null | sort -u > "$fired_file"

never=$(comm -23 "$all_skills_file" "$fired_file" 2>/dev/null)
if [ -z "$never" ]; then
    printf '  (all known skills have fired in this window)\n'
else
    printf '%s\n' "$never" | while IFS= read -r s; do
        printf '  %s\n' "$s"
    done
fi

printf '\nTotal invocations in window: %s\n' "$total"
