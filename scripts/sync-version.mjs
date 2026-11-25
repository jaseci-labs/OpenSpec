#!/usr/bin/env node
// neojac writes package.json from jac.toml, so a version that npm or changesets
// writes into package.json is carried back into jac.toml's [npm."."] table here.
import { readFileSync, writeFileSync } from 'node:fs';

const { version } = JSON.parse(readFileSync('package.json', 'utf8'));
const toml = readFileSync('jac.toml', 'utf8');
const table = toml.indexOf('[npm."."]');
const end = toml.indexOf('\n[', table + 1);
const head = toml.slice(table, end === -1 ? undefined : end);
const next = head.replace(/^version = ".*"$/m, `version = ${JSON.stringify(version)}`);
if (next === head && !head.includes(`version = ${JSON.stringify(version)}`)) {
  throw new Error('jac.toml has no version in its [npm."."] table');
}
writeFileSync('jac.toml', toml.slice(0, table) + next + (end === -1 ? '' : toml.slice(end)));
console.log(`jac.toml version: ${version}`);
