---
description: Manually sync Oursky handbooks and show per-handbook status (SHA, date, updated vs current). Pass --regen to also regenerate skills after syncing.
argument-hint: '[--regen]'
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/handbook-sync-status.sh" $ARGUMENTS`
