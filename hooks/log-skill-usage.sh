#!/bin/sh
# PostToolUse hook — logs handbook skill invocations to skill-usage.jsonl.
# Filters to only handbook: namespaced skills; logs nothing else.
# Always exits 0 — a logging failure must never break the user's session.

# Bail early and silently if jq is missing.
command -v jq >/dev/null 2>&1 || exit 0

# Read full stdin payload.
payload=$(cat)

# Extract the skill name.
skill=$(printf '%s' "$payload" | jq -r '.tool_input.skill // empty' 2>/dev/null)

# Only log handbook: skills.
case "$skill" in
    handbook:*) ;;
    *) exit 0 ;;
esac

# Resolve data dir; skip silently if unset or unmakeable.
data_dir="${CLAUDE_PLUGIN_DATA}"
if [ -z "$data_dir" ]; then
    exit 0
fi
mkdir -p "$data_dir" 2>/dev/null || exit 0

log_file="${data_dir}/skill-usage.jsonl"

# Extract fields from payload.
session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
success=$(printf '%s' "$payload" | jq -r 'if .tool_response.success != null then .tool_response.success else "null" end' 2>/dev/null)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || printf 'unknown')

# Build and append log line; skip silently on any failure.
printf '%s' "$payload" | jq -c \
    --arg ts "$timestamp" \
    --arg sk "$skill" \
    --arg sid "$session_id" \
    --argjson ok "$success" \
    '{timestamp: $ts, skill: $sk, session_id: $sid, success: $ok}' \
    2>/dev/null >> "$log_file" 2>/dev/null

exit 0
