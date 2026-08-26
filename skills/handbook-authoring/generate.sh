#!/usr/bin/env bash
# handbook-authoring/generate.sh
#
# Walks handbooks.json + synced caches, writes skills/<id>-<topic>/SKILL.md.
# NEVER rewrites an existing description: line — it is human-owned.
# Drafts a placeholder description only for brand-new skill files; marks it DRAFT.
#
# Usage:
#   generate.sh [--check] [--threshold N]
#
#   --check       Report duplicate trigger nouns only; do not generate files.
#   --threshold N Skip topics with fewer than N .md files (default: 3).

set -euo pipefail

# ── locate plugin root (two levels up from this script) ──────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HANDBOOKS_JSON="$PLUGIN_DIR/handbooks.json"
SKILLS_DIR="$PLUGIN_DIR/skills"
CACHE_ROOT="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

# ── defaults ─────────────────────────────────────────────────────────────────
MIN_FILES=3   # withholding threshold: skip topics with fewer than this many .md files
MODE="generate"

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)      MODE="check"; shift ;;
        --threshold)  MIN_FILES="$2"; shift 2 ;;
        --threshold=*)MIN_FILES="${1#*=}"; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# ── require jq ───────────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not found in PATH." >&2
    exit 1
fi

# ── helpers ───────────────────────────────────────────────────────────────────

# Count .md files (non-recursive) in a directory
count_md() { find "$1" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' '; }

# Strip punctuation, lowercase, remove short/stop words — returns word list
extract_nouns() {
    local desc="$1"
    echo "$desc" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs 'a-z_-' '\n' \
        | grep -v -E '^(use|when|asking|about|how|to|the|a|an|and|or|for|on|in|from|with|of|this|is|are|at|by|as|it|its|our|oursky|handbook|guidance|skill|skills|covers|writing|write|create|run|running|generate|generating|making|make|listing|list|plan|planning|review|reviewing|fill|filling|log|logging|draft|drafting|submit|submitting|file|filing|get|getting|engineering|workflow|pm|dev|management)$' \
        | grep -v -E '^.{1,2}$' \
        || true
}

# ── check mode ────────────────────────────────────────────────────────────────
run_check() {
    echo "=== Trigger-noun duplicate check ==="
    echo ""

    # Collect (handbook_id, topic, description) for all generated skills
    local -a hb_ids=()
    local -a hb_topics=()
    local -a hb_descs=()

    while IFS= read -r hb_id; do
        # Gather skills matching this handbook
        for skill_dir in "$SKILLS_DIR"/"$hb_id"-*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_file="$skill_dir/SKILL.md"
            [[ -f "$skill_file" ]] || continue
            local desc
            # NOTE: description: must be an unindented scalar on one line; indented or
            # block-scalar descriptions are not detected — write them unindented.
            desc=$(grep '^description:' "$skill_file" | head -1 | sed 's/^description:[[:space:]]*//')
            local topic
            topic="$(basename "$skill_dir")"
            hb_ids+=("$hb_id")
            hb_topics+=("$topic")
            hb_descs+=("$desc")
        done
    done < <(jq -r '.handbooks[].id' "$HANDBOOKS_JSON")

    # Within-handbook: duplicate nouns between skills of the same handbook
    echo "--- Within-handbook duplicates ---"
    local found_within=0
    local n="${#hb_ids[@]}"
    for ((i=0; i<n; i++)); do
        for ((j=i+1; j<n; j++)); do
            [[ "${hb_ids[$i]}" != "${hb_ids[$j]}" ]] && continue
            local nouns_i nouns_j overlap
            nouns_i=$(extract_nouns "${hb_descs[$i]}")
            nouns_j=$(extract_nouns "${hb_descs[$j]}")
            overlap=$(comm -12 <(echo "$nouns_i" | sort -u) <(echo "$nouns_j" | sort -u) || true)
            if [[ -n "$overlap" ]]; then
                echo "  WARN [${hb_ids[$i]}] ${hb_topics[$i]} vs ${hb_topics[$j]}: shared words: $(echo "$overlap" | tr '\n' ' ')"
                found_within=1
            fi
        done
    done
    [[ $found_within -eq 0 ]] && echo "  (none found)"
    echo ""

    # Cross-handbook: near-duplicates between different handbooks
    echo "--- Cross-handbook near-duplicates (informational — overlap is expected) ---"
    local found_cross=0
    for ((i=0; i<n; i++)); do
        for ((j=i+1; j<n; j++)); do
            [[ "${hb_ids[$i]}" == "${hb_ids[$j]}" ]] && continue
            local nouns_i nouns_j overlap
            nouns_i=$(extract_nouns "${hb_descs[$i]}")
            nouns_j=$(extract_nouns "${hb_descs[$j]}")
            overlap=$(comm -12 <(echo "$nouns_i" | sort -u) <(echo "$nouns_j" | sort -u) || true)
            if [[ -n "$overlap" ]]; then
                echo "  INFO [${hb_ids[$i]}::${hb_topics[$i]}] vs [${hb_ids[$j]}::${hb_topics[$j]}]: $(echo "$overlap" | tr '\n' ' ')"
                found_cross=1
            fi
        done
    done
    [[ $found_cross -eq 0 ]] && echo "  (none found)"
    echo ""
    echo "Check complete. This report does not block generation."
}

