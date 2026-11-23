#!/usr/bin/env node
// Source-only release inventory. Never connects to or changes Supabase.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const migrationDir = join(root, 'supabase/migrations');
const functionDir = join(root, 'supabase/functions');
const migrations = readdirSync(migrationDir).filter(name => /^\d{14}_.+\.sql$/.test(name)).sort();
const functions = readdirSync(functionDir, { withFileTypes: true })
  .filter(entry => entry.isDirectory() && !entry.name.startsWith('_'))
  .map(entry => entry.name).sort();
const problems = [];
if (migrations.length !== 37) problems.push('Expected 37 versioned migration sources');
if (new Set(migrations.map(name => name.slice(0, 14))).size !== migrations.length) problems.push('Duplicate migration timestamp');
if (functions.length !== 22) problems.push('Expected 22 Edge Function directories');
for (const name of functions) {
  const entrypoint = join(functionDir, name, 'index.ts');
  try {
    if (!readFileSync(entrypoint, 'utf8').trim()) problems.push('Empty Edge entrypoint: ' + name);
  } catch {
    problems.push('Missing Edge entrypoint: ' + name);
  }
}
console.log('GYMFORCE release source inventory');
console.log('Migration files:', migrations.length);
console.log('Edge Functions:', functions.length);
console.log('Owner/developer permissions require separate server-side verification.');
console.log('This check does not verify hosted migrations, deployments, or database backup.');
if (problems.length) {
  for (const issue of problems) console.error('FAIL:', issue);
  process.exitCode = 1;
} else console.log('PASS: expected source inventory is present');
