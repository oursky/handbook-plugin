---
name: dev-security
description: "Security guidance from Oursky's engineering handbook. Use when asking about secrets, GPG, SOPS, incident response, package audit, secure SDLC, maintaining a dormant codebase, or how to keep a new project secure."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- security/gpg-sops-secrets.md — how to encrypt repo secrets with GPG + SOPS; file naming convention, .sops.yaml setup, key rotation, and remote key custody via keyservice
- security/package-audit-scanning.md — dependency vulnerability auditing (`make audit` / `make security`) with language-specific tooling for Python, Go, JS/TS, .NET, Ruby, Android, iOS
- security/secure-project-setup.md — foundational security controls for new projects: .gitignore, .dockerignore, CI validation, TLS minimums, mobile secure storage and cert pinning
- security/index.md — topic overview table (consult to orient, then read the relevant file above)
- security/maintenance-project.md — maintenance checklist for projects not under active development: runtime/dependency/k8s updates, OWASP Top 10 report, version selection vs EOL
- security/secure-sdlc.md — secure SDLC for active projects: per-sprint minor upgrades, agent-flagged major upgrades, immediate response to high-impact CVEs

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/security/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/security/"`
4. `historical-archive/` is deprecated; do not cite files from it.
