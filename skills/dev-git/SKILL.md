---
name: dev-git
description: "Git guidance from Oursky's engineering handbook. Use when asking about rebase, branch naming, hotfix, PR merge strategy, remote naming, commit style, or fork workflow."
user-invocable: false
---

<!-- handbook-reviewed: 529f9842502a365d1f36212959f9e7436e10a1d2 -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- git/git-workflow.md — atomic commits (judging commit boundaries), branch naming (dashes, no slashes), remote naming (`oursky` convention), rebase-merge PR flow, feature flags, hotfix pointer
- git/hotfix-branching-model.md — when and how to use hotfix branches for production emergencies; differs from default trunk flow
- git/repo-setup.md — GitHub repo permissions, standard branch structure, PR assignee rules, Slack/GitHub integration
- git/index.md — topic overview table (consult to orient, then read the relevant file above)

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/git/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a specific command or rule):
   `rg -l "search term" "$CACHE/dev/git/"`
