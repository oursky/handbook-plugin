# Skill Authoring Contract

This document is the binding contract for all topic-skill authors across every
handbook this plugin ships. Follow it verbatim; do not invent alternatives.

---

## Skill naming

Skills are named `<handbook-id>-<topic>`, where `<handbook-id>` is the `id`
field from `handbooks.json` and `<topic>` is the directory name under that
handbook's `topic_root`.

Examples:

| Handbook id | Topic dir           | Skill name                    |
|-------------|---------------------|-------------------------------|
| `dev`       | `git`               | `dev-git`                     |
| `dev`       | `security`          | `dev-security`                |
| `pm`        | `usage-guide`       | `pm-usage-guide`              |

The exception is `handbook-authoring`, which is a hand-authored meta-skill
(not tied to any handbook corpus) and follows no `<id>-<topic>` pattern.

---

## Frontmatter

```yaml
---
name: <handbook-id>-<topic>    # e.g. dev-git, dev-security, pm-usage-guide
description: "<clause1> <clause2>"
user-invocable: false
---
```

**Key spelling:** `user-invocable` (hyphen, not underscore).
Citation: `doc/eval-probe-findings.md` §Q-A — "qa-hidden (user-invocable: false)" was
confirmed functional via live eval; the binary key is hyphenated kebab-case.

### Description rules

- **Total: ≤200 chars** (hard cap; run `echo -n "$desc" | wc -c` to verify).
- **Clause 1 ≤65 chars:** `<Topic> guidance from <label>.`
  where `<label>` is the exact `label` value from `handbooks.json`
  (e.g. `"Oursky engineering handbook"`, `"Oursky PM workflow handbook"`).
  This corpus identifier is the primary disambiguator when two handbooks
  cover related topics.
- **Clause 2:** `Use when <3–6 natural phrasings a teammate would actually type>,
  or asking about <2–4 literal handbook terms>.`
- No overlap in trigger nouns **within the same handbook** (see tables below).
- Do NOT echo section-title language; use phrases developers say in Slack.

---

## Reserved trigger-noun tables

Nouns are disjoint **within a handbook only — not across handbooks.**

**Rationale:** Forcing global uniqueness would silence a handbook that
genuinely owns a topic. Cross-handbook overlap is legitimate: when two
handbooks cover related subject matter from different angles, the corpus
identifier in clause 1 (e.g. "engineering handbook" vs "PM workflow handbook")
is what routes the question correctly — not noun exclusivity.

**Worked example:** The `pm` corpus documents `openapi-spec-generation` and
`github-commit-summary`. Meanwhile `dev-development` reserves the noun *API*
and `dev-git` reserves *commit style*. An OpenAPI or commit question can
properly land in either corpus: a developer asking about the team API-design
rule lands in `dev-development`; a PM asking which tool to use to generate
an OpenAPI spec lands in `pm-usage-guide`. Both behaviours are correct.
The disjointness rule keeps the *dev* skills from fighting each other, and
the *pm* skills from fighting each other — it does not govern cross-handbook
overlaps.

### `dev` — Oursky engineering handbook

Each `dev-*` skill owns the nouns in its row. Do not use another dev skill's
nouns in your description.

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

### `pm` — Oursky PM workflow handbook

The `pm` handbook currently ships one skill (`pm-usage-guide`) covering its
entire `usage-guide/` corpus. All nouns below belong to that single skill.

| Topic dir   | Reserved trigger nouns / phrases                                                                      |
|-------------|-------------------------------------------------------------------------------------------------------|
| usage-guide | Basecamp work record, Linear bug report, sprint objective, sprint goal, user story, progress update, openapi spec generation, github commit summary, master requirement, video usage guide |

---

## Generated-vs-hand-authored ownership

Most per-topic skills (`dev-*`, `pm-usage-guide`) are **generated** by the
`handbook-authoring` meta-skill. The `handbook-authoring` skill itself is
**hand-authored** with `user-invocable: true`.

| Part of `SKILL.md`                | Owner     | Rule                                                                                         |
|-----------------------------------|-----------|----------------------------------------------------------------------------------------------|
| Body table-of-contents (file list)| Machine   | Regenerated from the corpus on each run. Do not hand-edit; changes will be overwritten.     |
| `description` line in frontmatter | Human     | Regeneration **never rewrites an existing description.** Set it once; it is yours to keep. **Constraint:** must be written as an unindented `description: "..."` scalar on one line — indented or YAML block-scalar forms are not detected by the generator and will be silently replaced with a `DRAFT` placeholder on the next run. |
| `name` and `user-invocable`       | Machine   | Set at generation time; match the naming scheme above.                                       |

**Noun-table check is advisory.** The generator reports noun conflicts
between sibling skills in the same handbook but does **not** gate on them.
A human must resolve the conflict before the skill ships.

---

## Body template

Keep body ≤40 lines. Adapt the placeholders for your handbook id and topic dir.

```markdown
## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- <topic_root>/<dir>/file-a.md — <one-line: what question does this file answer?>
- <topic_root>/<dir>/file-b.md — <one-line: what question does this file answer?>

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/<id>/<topic_root>/<dir>/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/<id>/<topic_root>/<dir>/"`
4. `historical-archive/` is deprecated; do not cite files from it.
```

Cache path structure: `<cache-root>/<id>/<topic_root>/<dir>/`
— the `<id>/` segment (e.g. `dev/`, `pm/`) must appear in the **base path** used in the
"How to answer" section. File listing entries are relative to that base and correctly omit it.
A base path that lacks `<id>/` is the old single-handbook layout and is **incorrect**.

Concrete examples:
- `dev-git` reads from `$CACHE/dev/guides/git/`
- `pm-usage-guide` reads from `$CACHE/pm/usage-guide/`

---

## Eval file format

Path: `evals/<handbook-id>-<topic>.json`

```json
{
  "skill": "handbook:<handbook-id>-<topic>",
  "grader": {
    "type": "tool_used",
    "tool": "Skill",
    "skill": "handbook:<handbook-id>-<topic>"
  },
  "note": "Labels are TBD. A human must set must-fire/may-fire/must-not-fire before running CI.",
  "prompts": [
    {
      "id": "<handbook-id>-<topic>-001",
      "prompt": "<natural question — NOT a section title echo>",
      "label": "TBD",
      "human_labelled": false
    }
  ]
}
```

Rules:
- ≥5 prompts per topic.
- Prompts must sound like a developer or PM asking in Slack, not like a handbook
  section title.
- `label` is always `"TBD"`; `human_labelled` is always `false`.
  A human reviewer will later mark each prompt must-fire / may-fire / must-not-fire.
  Exception: `evals/negatives.json` is exempt — clear out-of-scope prompts carry
  `label: must-not-fire`; only borderline negatives are TBD.
- LLMs must NOT author the expected answers — that is the human's job.
- Grader: `tool_used: Skill` for `handbook:<handbook-id>-<topic>`.

---

## Running evals

See `evals/README.md`.
