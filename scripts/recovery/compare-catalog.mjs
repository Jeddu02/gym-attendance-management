// Offline metadata comparison only. Never connects to a database or emits raw metadata.
import { readFileSync, readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

export function verifySourceManifest(manifest) {
  if (!Array.isArray(manifest) || manifest.length !== 37 || new Set(manifest.map(x => x.file)).size !== 37) {
    throw new Error('Complete trusted source manifest required');
  }
  const actual = readdirSync(new URL('../../supabase/migrations/', import.meta.url)).filter(x => x.endsWith('.sql')).sort();
  if (JSON.stringify(actual) !== JSON.stringify(manifest.map(x => x.file).sort())) {
    throw new Error('Migration directory differs from reviewed manifest');
  }
  for (const row of manifest) {
    if (!/^\d{14}_[a-z0-9_]+\.sql$/.test(row.file) || row.version !== row.file.slice(0, 14)
      || !/^[a-f0-9]{64}$/.test(row.sha256)) throw new Error('Invalid source identity');
    const bytes = readFileSync(new URL('../../supabase/migrations/' + row.file, import.meta.url));
    if (createHash('sha256').update(bytes).digest('hex') !== row.sha256) throw new Error('Source changed; reference must be rebuilt');
  }
}

export function validateCatalog(value) {
  if (value?.format !== 1 || value.fingerprintAlgorithm !== 'sha256' || !Number.isInteger(value.serverMajor) || !Array.isArray(value.objects)) {
    throw new Error('Invalid catalog envelope');
  }
  const map = new Map();
  for (const row of value.objects) {
    if (typeof row.key !== 'string' || !/^[a-z]+\|[^\r\n]+$/.test(row.key)
      || !/^[a-f0-9]{64}$/.test(row.fingerprint) || map.has(row.key)) {
      throw new Error('Invalid or duplicate catalog object');
    }
    map.set(row.key, row);
  }
  return map;
}

export function compareCatalog(expected, actual, { engineControl = false } = {}) {
  const reference = validateCatalog(expected), observed = validateCatalog(actual);
  if (reference.size === 0) throw new Error('Empty reference cannot certify a migration stage');
  if (expected.serverMajor !== actual.serverMajor || (!engineControl && actual.serverMajor !== 17)) {
    throw new Error('Matching PostgreSQL 17 catalogs required; engine-control results are separate');
  }
  const counts = { EXACT_METADATA: 0, ABSENT: 0, PRESENT_DIFFERENT: 0, UNEXPECTED: 0 };
  for (const [key, row] of reference) {
    const found = observed.get(key);
    counts[!found ? 'ABSENT' : found.fingerprint === row.fingerprint ? 'EXACT_METADATA' : 'PRESENT_DIFFERENT']++;
  }
  for (const key of observed.keys()) if (!reference.has(key)) counts.UNEXPECTED++;
  return { counts, metadataMatches: counts.ABSENT + counts.PRESENT_DIFFERENT + counts.UNEXPECTED === 0,
    authority: 'NOT_VERIFIED', dataCompatibility: 'NOT_VERIFIED', history: 'NOT_VERIFIED',
    productionDecision: 'HOLD', engineControl };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = process.argv.slice(2), engineControl = args.includes('--engine-control');
    const files = args.filter(x => x !== '--engine-control');
    if (files.length !== 2) throw new Error('Usage: compare-catalog.mjs reference.json observed.json [--engine-control]');
    const load = file => {
      const bytes = readFileSync(file); if (bytes.length > 16 * 1024 * 1024) throw new Error('Catalog size limit');
      return JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
    };
    const expected = load(files[0]); verifySourceManifest(expected.sourceManifest);
    const result = compareCatalog(expected, load(files[1]), { engineControl });
    console.log(JSON.stringify(result)); process.exitCode = result.metadataMatches ? 0 : 1;
  } catch { console.error('HOLD: catalog comparison failed; inspect private inputs locally.'); process.exitCode = 2; }
}
