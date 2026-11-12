# Releasing

Claude Code caches an installed plugin by version, so a push that keeps the same version never reaches installs. Every push to `main` runs [release.yml](../.github/workflows/release.yml), which runs semantic-release with [.releaserc.json](../.releaserc.json). Commit types since the last `v*` tag decide the version.

| Commit | Release |
|---|---|
| `feat` | minor |
| `fix`, `perf`, `refactor` | patch |
| breaking change (`!` or `BREAKING CHANGE`) | minor, while below 1.0 |
| anything else, such as `docs`, `test`, `chore`, `ci` | none |

A release writes the version into [plugin.json](../.claude-plugin/plugin.json) and [marketplace.json](../.claude-plugin/marketplace.json), commits them as `chore(release): <version>`, tags `v<version>` and opens a GitHub release. Don't bump versions by hand.

The release commit is pushed with the workflow's `GITHUB_TOKEN`, which never starts another workflow run, so there is no loop. Branch protection on `main` must let `github-actions` push.