# ── generate one skill file ───────────────────────────────────────────────────
# Args: hb_id  hb_label  rel_topic  topic_abs
#   rel_topic  — path relative to cache/<id>/  e.g. "guides/development" or "usage-guide"
#   topic_abs  — absolute path to that directory in the cache
generate_skill() {
    local hb_id="$1"
    local hb_label="$2"
    local rel_topic="$3"   # e.g. "guides/development" or "usage-guide"
    local topic_abs="$4"   # absolute cache path

    # Leaf name: last path component (e.g. "development", "usage-guide")
    local topic_dir_name
    topic_dir_name="$(basename "$rel_topic")"

    local skill_name="${hb_id}-${topic_dir_name}"
    local skill_dir="$SKILLS_DIR/$skill_name"
    local skill_file="$skill_dir/SKILL.md"

    local cache_topic_path="\$CACHE/${hb_id}/${rel_topic}"

    # ── Parse existing file-listing annotations (keyed by basename) ──────────
    # Values are the annotation text after " — " on each bullet line.
    # existing_order records insertion order so the listing sequence is preserved.
    local -A existing_annotations=()
    local -a existing_order=()
    if [[ -f "$skill_file" ]]; then
        local _in_lst=0
        while IFS= read -r _line; do
            if [[ "$_line" == "## Files in this topic" ]]; then
                _in_lst=1; continue
            fi
            if [[ $_in_lst -eq 1 && "$_line" =~ ^"## " ]]; then
                _in_lst=0; continue
            fi
            if [[ $_in_lst -eq 1 && "$_line" =~ ^-\ ([^[:space:]]+)\ —\ (.*)$ ]]; then
                local _path="${BASH_REMATCH[1]}"
                local _annot="${BASH_REMATCH[2]}"
                local _base
                _base="$(basename "$_path")"
                existing_annotations["$_base"]="$_annot"
                existing_order+=("$_base")
            fi
        done < "$skill_file"
    fi

    # ── Build corpus file set ─────────────────────────────────────────────────
    local -A corpus_set=()
    local -a sorted_corpus=()
    while IFS= read -r _md; do
        local _cb; _cb="$(basename "$_md")"
        corpus_set["$_cb"]=1
        sorted_corpus+=("$_cb")
    done < <(find "$topic_abs" -maxdepth 1 -name "*.md" -type f | sort)

    # ── Build file listing ────────────────────────────────────────────────────
    # Paths are bare-relative (relative to cache/<id>/): e.g. guides/git/file.md
    # Emit in existing order first (dropping files removed from corpus),
    # then append any new files (sorted) with placeholder annotations.
    local file_lines=""
    local -A emitted=()
    for _base in "${existing_order[@]}"; do
        [[ -z "${corpus_set[$_base]+x}" ]] && continue  # removed from corpus
        file_lines+="- ${rel_topic}/${_base} — ${existing_annotations[$_base]}"$'\n'
        emitted["$_base"]=1
    done
    for _base in "${sorted_corpus[@]}"; do
        [[ -n "${emitted[$_base]+x}" ]] && continue
        file_lines+="- ${rel_topic}/${_base} — [add one-line description]"$'\n'
    done

    # ── Write or splice skill file ────────────────────────────────────────────
    mkdir -p "$skill_dir"

    if [[ -f "$skill_file" ]]; then
        # Existing file: splice only the ## Files in this topic block.
        # Frontmatter, How to answer, and any hand-authored guidance below the
        # listing are preserved byte-untouched.
        local _listing_file
        _listing_file="$(mktemp)"
        printf '%s' "$file_lines" > "$_listing_file"
        awk -v lf="$_listing_file" '
            /^## Files in this topic$/ {
                in_section=1
                print
                print ""
                while ((getline ln < lf) > 0) print ln
                print ""
                close(lf)
                next
            }
            in_section && /^## / { in_section=0 }
            in_section { next }
            { print }
        ' "$skill_file" > "${skill_file}.tmp" && mv "${skill_file}.tmp" "$skill_file"
        rm -f "$_listing_file"
    else
        # New file: write full skeleton with DRAFT description
        local desc_line
        desc_line="description: \"DRAFT — review before shipping: ${hb_label} guidance on ${topic_dir_name}. Use when asking about ...\""
        echo "  NEW skill: $skill_name (description is a draft — edit before shipping)"
        cat > "$skill_file" <<EOF
