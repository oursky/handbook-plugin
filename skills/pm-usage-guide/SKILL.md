---
name: pm-usage-guide
description: "PM workflow handbook for Oursky's project management skills. Use when writing user stories, sprint objectives, progress updates, Linear bug reports, Basecamp records, or master requirement docs."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- usage-guide/user_story_creator.md — how to write well-formed user stories with the PM skill
- usage-guide/sprint_objective.md — how to define and document sprint objectives
- usage-guide/progress_update.md — how to write structured progress update reports
- usage-guide/linear_bug_report.md — how to file bug reports in Linear using the PM skill
- usage-guide/master_requirement_generator.md — how to generate master requirement documents from briefs
- usage-guide/basecamp_work_record.md — how to log and format work records in Basecamp
- usage-guide/github_commit_summary.md — how to generate commit summary digests from GitHub history
- usage-guide/openapi_spec_generation.md — how to generate OpenAPI specs via the PM workflow
- usage-guide/video_usage_guide_generation.md — how to generate video usage guides for a feature or flow

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/pm/usage-guide/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/pm/usage-guide/"`
4. Do not cite files outside `usage-guide/`; the rest of the repo is Claude Code skills, not PM prose.
