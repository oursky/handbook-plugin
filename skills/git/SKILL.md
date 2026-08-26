---
name: git
description: "Git guidance from Oursky's engineering handbook. Use when asking about rebase, branch naming, hotfix, PR merge strategy, remote naming, commit style, or fork workflow."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/git/git-workflow.md — atomic commits, branch naming, remote naming (`oursky` convention), rebase-merge PR flow, feature flags, hotfix pointer
- guides/git/hotfix-branching-model.md — when and how to use hotfix branches for production emergencies; differs from default trunk flow
- guides/git/repo-setup.md — GitHub repo permissions, standard branch structure, PR assignee rules, Slack/GitHub integration
- guides/git/index.md — topic overview table (consult to orient, then read the relevant file above)

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/git/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a specific command or rule):
   `rg -l "search term" "$CACHE/guides/git/"`
4. `historical-archive/` is deprecated; do not cite files from it.
