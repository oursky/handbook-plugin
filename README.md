# handbook-plugin

Claude Code plugin exposing Oursky's private engineering handbook
(git@github.com:oursky/handbook-dev.git — ~75 Markdown files, ~38 K tokens)
to Claude Code agents as a read-only reference.

**Status: v0.1.0 — skills + sync hook implemented; eval prompts drafted, awaiting human labelling.**

---

## Install

SSH access to `oursky/handbook-dev` is required (the sync hook clones via SSH at session start).

### Quick / per-session (no config changes)

Pass `--plugin-dir` to `claude` for a single session:

```bash
claude --plugin-dir /home/newman/.local/share/handbook-plugin
```

> `--plugin-dir` verified in `claude --help` (CLI 2.1.245): "Load a plugin from a directory or .zip for this session only (repeatable)".

### Persistent (installs to user config)

Register the repo as a local marketplace, then install the plugin:

```bash
claude plugin marketplace add /home/newman/.local/share/handbook-plugin
claude plugin install handbook
```

This works because `.claude-plugin/marketplace.json` declares the `handbook` plugin with `source: "./"`.
Scope defaults to `user`; pass `--scope project` to restrict to one repo.

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `HANDBOOK_CACHE_DIR` | `${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook` | Local cache path for the cloned handbook |
| `HANDBOOK_REPO_URL` | `git@github.com:oursky/handbook-dev.git` | Override the handbook remote (e.g. a fork) |

---

## Architecture

Four layers, no index, no embeddings, no PreToolUse injection.

```
┌─────────────────────────────────────────────────────────┐
│ 1. SessionStart sync                                    │
│    hooks/sync-handbook.sh clones or pulls the handbook  │
│    into HANDBOOK_CACHE_DIR on every session. Never       │
│    exits non-zero — sync failure prints a warning and   │
│    falls back to the cached copy (or notes no cache).   │
├─────────────────────────────────────────────────────────┤
│ 2. Topic-scoped skills (9 total, user-invocable: false) │
│    Each skill covers one handbook section. The model    │
│    routes to the right skill from natural prompts.      │
│                                                         │
│    agentic-engineering  MCP, codebox, agentic provision │
│    deployment-infra     Kubernetes, pageship, GCP       │
│    development          API versioning, Golang, React   │
│    git                  rebase, hotfix, branch naming   │
│    human-interface      frontend styling, UI checklist  │
│    observability        logging, OpenTelemetry, k6      │
│    project-setup        CI/CD, GitHub Actions, Make     │
│    security             secrets, GPG, SOPS, audits      │
│    web                  SEO, URL design, localization   │
├─────────────────────────────────────────────────────────┤
│ 3. Slim TOC + whole-file reads                          │
│    Each skill body identifies the relevant file(s) and  │
│    reads them in full from the cache — no chunking.     │
├─────────────────────────────────────────────────────────┤
│ 4. ripgrep for exact lookups                            │
│    Skills shell out to rg for precise term lookups      │
│    (config values, commands, rule text) within the      │
│    cached handbook tree.                                │
└─────────────────────────────────────────────────────────┘
```

**No PreToolUse injection** (decision D-6): the handbook is a hand-maintained
knowledge base, not a policy engine; no must-not-miss constraints were
identified that warrant intercepting every tool call.

**No index or embeddings** (decision D-2): the handbook is small enough (~38 K
tokens) that whole-file reads are cheap; an embedding pipeline would add
operational overhead with no retrieval-quality gain at this corpus size.

---

## Evals

Eval suites live in `evals/<topic>.json` (one per skill, 86 cases total across 10 files).
A converter script handles the JSON → CLI-native case-dir transformation automatically.

Early-access flag required (CLI 2.1.245):

```bash
export CLAUDE_CODE_WALNUT_SPIRE=1
```

```bash
# List all cases (no API calls)
./evals/run.sh --list

# Run one topic (~7 cases, ~$0.50 at sonnet judge)
./evals/run.sh --topic web

# Run full suite (86 cases, ~$6–7 at sonnet judge)
./evals/run.sh
```

`--ablation none` is applied automatically. The plugin directory must be 755 (not
group-writable); `run.sh` enforces this on its build dir. See `evals/README.md` for the
grader limitation (tool_used cannot assert a specific skill name), labelling workflow, and
cost table.

**All prompts ship with `label: TBD` and `human_labelled: false`.** A human reviewer must
assign `must-fire` / `may-fire` / `must-not-fire` before running evals in CI. Do not use an
LLM to assign labels.

---

## Directory layout

```
handbook-plugin/
  .claude-plugin/
    plugin.json        plugin manifest (name, version, skills, hooks)
  hooks/
    hooks.json         SessionStart hook declaration
    sync-handbook.sh   clone/pull script with graceful fallback
  skills/
    agentic-engineering/SKILL.md
    deployment-infra/SKILL.md
    development/SKILL.md
    git/SKILL.md
    human-interface/SKILL.md
    observability/SKILL.md
    project-setup/SKILL.md
    security/SKILL.md
    web/SKILL.md
  evals/
    README.md               how to run evals
    RESULTS.md              full run results and observations
    run.sh                  converter + runner (JSON → CLI case-dir)
    agentic-engineering.json
    deployment-infra.json
    development.json
    git.json
    human-interface.json
    negatives.json          out-of-scope / must-not-fire prompts
    observability.json
    project-setup.json
    security.json
    web.json
  doc/
    skill-authoring.md      authoring contract for skill contributors
    eval-probe-findings.md  empirical findings on eval mechanics
    OPEN-QUESTIONS.md       pre-implementation questions + resolutions
    research-brief.html     background research on plugin architecture
```

---

## Contributing

**Adding a skill:** follow `doc/skill-authoring.md` exactly — it is the binding
contract for frontmatter, description rules, body template, and eval format.

**Reserved trigger nouns:** each skill owns a set of nouns/phrases; do not
reuse another skill's reserved nouns in a new description. The full table is in
`doc/skill-authoring.md`.
