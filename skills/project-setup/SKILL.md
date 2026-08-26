---
name: project-setup
description: "Project-setup guidance from Oursky's engineering handbook. Use when asking about CI/CD, GitHub Actions setup, Make targets, mobile pipeline, App Store / Play Store config, or new project checklist."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/project-setup/index.md — topic overview table; orient here, then read the relevant file
- guides/project-setup/engineering-project-checklist.md — master checklist of what every new project must have before it ships
- guides/project-setup/project-cicd-pipeline.md — three-stage pipeline structure (test / build / deploy), branch promotion rules, no-lock-in principle
- guides/project-setup/github-actions.md — runner labels, available secrets, third-party action restriction, concurrency groups, Slack subscription
- guides/project-setup/github-actions-recipes.md — copy-paste workflow starters: web SPA, Kubernetes deploy, per-env monorepo jobs, private submodules
- guides/project-setup/make-targets.md — required Make targets every project must implement and what each one does
- guides/project-setup/mobile-ci-pipeline.md — Android, Flutter, and iOS build pipelines: SDK setup, signing, fastlane distribution to Play Store / TestFlight
- guides/project-setup/appstore-playstore-setup.md — bundle ID convention, Google Play and App Store accounts, fastlane service account, signing key storage

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/project-setup/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/project-setup/"`
4. `historical-archive/` is deprecated; do not cite files from it.
