---
name: dev-documentation
description: "Documentation guidance from Oursky's engineering handbook. Use when asking how to write repo docs: user journeys, sequence diagrams, specifications in docs/specs, AI-generated agent notes in docs/ai, or Mermaid diagrams."
user-invocable: false
---

<!-- handbook-reviewed: 2b4ec2b12888e9476357b2dbfccfab00d46ad1da -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- documentation/ai-generated.md — where coding agents keep their working notes (docs/ai/), what they may contain, and why they never replace human-facing docs
- documentation/index.md — topic overview and general rules: document design, flow and business (not engineering logs), keep docs clean, use Mermaid, doc locations
- documentation/journeys.md — documenting major cross-boundary user journeys in docs/journeys/: pre-condition, journey table, branches, sequence diagram, worked example
- documentation/specifications.md — keeping product and API integration specs agreed with outside parties in docs/specs/; specs drive the code, not the other way round

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/documentation/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/documentation/"`
