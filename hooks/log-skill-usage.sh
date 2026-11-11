#!/bin/sh
# PostToolUse hook. Logs handbook use to skill-usage.jsonl, one line per skill.
#   via "skill": a Skill call to handbook:<name>.
#   via "read":  a Read, Grep, Glob or Bash call that touches the handbook cache.
# Logs only the derived skill name, never prompts, paths or commands.
# Always exits 0. A logging failure must never break the user's session.

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)

cache_root="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"
cache_root="${cache_root%/}"

# Cheap pre-filter so unrelated tool calls skip jq.
case "$payload" in
    *'handbook:'*|*"${cache_root##*/}"*) ;;
    *) exit 0 ;;
esac

plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
skills=""
for d in "$plugin_root"/skills/*/; do
    [ -f "${d}SKILL.md" ] || continue
    n="${d%/}"
    skills="${skills}${n##*/}
"
done

data_dir="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/handbook-oursky-handbook}"
mkdir -p "$data_dir" 2>/dev/null || exit 0

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || printf 'unknown')

printf '%s' "$payload" | jq -c \
    --arg ts "$ts" \
    --arg root "$cache_root" \
    --arg home "$HOME" \
    --arg skills "$skills" '
  def names: $skills | split("\n");
  def roots:
    [$root]
    + (if ($home != "") and ($root | startswith($home + "/"))
       then ($root[($home | length):]) as $rel
            | ["~" + $rel, "$HOME" + $rel, "${HOME}" + $rel]
       else [] end);
  def from_text:
    . as $t
    | [roots[] as $r
       | ($t | split($r))[1:][]
       | capture("^/(?<id>[A-Za-z0-9_.-]+)(?:/(?<topic>[A-Za-z0-9_.-]+))?")?
       | select(.id != null)
       | . as $m
       | if ($m.topic != null) and ((names | index($m.id + "-" + $m.topic)) != null)
         then "handbook:" + $m.id + "-" + $m.topic
         else "handbook:" + $m.id end]
    | unique[];
  (.tool_input // {}) as $in
  | (.session_id // "") as $sid
  | (if (.tool_response | type) == "object" then .tool_response.success else null end) as $ok
  | (if .tool_name == "Skill" then
       (($in.skill // "") | select(startswith("handbook:")) | {skill: ., via: "skill"})
     else
       ([$in.file_path, $in.path, $in.pattern, $in.command]
        | map(select(type == "string")) | join("\n") | from_text
        | {skill: ., via: "read"})
     end)
  | {timestamp: $ts, skill, session_id: $sid, success: $ok, via}
' >> "${data_dir}/skill-usage.jsonl" 2>/dev/null
exit 0
