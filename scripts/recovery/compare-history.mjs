// Offline only. History versions are bookkeeping, never proof of applied SQL bytes.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { verifySourceManifest } from './compare-catalog.mjs';

export function compareHistory(manifest, observed) {
  verifySourceManifest(manifest);
  if (observed?.format !== 1 || !Array.isArray(observed.versions)
    || observed.versions.some(x => typeof x !== 'string' || !/^\d{14}$/.test(x))) {
    throw new Error('Invalid version-only history envelope');
  }
  const versions = manifest.map(x => x.version).sort(), known = new Set(versions);
  const recorded = new Set(observed.versions);
  const duplicateOccurrences = observed.versions.length - recorded.size;
  const unknownVersions = [...recorded].filter(x => !known.has(x)).length;
  const missing = versions.filter(x => !recorded.has(x));
  const latestKnown = versions.filter(x => recorded.has(x)).at(-1);
  const gaps = missing.filter(x => latestKnown && x < latestKnown).length;
  const supplied = new Set(manifest.filter(x => x.recordedInSuppliedHistory).map(x => x.version));
  const differsFromSupplied = [...recorded].filter(x => !supplied.has(x)).length
    + [...supplied].filter(x => !recorded.has(x)).length;
  return { localFiles: versions.length, recordedKnown: [...recorded].filter(x => known.has(x)).length,
    unrecordedLocal: missing.length, duplicateOccurrences, unknownVersions, gaps,
    differsFromSupplied, orderedPrefix: duplicateOccurrences + unknownVersions + gaps === 0,
    appliedSourceBytes: 'NOT_VERIFIED', schemaDrift: 'NOT_VERIFIED', productionDecision: 'HOLD' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.length !== 3) throw new Error('Expected private version-only history JSON path');
    const bytes = readFileSync(process.argv[2]);
    if (bytes.length > 1024 * 1024) throw new Error('History size limit');
    const manifest = JSON.parse(readFileSync(new URL('../../supabase/recovery/source-manifest.json', import.meta.url), 'utf8'));
    const result = compareHistory(manifest.migrations, JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, '')));
    console.log(JSON.stringify(result));
    process.exitCode = result.orderedPrefix ? 0 : 1;
  } catch { console.error('HOLD: history/source validation failed; no SQL executed.'); process.exitCode = 2; }
}
