---
name: dev-project-setup
description: "Project-setup guidance from Oursky's engineering handbook. Use when asking about CI/CD, GitHub Actions setup, Make targets, mobile pipeline, Xcode version, App Store / Play Store config, or new project checklist."
user-invocable: false
---

<!-- handbook-reviewed: 2b4ec2b12888e9476357b2dbfccfab00d46ad1da -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- project-setup/index.md — topic overview table; orient here, then read the relevant file
- project-setup/engineering-project-checklist.md — master checklist of what every new project must have before it ships
- project-setup/project-cicd-pipeline.md — three-stage pipeline structure (test / build / deploy), branch promotion rules, keeping `make build` a plain docker build, no-lock-in principle
- project-setup/github-actions.md — runner labels, available secrets, third-party action restriction, concurrency groups, Slack subscription
- project-setup/github-actions-recipes.md — copy-paste workflow starters: web SPA, Kubernetes deploy, agentic cluster deploy, per-env monorepo jobs, private submodules
- project-setup/make-targets.md — required Make targets every project must implement and what each one does
- project-setup/mobile-ci-pipeline.md — Android, Flutter, and iOS build pipelines: SDK setup, choosing and pinning an Xcode version, signing, fastlane distribution to Play Store / TestFlight
- project-setup/appstore-playstore-setup.md — bundle ID convention, Google Play and App Store accounts, fastlane service account, signing key storage
- project-setup/blob-storage.md — portable blob storage: storage interface over local FS/S3/GCS, rclone fixtures, shared RustFS for dev deployments

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/project-setup/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/project-setup/"`
4. `historical-archive/` is deprecated; do not cite files from it.
