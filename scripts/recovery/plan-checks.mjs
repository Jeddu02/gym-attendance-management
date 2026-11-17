// Offline prerequisite planner. It prints paths/statuses; never executes SQL.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { validateCatalog } from './compare-catalog.mjs';
const pendingVersions = new Set(JSON.parse(readFileSync(new URL('../../supabase/recovery/source-manifest.json', import.meta.url), 'utf8'))
  .migrations.filter(x => !x.recordedInSuppliedHistory).map(x => x.version));
export function planChecks(catalog, checks, { beforeVersion } = {}) {
  const objects = validateCatalog(catalog);
  if (beforeVersion !== undefined && !pendingVersions.has(beforeVersion)) throw new Error('Unreviewed intended stage');
  return checks.map(check => {
    if (check.beforeVersion && beforeVersion === undefined) return { id: check.id, file: check.file, status: 'UNKNOWN' };
    if (check.beforeVersion && beforeVersion > check.beforeVersion) {
      return { id: check.id, file: check.file, status: 'NOT_APPLICABLE_TO_STAGE' };
    }
    const unavailable = check.tables.some(table => {
      const relation = objects.get('relation|private|' + table.name);
      return !relation || relation.readable !== true || relation.filtered !== false
        || table.columns.some(column => !objects.has('column|private|' + table.name + '|' + column));
    });
    return { id: check.id, file: check.file, status: unavailable ? 'UNKNOWN' : 'READY_FOR_OWNER_REVIEW' };
  });
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (![3,4].includes(process.argv.length)) throw new Error('Expected private catalog path and optional intended migration version');
    const bytes = readFileSync(process.argv[2]);
    if (bytes.length > 16 * 1024 * 1024) throw new Error('Catalog size limit');
    const catalog = JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
    const checks = JSON.parse(readFileSync(new URL('../../supabase/recovery/checks.json', import.meta.url), 'utf8'));
    console.log(JSON.stringify(planChecks(catalog, checks, { beforeVersion: process.argv[3] })));
  } catch { console.error('HOLD: prerequisite planning failed; no SQL executed.'); process.exitCode = 2; }
}
