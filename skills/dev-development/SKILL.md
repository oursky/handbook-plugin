---
name: dev-development
description: "Development guidance from Oursky's engineering handbook. Use when asking about API versioning, Golang SSRF, Python or React rules, WordPress setup, dogpile caching, or non-breaking changes."
user-invocable: false
---

<!-- handbook-reviewed: 2b4ec2b12888e9476357b2dbfccfab00d46ad1da -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- development/deprecating-api.md — six-step workflow for deprecating an API version without breaking existing clients
- development/hard-technical-requirements.md — non-negotiable requirements that apply to all projects regardless of client pressure
- development/harden-golang-http-client.md — how to prevent SSRF in a Golang HTTP client used for webhook delivery
- development/index.md — topic overview table; consult to orient, then read the relevant file above
- development/mcp.md — Python MCP server tech stack reference (libraries and architecture choices)
- development/non-breaking-changes.md — how to change function or API behavior without breaking existing callers
- development/python-caching-dogpile.md — dogpile.cache patterns for Python backend caching, avoiding thundering herd
- development/python.md — Oursky's default Python tech stack and library choices for backend and CLI projects
- development/testing-approaches.md — when and how to use example-based vs property-based testing
- development/wordpress-setup.md — WordPress server stack and setup best practices
- development/must-support-multiple-email-providers.md — send mail through a sender interface (console, Slack, SendGrid, SMTP) with default providers per environment
- development/react.md — default React + TypeScript stack (Tailwind, pnpm, Vite, Vitest, React Router, TanStack Query, React Hook Form, Zod) and usage rules

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/development/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/development/"`
4. `historical-archive/` is deprecated; do not cite files from it.
