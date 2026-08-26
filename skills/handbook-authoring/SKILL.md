---
name: handbook-authoring
description: "Generate or audit handbook reference skills from synced caches. Use when adding a new handbook, regenerating skills after a cache update, or checking for duplicate trigger nouns."
user-invocable: true
---

## Purpose

Generates `skills/<id>-<topic>/SKILL.md` files from the handbooks declared in
`handbooks.json` and the synced caches under the cache root. Also runs a
duplicate-trigger-noun check across the generated skills.

**Description lines are human-owned.** Regeneration NEVER rewrites an existing
`description:` line. Descriptions are preserved byte-for-byte on every re-run.
The generator only drafts a placeholder description when creating a brand-new
skill file, and it marks every draft with `DRAFT — review before shipping:` so
nothing ships without human review.

---

## Prerequisites

1. `jq` must be on `PATH`.
2. The handbook caches must be synced first:
   ```
   bash <plugin-root>/hooks/sync-handbook.sh
   ```
   The caches land under `${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}`.
3. Never vendor handbook Markdown into this repo — generated skills cite paths
   under the cache root and never copy handbook prose.

---

## Withholding threshold (default: 3 files)

Topics whose directory contains fewer than **3 `.md` files** are skipped.
Rationale: near-empty topic directories in the corpora would produce
near-empty, low-value skills. The threshold can be overridden:

```bash
bash generate.sh --threshold 2
```

Skipped topics are reported clearly on stdout. The threshold is not a hard
gate on generation — it only prunes noise topics.

---

## Generate mode (default)

```bash
bash skills/handbook-authoring/generate.sh
# or with a custom threshold:
bash skills/handbook-authoring/generate.sh --threshold 2
```

For each handbook in `handbooks.json` the script:

1. Walks `<cache-root>/<id>/<topic_root>` to `depth` levels.
2. Counts `.md` files per topic directory; skips if below threshold.
3. For each qualifying topic:
   - If `skills/<id>-<topic>/SKILL.md` **already exists**: preserves its
     `description:` line unchanged; rewrites only the file listing in the body.
   - If the file is **new**: writes a full skeleton with a `DRAFT` description
     for human review before the skill is considered complete.
4. Prints reload instructions for both load paths (see below).

Output files are `skills/<id>-<topic>/SKILL.md`, one per qualifying topic.
File-level annotations (`— [add one-line description]`) are placeholders; fill them
in by hand before merging.

---

## Check mode (D-15)

```bash
bash skills/handbook-authoring/generate.sh --check
```

Reports two things — **does not gate or block generation**:

- **Within-handbook duplicates**: trigger nouns that appear in two or more
  skill descriptions for the same handbook. These are worth reviewing since the
  `doc/skill-authoring.md` contract requires nouns to be disjoint within a
  handbook.
- **Cross-handbook near-duplicates** (informational only): shared nouns across
  handbooks. This is expected and legitimate — the corpus name in each
  description's first clause disambiguates. The shipped example: `pm` covers
  `openapi_spec_generation.md` and `github_commit_summary.md` while
  `dev-development` reserves *API* and `dev-git` reserves *commit style*. Both
  sets are correct.

Run check mode after generation to surface anything to review. It never fails
the run.

---

## Reload instructions (from empirical findings in doc/plugin-reload-findings.md)

The generator script prints the correct instruction set at the end of every
generate run. Summary:

### Loaded via `--plugin-dir <path>`

No version bump needed. New skill directories are picked up from disk at the
next session start.

```
To activate: start a new Claude Code session with --plugin-dir <path>
or run /reload-plugins in your current session.
```

### Installed via marketplace (`claude plugin install`)

The installed copy is a **frozen cache snapshot** at
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Adding a skill
directory to the source repo does NOT update the installed copy.

A version bump is required — and it must be applied to **both** files or
neither (a half-bump leaves the plugin in an inconsistent state):

```
1. Bump "version" in .claude-plugin/plugin.json
2. Bump "version" in .claude-plugin/marketplace.json  (must match)
3. Commit and push
4. Each user runs: claude plugin update handbook
5. Start a new session (or /reload-plugins in the current one)
```

The generator script reads both files at run time and prints the current
version in the instruction block. If asked to bump the version, always update
both files together.

---

## What this skill does NOT do

- Does not generate evals (descoped, decision D-8).
- Does not build indexes, embeddings, or chunking — whole-file routing plus
  `rg` is the settled design.
- Does not copy or vendor handbook content into this repo.
- Does not commit or push.

---

## Helper script

`skills/handbook-authoring/generate.sh` — the implementation. Run it directly
from the plugin root. Self-contained bash, no external deps beyond `jq` and
standard POSIX tools.
