# handbook-plugin

Claude Code plugin exposing Oursky's private handbooks
to Claude Code agents as a read-only reference.

**Status: v0.2.0 — multi-handbook support; `dev-*` skill rename (breaking).**

---

## BREAKING CHANGE from v0.1.0

**The nine `handbook-dev` skills have been renamed with a `dev-` prefix.**
The old un-prefixed directories (`agentic-engineering/`, `deployment-infra/`, etc.)
no longer exist. There are no alias shims. If you have v0.1.0 installed, the
old skill names will stop resolving after the upgrade.

Old name → new name:

| v0.1.0 | v0.2.0 |
|--------|--------|
| `handbook:agentic-engineering` | `handbook:dev-agentic-engineering` |
| `handbook:deployment-infra` | `handbook:dev-deployment-infra` |
| `handbook:development` | `handbook:dev-development` |
| `handbook:git` | `handbook:dev-git` |
| `handbook:human-interface` | `handbook:dev-human-interface` |
| `handbook:observability` | `handbook:dev-observability` |
| `handbook:project-setup` | `handbook:dev-project-setup` |
| `handbook:security` | `handbook:dev-security` |
| `handbook:web` | `handbook:dev-web` |

---

## Install

SSH access to `oursky/handbook-dev` and `oursky/os-project-management` is required
(the sync hook clones via SSH at session start).

