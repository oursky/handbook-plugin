---
name: dev-agentic-engineering
description: "Agentic engineering guidance from Oursky's engineering handbook. Use when setting up MCP, codebox, or codex, asking about agentic provision or setup routing, or onboarding a new coding agent."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/agentic-engineering/setup-routing.md — VPN, Tailscale exit-node routing, and account prerequisites for using Claude/Codex from Hong Kong without account bans
- guides/agentic-engineering/claude-setup.md — Claude account registration, Claude Code CLI login, and monthly token limits
- guides/agentic-engineering/codex-setup.md — OpenAI Codex account registration, Codex CLI login, HTTP proxy setup for daily use, and token limits
- guides/agentic-engineering/codebox-setup.md — sandboxed agent workflow: Podman host install, codebox config, per-task sandbox creation and cleanup
- guides/agentic-engineering/index.md — topic overview table linking all four setup guides

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/agentic-engineering/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/agentic-engineering/"`
4. `historical-archive/` is deprecated; do not cite files from it.
