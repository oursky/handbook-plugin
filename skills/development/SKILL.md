---
name: development
description: "Development guidance from Oursky's engineering handbook. Use when asking about API versioning, Golang SSRF, Python or React rules, WordPress setup, dogpile caching, or non-breaking changes."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/development/deprecating-api.md — six-step workflow for deprecating an API version without breaking existing clients
- guides/development/hard-technical-requirements.md — non-negotiable requirements that apply to all projects regardless of client pressure
- guides/development/harden-golang-http-client.md — how to prevent SSRF in a Golang HTTP client used for webhook delivery
- guides/development/index.md — topic overview table; consult to orient, then read the relevant file above
- guides/development/mcp.md — Python MCP server tech stack reference (libraries and architecture choices)
- guides/development/non-breaking-changes.md — how to change function or API behavior without breaking existing callers
- guides/development/python-caching-dogpile.md — dogpile.cache patterns for Python backend caching, avoiding thundering herd
- guides/development/python.md — Oursky's default Python tech stack and library choices for backend and CLI projects
- guides/development/react-best-practices.md — company-specific React conventions that differ from community defaults
- guides/development/testing-approaches.md — when and how to use example-based vs property-based testing
- guides/development/wordpress-setup.md — WordPress server stack and setup best practices

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/development/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/development/"`
4. `historical-archive/` is deprecated; do not cite files from it.