---
name: ${skill_name}
${desc_line}
user-invocable: false
---

## Cache root

CACHE="\${HANDBOOK_CACHE_DIR:-\${XDG_CACHE_HOME:-\$HOME/.cache}/oursky-handbook}"

## Files in this topic

${file_lines}
## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from \`${cache_topic_path}/\`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   \`rg -l "search term" "${cache_topic_path}/"\`
EOF
    fi

    echo "  Written: $skill_file"
}

# ── main: generate mode ───────────────────────────────────────────────────────
run_generate() {
    local generated=0
    local skipped=0

    echo "Cache root: $CACHE_ROOT"
    echo "Withholding threshold: $MIN_FILES .md files"
    echo ""

    while IFS= read -r hb_json; do
        local hb_id hb_label hb_topic_root hb_depth
        hb_id=$(echo "$hb_json" | jq -r '.id')
        hb_label=$(echo "$hb_json" | jq -r '.label')
        hb_topic_root=$(echo "$hb_json" | jq -r '.topic_root')
        hb_depth=$(echo "$hb_json" | jq -r '.depth')

        echo "Handbook: $hb_id ($hb_label)"

        local cache_hb="$CACHE_ROOT/$hb_id"
        if [[ ! -d "$cache_hb" ]]; then
            echo "  SKIP: cache not found at $cache_hb (run sync-handbook.sh first)"
            echo ""
            continue
        fi

        local topic_root_abs="$cache_hb/${hb_topic_root%/}"
        if [[ ! -d "$topic_root_abs" ]]; then
            echo "  SKIP: topic_root '$hb_topic_root' not found under $cache_hb"
            echo ""
            continue
        fi

        # Walk subdirectories of topic_root at hb_depth levels.
        # Fallback: if topic_root has no subdirectories, treat topic_root itself
        # as the single topic (handles flat handbooks like pm/usage-guide/).
        local topic_root_trimmed="${hb_topic_root%/}"
        local -a topic_dirs=()
        while IFS= read -r d; do
            topic_dirs+=("$d")
        done < <(find "$topic_root_abs" -mindepth "$hb_depth" -maxdepth "$hb_depth" -type d | sort)

        if [[ ${#topic_dirs[@]} -eq 0 ]]; then
            # No subdirs found — treat topic_root itself as the sole topic
            topic_dirs=("$topic_root_abs")
        fi

        for topic_dir in "${topic_dirs[@]}"; do
            local topic_name count rel_topic
            topic_name="$(basename "$topic_dir")"
            count=$(count_md "$topic_dir")
            if [[ "$count" -lt "$MIN_FILES" ]]; then
                echo "  SKIP topic '$topic_name': $count .md file(s) < threshold $MIN_FILES"
                ((skipped++)) || true
                continue
            fi
            # Build rel_topic: if this IS the topic_root, rel = topic_root_trimmed;
            # otherwise rel = topic_root_trimmed/topic_name
            if [[ "$topic_dir" == "$topic_root_abs" ]]; then
                rel_topic="$topic_root_trimmed"
            else
                rel_topic="${topic_root_trimmed}/${topic_name}"
            fi
            generate_skill "$hb_id" "$hb_label" "$rel_topic" "$topic_dir"
            ((generated++)) || true
        done

        echo ""
    done < <(jq -c '.handbooks[]' "$HANDBOOKS_JSON")

    echo "Generated: $generated skill(s). Skipped: $skipped topic(s) below threshold ($MIN_FILES files)."
    echo ""

    # ── Reload instructions ───────────────────────────────────────────────────
    local plugin_json="$PLUGIN_DIR/.claude-plugin/plugin.json"
    local market_json="$PLUGIN_DIR/.claude-plugin/marketplace.json"
    local current_ver="unknown"
    if [[ -f "$plugin_json" ]]; then
        current_ver=$(jq -r '.version // "unknown"' "$plugin_json")
    fi

    cat <<RELOAD
=== Reload instructions ===

If you loaded the plugin via --plugin-dir:
  No version bump needed.
  To activate new skills: start a new Claude Code session with --plugin-dir $PLUGIN_DIR
  or run /reload-plugins in your current session.

If you installed the plugin via marketplace (claude plugin install):
  A version bump IS required — the installed copy is a frozen cache snapshot.
  Current version: $current_ver
  Steps:
    1. Bump "version" in $plugin_json
    2. Bump "version" in $market_json  (must match)
       (bump both or neither — a half-bump leaves the plugin inconsistent)
    3. Commit and push
    4. Each user runs: claude plugin update handbook
    5. Start a new session (or /reload-plugins in the current one)
RELOAD
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
    check)    run_check ;;
    generate) run_generate ;;
esac
