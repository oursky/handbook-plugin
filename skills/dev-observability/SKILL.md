---
name: dev-observability
description: "Observability guidance from Oursky's engineering handbook. Use when asking about logging, OpenTelemetry, k6, uptime, crash logging, otel, or silencing noisy third-party logs."
user-invocable: false
---

<!-- handbook-reviewed: 1c3dd2357955afc271439d6956871fd1deab984e -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- observability/index.md — topic overview table; consult to orient, then read the relevant file
- observability/add-otel-metrics.md — how to wire up OTel metrics, required env vars, and cluster-specific OTLP endpoints
- observability/application-logging.md — logging standards for Python; logger naming, sink routing, sensitive-message handling
- observability/otel-browser.md — browser OTel status (2025), limitations, and viable exporter and auth options
- observability/third-party-log-config.md — how to quiet PgBouncer stats logs and nginx health-check access logs
- observability/uptime-crash-logging.md — Sentry project naming, alert rules, and production uptime monitoring with updown.io
- observability/visualize-k6-results.md — run k6 load tests and view time-series dashboards via InfluxDB + Grafana

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/observability/`.
   Do not excerpt or paraphrase from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/observability/"`
