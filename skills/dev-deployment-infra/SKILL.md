---
name: dev-deployment-infra
description: "Deployment & infra guidance from Oursky's engineering handbook. Use when asking how to deploy to Kubernetes or the agentic cluster (oursky.dev), host a static site with pageship, set up a reverse proxy, provision GCP block storage, or configure RustFS CORS."
user-invocable: false
---

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- deployment-infra/index.md — cluster environments (agentic, pandawork, oursky.app), Docker registry conventions, VM/k3s setup
- deployment-infra/agentic-provision.md — namespace, database, and block storage provisioning on agentic.oursky.cloud
- deployment-infra/client-deployment.md — hosting and database decision guide for client projects; cloud billing setup for AWS/GCP/Azure
- deployment-infra/gcp-blockstorage.md — GCS bucket provisioning and service account setup for block storage
- deployment-infra/gcp-database.md — Cloud SQL database provisioning and access setup on GCP
- deployment-infra/kubernetes-admin.md — Kubernetes namespace creation and access management
- deployment-infra/pageship-static-hosting.md — deploying static sites with Pageship; pageship.toml config and GitHub Actions workflow
- deployment-infra/resource-permission-control.md — default access control policies for cloud, SSH, K8s, and databases
- deployment-infra/reverse-https-proxy.md — exposing a local server publicly via Kubernetes reverse HTTPS proxy on pandawork.com
- deployment-infra/agentic-k8s.md — the agentic cluster: Tailscale-protected oursky.dev ingress, public ingress via cloudflare-tunnel, ingress classes and TLS, developer and office access
- deployment-infra/rustfs-s3-cors.md — configuring bucket CORS on RustFS (s3.oursky.dev) for browser uploads/downloads via presigned URLs

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/deployment-infra/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/deployment-infra/"`
4. `historical-archive/` is deprecated; do not cite files from it.
