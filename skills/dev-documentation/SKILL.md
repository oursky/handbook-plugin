---
name: dev-documentation
description: "Documentation guidance from Oursky's engineering handbook. Use when asking how to write repo docs: user journeys, sequence diagrams, specifications in docs/specs, AI-generated agent notes in artifacts/, docs/AGENTS.md, or Mermaid diagrams."
user-invocable: false
---

<!-- handbook-reviewed: 1c3dd2357955afc271439d6956871fd1deab984e -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- documentation/ai-generated.md — where coding agents keep their working notes (top-level artifacts/, outside docs/), what to write and not write, and why docs/ always wins over them
- documentation/index.md — topic overview and general rules: document design, flow and business (not engineering logs), keep docs clean, use Mermaid, doc locations (docs/ vs artifacts/), the required docs/AGENTS.md
- documentation/journeys.md — documenting major cross-boundary user journeys in docs/journeys/: pre-condition, journey table, branches, sequence diagram, worked example
- documentation/specifications.md — keeping product and API integration specs agreed with outside parties in docs/specs/; specs drive the code, not the other way round

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/documentation/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/documentation/"`
