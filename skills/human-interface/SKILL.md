---
name: human-interface
description: "Human interface guidance from Oursky's engineering handbook. Use when asking about frontend styling, design engineering, UI checklist, button padding, type scale, or responsive layout."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/human-interface/frontend-styling-basics.md — foundational CSS rules for buttons, typography, layout, images, and common styling mistakes
- guides/human-interface/design-engineering-checklist.md — pre-coding checklist to review with designer: component states, adaptive design, platform feasibility
- guides/human-interface/index.md — topic overview table (orient here, then read the relevant file above)

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/human-interface/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/human-interface/"`
4. `historical-archive/` is deprecated; do not cite files from it.
