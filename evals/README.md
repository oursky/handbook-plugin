# Trigger evals

These cases measure one thing. Given a realistic prompt, does Claude call the right `handbook:dev-*` skill? A case passes when the Skill tool call for that skill appears in the run's trace. Nothing grades the answer itself.

## Layout

- `evals/<skill>/{keyword,task,indirect}` holds three positive cases per `dev-*` skill. Each one has a prompt that never names the skill or the handbook.
- `evals/_negative/` holds ten cases. Seven are generic coding prompts where no handbook skill should fire. Three are near-misses that should fire skill A and not skill B.
- `handbook-authoring` has no cases. It is a maintenance skill.

Each case runs on sonnet with `runs: 3`, `max_turns: 5` and the tools Read, Glob, Grep and Skill.

## Run it

Always pass `--ablation none`. Under the default with-without ablation, `tool_used: Skill` graders are not scored and read 0.

Full suite, 3 runs per case:

```
claude plugin eval . --runs 3 -j 6 --max-cost-usd 25 --ablation none --no-publish --trust-plugin
```

One case:

```
claude plugin eval . --case 'dev-git-keyword' --runs 1 --ablation none --no-publish --trust-plugin
```

To run one skill, pass `--case 'dev-git-*'`. Add `--keep-temp` to keep the run's `trace.jsonl` for inspection.

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

Read the baseline with care. These prompts are single-turn and the plugin is the only one loaded. A real session has far more skills competing and much more context. The usage log shows the skills firing far less often than this suite does. A high score here means the descriptions are enough in isolation, not that they fire in practice.
