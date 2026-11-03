---
name: dev-rationale
description: "Rationale from Oursky's engineering handbook. Use when asking what makes a good CLI, or about coding hygiene: code comments, TODO markers, or writing code to be read years later."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- rationale/cli.md — what makes a good CLI: assume a knowledgeable audience, sensible defaults, borrow git/ssh/kubectl conventions (codebox as example)
- rationale/hygiene.md — coding hygiene: tracked TODOs, minimal comments (explain why, not what), consistency, writing code to be read years later
- rationale/index.md — topic overview table; orient here, then read the relevant file

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/rationale/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/rationale/"`
