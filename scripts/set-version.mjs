#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const version = process.argv[2];
if (!/^\d+\.\d+\.\d+(-[\w.]+)?$/.test(version ?? '')) {
  console.error('usage: set-version.mjs <semver>');
  process.exit(1);
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const file of ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json']) {
  const path = join(root, file);
  const text = readFileSync(path, 'utf8');
  const field = /("version":\s*)"[^"]*"/;
  if (!field.test(text)) {
    console.error(`${file}: no "version" field`);
    process.exit(1);
  }
  writeFileSync(path, text.replace(field, `$1"${version}"`));
}
