---
name: deployment-infra
description: "Deployment & infra guidance from Oursky's engineering handbook. Use when asking how to deploy to Kubernetes, host a static site with pageship, set up a reverse proxy, or provision GCP block storage."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- guides/deployment-infra/index.md — cluster environments (agentic, pandawork, oursky.app), Docker registry conventions, VM/k3s setup
- guides/deployment-infra/agentic-provision.md — namespace, database, and block storage provisioning on agentic.oursky.cloud
- guides/deployment-infra/client-deployment.md — hosting and database decision guide for client projects; cloud billing setup for AWS/GCP/Azure
- guides/deployment-infra/gcp-blockstorage.md — GCS bucket provisioning and service account setup for block storage
- guides/deployment-infra/gcp-database.md — Cloud SQL database provisioning and access setup on GCP
- guides/deployment-infra/kubernetes-admin.md — Kubernetes namespace creation and access management
- guides/deployment-infra/pageship-static-hosting.md — deploying static sites with Pageship; pageship.toml config and GitHub Actions workflow
- guides/deployment-infra/resource-permission-control.md — default access control policies for cloud, SSH, K8s, and databases
- guides/deployment-infra/reverse-https-proxy.md — exposing a local server publicly via Kubernetes reverse HTTPS proxy on pandawork.com

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/guides/deployment-infra/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/guides/deployment-infra/"`
4. `historical-archive/` is deprecated; do not cite files from it.
