# handbook-plugin

Claude Code plugin exposing Oursky's private handbooks to agents as read-only reference.

**v0.3.0** — multi-handbook support, manual sync, usage reporting.

## Install

```bash
claude plugin marketplace add oursky/handbook-plugin
claude plugin install handbook
```

Restart Claude Code, then ask something like "what's our branch naming convention?"
to confirm it routes to the handbook.

This repo is public, but the handbooks it syncs are not — you need `jq`
(`brew install jq` / `apt install jq`) and SSH access to `oursky/handbook-dev` and
`oursky/os-project-management`. They sync to `~/.cache/oursky-handbook/` at session start.

To update:

```bash
claude plugin marketplace update oursky-handbook
claude plugin update handbook
```

## Commands

| Command | Purpose |
|---|---|
| `/handbook:sync` | Re-sync handbooks now; prints each one's SHA, commit date, and whether it moved. Add `--regen` to regenerate skills too. |
| `/handbook:usage` | Which handbook skills have fired, how often, and which never have. Add `--since 7d` to window it. |

Both are type-only (`disable-model-invocation: true`).

## How it works

1. **SessionStart hook** — `hooks/sync-handbook.sh` reads `handbooks.json` and
   clones or fast-forward pulls each handbook into `$HANDBOOK_CACHE_DIR/<id>/`
   (default `~/.cache/oursky-handbook`). Never exits non-zero; a failed handbook
   keeps its stale cache while others sync.
2. **Topic-scoped skills** — 11 skills, one per handbook section. The model picks
   one from the prompt, reads the relevant file **in full** from the cache, and
   shells out to `rg` for exact-string lookups.

No index, no embeddings, no chunking, no PreToolUse injection — the corpus is
small enough that whole-file reads are cheaper than a retrieval pipeline
(decisions D-2, D-6).

Skills: `dev-agentic-engineering`, `dev-deployment-infra`, `dev-development`,
`dev-git`, `dev-human-interface`, `dev-observability`, `dev-project-setup`,
`dev-security`, `dev-web`, `pm-usage-guide`, `handbook-authoring`.

## Adding a handbook

Add one entry to `handbooks.json` — no script edits needed:

```json
{
  "id": "pm",
  "url": "git@github.com:oursky/os-project-management.git",
  "topic_root": "usage-guide/",
  "depth": 0,
  "label": "Oursky PM workflow handbook"
}
```

| Field | Purpose |
|---|---|
| `id` | Skill-name prefix (`dev-git`) and cache subdirectory |
| `url` | SSH clone URL |
| `topic_root` | Path within the repo containing topic directories |
| `depth` | `0` = `topic_root` is itself one topic; `1` = its immediate subdirs are topics |
| `label` | Corpus name used in clause 1 of each skill description, so two handbooks can share trigger nouns |

Then invoke the `handbook-authoring` skill to generate `skills/<id>-<topic>/SKILL.md`,
review the diff, and commit. It never overwrites an existing `description:` line, so
hand-tuned descriptions survive regeneration. Flags: `--threshold N` (skip topics with
fewer than N files, default 3), `--check` (report duplicate trigger nouns, write nothing).

## Developing this plugin

Install from a local clone instead, so the plugin runs from your working tree and
edits take effect on `/reload-plugins` with no version bump and no push:

```bash
git clone git@github.com:oursky/handbook-plugin.git ~/.local/share/handbook-plugin
claude plugin marketplace add ~/.local/share/handbook-plugin
claude plugin install handbook
```

(`claude --plugin-dir <path>` does the same for a single session.)

Installing from `oursky/handbook-plugin` instead gives you a clone that Claude Code
owns, so changes need a `version` bump in **both** `.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`, a push, then `claude plugin update handbook`.

## Usage logging

A `PostToolUse` hook appends one line per `handbook:`-namespaced skill invocation to
`~/.claude/plugins/data/handbook-*/skill-usage.jsonl`:

```json
{"timestamp":"2026-08-25T17:00:00Z","skill":"handbook:dev-git","session_id":"…","success":true}
```

**Never logged:** prompt text, cwd, transcript path. Local only, no network calls.
Disable by removing the `PostToolUse` entry from `hooks/hooks.json`; clear by deleting
the JSONL file.

**It has no denominator.** A question where a handbook skill *should* have fired but
didn't leaves no trace. This is a usage distribution, not a trigger rate — the
actionable signal is a skill sitting at zero after real work, meaning its description
doesn't match how people phrase those questions.

## Layout

```
.claude-plugin/     plugin.json, marketplace.json
handbooks.json      declared handbooks
hooks/              sync-handbook.sh (SessionStart), log-skill-usage.sh (PostToolUse)
commands/           sync.md, usage.md
scripts/            handbook-sync-status.sh, skill-usage-report.sh
skills/             11 SKILL.md files
doc/                skill-authoring.md — binding authoring contract
```

`doc/skill-authoring.md` is the contract for frontmatter, description rules, and the
per-handbook trigger-noun tables. Trigger nouns must be disjoint within a handbook;
across handbooks, the `label` in clause 1 disambiguates.
