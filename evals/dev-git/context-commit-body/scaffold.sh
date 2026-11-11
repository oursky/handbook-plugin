#!/usr/bin/env bash
set -euo pipefail
git init -q -b main
git config user.email dev@example.com
git config user.name Dev
mkdir -p src .github/workflows
cat > package.json <<'JSON'
{
  "name": "orders-service",
  "private": true,
  "scripts": { "dev": "node src/server.js", "test": "node --test", "lint": "eslint src" },
  "dependencies": { "express": "4.19.2", "pino": "9.3.2" },
  "devDependencies": { "eslint": "9.9.0" }
}
JSON
cat > src/server.js <<'JS'
const express = require("express");
const app = express();
app.get("/v1/orders", (req, res) => res.json([]));
app.get("/healthz", (req, res) => res.send("ok"));
app.listen(process.env.PORT || 3000);
JS
cat > Makefile <<'MK'
.PHONY: dev test
dev:
	npm run dev
test:
	npm test
MK
cat > .github/workflows/ci.yml <<'YML'
name: ci
on: [pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
YML
printf '# orders-service

Small Express service for order lookups.
' > README.md
printf 'DATABASE_URL=postgres://orders:s3cret@db.internal:5432/orders
STRIPE_KEY=sk_live_example
' > .env.production
printf 'node_modules/
' > .gitignore
git add -A
git commit -q -m "Initial orders service"
echo "// TODO" >> src/server.js
git commit -q -am "Add placeholder"
git commit -q --allow-empty -m "Add order export

This adds an export endpoint so finance can pull orders as CSV. The business
case is described in the Q3 planning doc and the user story is in the ticket.

Refs #42"
