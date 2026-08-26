#!/bin/sh
# Produce a usage report from ${CLAUDE_PLUGIN_DATA}/skill-usage.jsonl.
# Usage: skill-usage-report.sh [--since Nd]
# Example: skill-usage-report.sh --since 7d

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
data_dir="${CLAUDE_PLUGIN_DATA}"
log_file="${data_dir}/skill-usage.jsonl"

# --since Nd: filter to last N days. 0 = no filter.
since_days=0
if [ "$1" = "--since" ] && [ -n "$2" ]; then
    since_days=$(printf '%s' "$2" | sed 's/[dD]$//')
fi

command -v jq >/dev/null 2>&1 || { printf 'error: jq is required\n'; exit 1; }

# Discover skills from skills/ directory (strip trailing /SKILL.md, keep basename).
skills_dir="${PLUGIN_ROOT}/skills"
all_skills_file=$(mktemp)
trap 'rm -f "$all_skills_file" "$tmpfile" "$fired_file"' EXIT

if [ -d "$skills_dir" ]; then
    for d in "$skills_dir"/*/; do
        name=$(basename "$d")
        printf 'handbook:%s\n' "$name" >> "$all_skills_file"
    done
fi
sort -o "$all_skills_file" "$all_skills_file"

printf '=== Handbook skill usage report ===\n'

# If no log file, report that but still show never-fired list.
if [ ! -f "$log_file" ]; then
    printf 'Log file not found: %s\n' "$log_file"
    printf '\nNo invocations recorded yet.\n'
    if [ -s "$all_skills_file" ]; then
        printf '\n--- Never fired ---\n'
        while IFS= read -r s; do
            printf '  %s\n' "$s"
        done < "$all_skills_file"
    fi
    exit 0
fi

# Compute cutoff timestamp for --since filter.
cutoff=""
if [ "$since_days" -gt 0 ] 2>/dev/null; then
    # Try GNU date, then BSD date.
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
    done < "$log_file" > "$tmpfile"
else
    cp "$log_file" "$tmpfile"
fi

total=$(wc -l < "$tmpfile" | tr -d ' ')

if [ "$total" -eq 0 ]; then
    printf 'No invocations in window.\n'
else
    printf '%-45s  %6s  %s\n' "Skill" "Count" "Last used"
    printf '%-45s  %6s  %s\n' "-----" "-----" "---------"

    # Aggregate: count + last timestamp per skill.
    jq -r '.skill' "$tmpfile" 2>/dev/null | sort -u > "$fired_file"

    while IFS= read -r sk; do
        count=$(grep -c "\"skill\":\"${sk}\"" "$tmpfile" 2>/dev/null || printf '0')
        last=$(jq -r --arg sk "$sk" 'select(.skill==$sk) | .timestamp' "$tmpfile" 2>/dev/null | sort | tail -1)
        last_date=$(printf '%s' "$last" | cut -c1-10)
        printf '%-45s  %6s  %s\n' "$sk" "$count" "$last_date"
    done < "$fired_file"
fi

printf '\n--- Never fired ---\n'

# Compare all_skills_file against fired_file using comm (both sorted).
jq -r '.skill' "$tmpfile" 2>/dev/null | sort -u > "$fired_file"

# comm -23: lines only in all_skills (not in fired).
never=$(comm -23 "$all_skills_file" "$fired_file" 2>/dev/null)
if [ -z "$never" ]; then
    printf '  (all known skills have fired in this window)\n'
else
    printf '%s\n' "$never" | while IFS= read -r s; do
        printf '  %s\n' "$s"
    done
fi

printf '\nTotal invocations in window: %s\n' "$total"