**Dependency: `jq`** — the sync hook and the authoring skill both require `jq` to parse
`handbooks.json`. If `jq` is absent, the hook warns and exits without syncing anything.
Install with `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu).

### Quick / per-session (no config changes)

Pass `--plugin-dir` to `claude` for a single session:

```bash
claude --plugin-dir <path-to-plugin-repo>
```

> `--plugin-dir` verified in `claude --help` (CLI 2.1.245): "Load a plugin from a directory or .zip for this session only (repeatable)".

### Persistent (installs to user config)

Register the repo as a local marketplace, then install the plugin:

```bash
claude plugin marketplace add <path-to-plugin-repo>
claude plugin install handbook
```

This works because `.claude-plugin/marketplace.json` declares the `handbook` plugin with `source: "./"`.
Scope defaults to `user`; pass `--scope project` to restrict to one repo.

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `HANDBOOK_CACHE_DIR` | `${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook` | Cache root; each handbook syncs into `<cache-root>/<id>/` |

`HANDBOOK_REPO_URL` from v0.1.0 is retired — use `handbooks.json` to declare repos.

---

## Handbooks declared (`handbooks.json`)

```json
{
  "handbooks": [
    {
      "id": "dev",
      "url": "git@github.com:oursky/handbook-dev.git",
      "topic_root": "guides/",
      "depth": 1,
      "label": "Oursky engineering handbook"
    },
    {
      "id": "pm",
      "url": "git@github.com:oursky/os-project-management.git",
      "topic_root": "usage-guide/",
      "depth": 0,
      "label": "Oursky PM workflow handbook"
    }
  ]
}
```

Field meanings:

| Field | Purpose |
|---|---|
| `id` | Unique identifier; used as the skill-name prefix (`dev-git`, `pm-usage-guide`) and as the cache subdirectory name |
| `url` | SSH clone URL for the handbook repo |
| `topic_root` | Path within the repo that contains topic directories |
| `depth` | Directory depth under `topic_root` at which topics live (`0` = topic_root is itself the single topic, `1` = immediate subdirs) |
| `label` | Human-readable corpus name; feeds clause 1 of every generated skill description (e.g. "… from Oursky engineering handbook") so cross-handbook disambiguation works from the description alone |

To add a third handbook, add one entry to this file. No shell script edits are required.

---

## Cache layout

Each declared handbook is synced into its own subdirectory:

```
${HANDBOOK_CACHE_DIR}/
  dev/          ← oursky/handbook-dev checkout
    guides/
      git/
        git-workflow.md
      ...
  pm/           ← oursky/os-project-management checkout
    usage-guide/
      ...
```

A v0.1.0 installation left the `handbook-dev` checkout flat at the cache root
(`.git` directly under `oursky-handbook/`). The sync hook detects this, prints one
warning naming the stale path, and clones into `<root>/dev/` regardless. It never
deletes the old checkout.

---

## Architecture

Four layers, no index, no embeddings, no PreToolUse injection.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SessionStart sync                                        │
│    hooks/sync-handbook.sh reads handbooks.json (requires    │
│    jq) and clones or fast-forward pulls each handbook into  │
│    <HANDBOOK_CACHE_DIR>/<id>/. Partial failure warns and    │
│    keeps that handbook's stale cache; others still sync.    │
│    Never exits non-zero.                                    │
├─────────────────────────────────────────────────────────────┤
│ 2. Topic-scoped skills (11 total, user-invocable: false     │
│    except handbook-authoring)                               │
│    Each skill covers one handbook section or corpus.        │
│    The model routes to the right skill from natural prompts.│
│                                                             │
│    dev-agentic-engineering  MCP, codebox, agentic provision │
│    dev-deployment-infra     Kubernetes, pageship, GCP       │
│    dev-development          API versioning, Golang, React   │
│    dev-git                  rebase, hotfix, branch naming   │
│    dev-human-interface      frontend styling, UI checklist  │
│    dev-observability        logging, OpenTelemetry, k6      │
│    dev-project-setup        CI/CD, GitHub Actions, Make     │
│    dev-security             secrets, GPG, SOPS, audits      │
│    dev-web                  SEO, URL design, localization   │
│    pm-usage-guide           PM workflow tools and skills    │
│    handbook-authoring       generates per-topic skills      │
├─────────────────────────────────────────────────────────────┤
│ 3. Slim TOC + whole-file reads                              │
│    Each skill body identifies the relevant file(s) and      │
│    reads them in full from the cache — no chunking.         │
├─────────────────────────────────────────────────────────────┤
│ 4. ripgrep for exact lookups                                │
│    Skills shell out to rg for precise term lookups          │
│    (config values, commands, rule text) within the          │
│    cached handbook tree.                                    │
└─────────────────────────────────────────────────────────────┘
```

**No PreToolUse injection** (decision D-6): the handbook is a hand-maintained
knowledge base, not a policy engine; no must-not-miss constraints were
identified that warrant intercepting every tool call.

**No index or embeddings** (decision D-2): the handbook is small enough that
whole-file reads are cheap; an embedding pipeline would add operational overhead
with no retrieval-quality gain at this corpus size.

---

## Adding or regenerating skills (`handbook-authoring`)

Skills are generated at authoring time, not at runtime. The `handbook-authoring`
skill (`user-invocable: true`) reads `handbooks.json` and the synced caches and
writes `skills/<id>-<topic>/SKILL.md` files into this repo.

### Workflow

```
1. Invoke the handbook-authoring skill in Claude Code
   (it reads handbooks.json + cache; writes skills/<id>-<topic>/SKILL.md)

2. Review the diff
   Check generated descriptions; the skill never overwrites an existing
   description: line, so a human-reviewed description is never silently lost.
   Edit any description you want to tune before committing.

3. Commit and reload
   See reload instructions below.
```

### Reload after adding or regenerating skills

The correct reload steps depend on how the plugin is loaded.

**If using `--plugin-dir`** — no version bump needed:

```
Start a new Claude Code session with --plugin-dir <path>.
Or run /reload-plugins within your current session.
```

**If installed via marketplace** (`claude plugin install handbook`) — version bump required
because marketplace-installed plugins load from a frozen per-version cache:

```
1. Bump "version" in .claude-plugin/plugin.json
2. Bump "version" in .claude-plugin/marketplace.json  (must match)
3. Commit and push
4. Run: claude plugin update handbook
5. Start a new session (or /reload-plugins in the current one)
```

### `--threshold` and `--check` flags

The authoring skill accepts:

- `--threshold N` (default 3): topics with fewer than N `.md` files are skipped and reported rather than generating a skill.
- `--check`: report within-handbook duplicate trigger nouns and cross-handbook near-duplicates without writing any files.

---


## Directory layout

```
handbook-plugin/
  .claude-plugin/
    plugin.json        plugin manifest (name, version, skills, hooks)
    marketplace.json   local marketplace declaration
  handbooks.json       declared handbooks (id, url, topic_root, depth, label)
  hooks/
    hooks.json         SessionStart hook declaration
    sync-handbook.sh   clone/pull script; reads handbooks.json; requires jq
  skills/
    dev-agentic-engineering/SKILL.md
    dev-deployment-infra/SKILL.md
    dev-development/SKILL.md
    dev-git/SKILL.md
    dev-human-interface/SKILL.md
    dev-observability/SKILL.md
    dev-project-setup/SKILL.md
    dev-security/SKILL.md
    dev-web/SKILL.md
    pm-usage-guide/SKILL.md
    handbook-authoring/SKILL.md   (user-invocable: true; generates the above)
  doc/
    skill-authoring.md      authoring contract; one trigger-noun table per handbook
    research-brief.html     background research on plugin architecture
```

## Contributing

**Adding a handbook:** add one entry to `handbooks.json`, run the sync hook,
then invoke the `handbook-authoring` skill to generate topic skills.

**Adding a skill:** invoke `handbook-authoring` against the synced cache, review
the generated `skills/<id>-<topic>/SKILL.md`, and follow the reload workflow above.

**Authoring contract:** see `doc/skill-authoring.md` — it is the binding contract
for frontmatter, description rules, body template, and trigger-noun tables.
Each handbook has its own reserved-trigger-noun table; nouns must be disjoint within
a handbook. Cross-handbook overlap is resolved by naming the corpus in clause 1 of
the skill description (the `label` field supplies this phrase).
