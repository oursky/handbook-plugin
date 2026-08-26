---
description: Show handbook skill usage — invocation counts, last-used dates, and skills that have never fired. Pass --since Nd to limit to the last N days (e.g. --since 7d).
argument-hint: '[--since Nd]'
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/skill-usage-report.sh" $ARGUMENTS`
