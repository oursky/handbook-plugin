---
name: observability
description: "Observability guidance from Oursky's engineering handbook. Use when asking about logging, OpenTelemetry, k6, uptime, crash logging, otel, or silencing noisy third-party logs."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/observability/index.md — topic overview table; consult to orient, then read the relevant file
- guides/observability/add-otel-metrics.md — how to wire up OTel metrics, required env vars, and cluster-specific OTLP endpoints
- guides/observability/application-logging.md — logging standards for Python and .NET; logger naming, sink routing, sensitive-message handling
- guides/observability/otel-browser.md — browser OTel status (2025), limitations, and viable exporter and auth options
- guides/observability/third-party-log-config.md — how to quiet PgBouncer stats logs and nginx health-check access logs
- guides/observability/uptime-crash-logging.md — Sentry project naming, alert rules, and production uptime monitoring with updown.io
- guides/observability/visualize-k6-results.md — run k6 load tests and view time-series dashboards via InfluxDB + Grafana

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/observability/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/observability/"`
4. `historical-archive/` is deprecated; do not cite files from it.
