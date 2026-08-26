# Skill Authoring Contract

This document is the binding contract for all 9 topic-skill authors.
Follow it verbatim; do not invent alternatives.

---

## Frontmatter

```yaml
---
name: <dir-name>           # e.g. git, security, web — must match guides/<dir>
description: "<clause1> <clause2>"
user-invocable: false
---
```

**Key spelling:** `user-invocable` (hyphen, not underscore).
Citation: `doc/eval-probe-findings.md` §Q-A — "qa-hidden (user-invocable: false)" was
confirmed functional via live eval; the binary key is hyphenated kebab-case.

### Description rules

- **Total: ≤200 chars** (hard cap; run `echo -n "$desc" | wc -c` to verify).
- **Clause 1 ≤65 chars:** `<Topic> guidance from Oursky's engineering handbook.`
- **Clause 2:** `Use when <3–6 natural phrasings a teammate would actually type>,
  or asking about <2–4 literal handbook terms>.`
- No overlap in trigger nouns between sibling skills (see table below).
- Do NOT echo section-title language; use phrases developers say in Slack.

### Reserved trigger-noun table

Each skill owns the nouns in its row. Do not use another skill's nouns in your description.

| Topic dir           | Reserved trigger nouns / phrases                                          |
|---------------------|---------------------------------------------------------------------------|
| agentic-engineering | agent, MCP, codebox, agentic provision, setup routing, codex              |
| deployment-infra    | deploy, GCP, Kubernetes, pageship, reverse proxy, block storage           |
| development         | API, Golang, Python, React, WordPress, dogpile, non-breaking changes      |
| git                 | rebase, branch naming, hotfix, no-ff merge, remote naming, commit style   |
| human-interface     | frontend styling, design engineering, UI checklist                        |
| observability       | logging, OpenTelemetry, k6, uptime, crash logging, otel                   |
| project-setup       | CI/CD, GitHub Actions, mobile pipeline, App Store, Make targets           |
| security            | secrets, GPG, SOPS, incident response, package audit                      |
| web                 | SEO, URL design, localization, web performance, web navigation             |

---

## Body template

Keep body ≤40 lines. Adapt the placeholders for your topic dir.

```markdown
## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/<dir>/file-a.md — <one-line: what question does this file answer?>
- guides/<dir>/file-b.md — <one-line: what question does this file answer?>
<!-- one bullet per file; include index.md only if it adds content beyond the table -->

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/<dir>/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/<dir>/"`
4. `historical-archive/` is deprecated; do not cite files from it.
```

---

## Eval file format

Path: `evals/<topic>.json`

```json
{
  "skill": "handbook:<dir-name>",
  "grader": {
    "type": "tool_used",
    "tool": "Skill",
    "skill": "handbook:<dir-name>"
  },
  "note": "Labels are TBD. A human must set must-fire/may-fire/must-not-fire before running CI.",
  "prompts": [
    {
      "id": "<topic>-001",
      "prompt": "<natural developer question — NOT a section title echo>",
      "label": "TBD",
      "human_labelled": false
    }
  ]
}
```

Rules:
- ≥5 prompts per topic.
- Prompts must sound like a developer asking in Slack, not like a handbook section title.
- `label` is always `"TBD"`; `human_labelled` is always `false`.
  A human reviewer will later mark each prompt must-fire / may-fire / must-not-fire.
  Exception: `evals/negatives.json` is exempt — clear out-of-scope prompts carry
  `label: must-not-fire`; only borderline negatives are TBD.
- LLMs must NOT author the expected answers — that is the human's job.
- Grader: `tool_used: Skill` for `handbook:<topic>`.

---

## Running evals

See `evals/README.md`.
