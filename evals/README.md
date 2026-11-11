# Trigger evals

These cases measure one thing. Given a realistic prompt, does Claude call the right `handbook:dev-*` skill? A case passes when the Skill tool call for that skill appears in the run's trace. Nothing grades the answer itself.

## Layout

- `evals/<skill>/{keyword,task,indirect}` holds three positive cases per `dev-*` skill. Each one has a prompt that never names the skill or the handbook.
- `evals/_negative/` holds ten cases. Seven are generic coding prompts where no handbook skill should fire. Three are near-misses that should fire skill A and not skill B.
- `evals/<skill>/context-*` holds ten cases that start inside a small scaffolded repo. Each gives an instruction rather than a question, like the misses in real sessions.
- `handbook-authoring` has no cases. It is a maintenance skill.

Each case runs on sonnet with `runs: 3` and the tools Read, Glob, Grep and Skill. Context cases also get Bash, Edit and Write, which is why the commands below pass `--scaffold` and `--allow-tools`.

## Run it

Always pass `--ablation none`. Under the default with-without ablation, `tool_used: Skill` graders are not scored and read 0.

Full suite, 3 runs per case:

```
claude plugin eval . --scaffold --allow-tools Bash Edit Write --runs 3 -j 6 --max-cost-usd 25 --ablation none --no-publish --trust-plugin
```

One case:

```
claude plugin eval . --case 'dev-git-keyword' --runs 1 --ablation none --no-publish --trust-plugin
```

To run one skill, pass `--tag dev-git` with the scaffold flags. Add `--keep-temp` to keep the run's `trace.jsonl` for inspection.

Results land in `evals/results/<timestamp>/`. That folder stays untracked.

Do not use skill-creator's trigger eval here. It matches a temporary skill name, not `plugin:skill`, so it reads 0% on plugin skills.

## Baseline

Taken at base commit 626bba2 with no description edits. 3 runs per case, sonnet, 37 cases, $5.77, 6 minutes.

| Group | Pass |
| --- | --- |
| Each `dev-*` skill, 9 positive runs | 9/9, except `dev-human-interface` at 8/9 |
| Generic negatives, 7 cases | 21/21 |
| Near-miss `near-git-vs-security` | 3/3 |
| Near-miss `near-web-vs-hi` | 1/3 |
| Near-miss `near-ci-vs-deploy` | 0/3 |

The first run of the context cases passed 28/30. `dev-git-context-commit-body` fired 1/3 because the `dev-git` description never mentioned commit messages. After adding that, all ten fired 3/3 ($2.77, 2 minutes).

Read these numbers with care. Prompts are single-turn and the plugin is the only one loaded. A real session lists about 44 skills and carries much more context. In real sessions since 2026-11-03, Claude mostly read `~/.cache/oursky-handbook` directly instead of calling the skill, and most handbook-topic prompts got neither. A high score here means the descriptions work in isolation, not that they fire in practice.
