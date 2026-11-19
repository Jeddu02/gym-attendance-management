// Offline source hashes and explicitly locked grammar only; never reads environment files.
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { verifySourceManifest } from './compare-catalog.mjs';
import { verifyReviewedSource } from './source-bytes.mjs';
const require = createRequire(import.meta.url);
try {
  const root = new URL('../../', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('supabase/recovery/source-manifest.json', root), 'utf8'));
  let gitBlobChecks = verifySourceManifest(manifest.migrations).gitBlobChecks;
  for (const [key, count] of [['edgeEntrypoints', 21], ['sharedRuntime', 17]]) {
    const rows = manifest[key];
    if (!Array.isArray(rows) || rows.length !== count || new Set(rows.map(x => x.file)).size !== count) throw new Error('Incomplete runtime manifest');
    for (const row of rows) {
      if (!/^supabase\/functions\/(?:[a-z-]+\/index|_shared\/[a-z-]+)\.ts$/.test(row.file)) throw new Error('Invalid runtime path');
      if (verifyReviewedSource(row.file, row.sha256).gitBlobChecked) gitBlobChecks++;
    }
  }
  const entries = readdirSync(new URL('supabase/functions/', root), { withFileTypes: true })
    .filter(x => x.isDirectory() && x.name !== '_shared').map(x => `supabase/functions/${x.name}/index.ts`).sort();
  const additive = JSON.parse(readFileSync(new URL('supabase/recovery/phase61/source-manifest.json',root),'utf8'));
  const approvedAdditions=['supabase/functions/public-walkin-recovery/index.ts','supabase/functions/_shared/walkin-recovery.ts','src/lib/walkin-recovery-store.ts','supabase/recovery/phase61/001-public-walkin-recovery.sql'];
  if(additive.canonical!=='UTF-8 LF' || JSON.stringify(additive.files.map(row=>row.file).sort())!==JSON.stringify([...approvedAdditions].sort()))throw new Error('Additive inventory drift');
  for(const row of additive.files){
    const text=readFileSync(new URL(row.file,root),'utf8').replaceAll('\r\n','\n');
    if(createHash('sha256').update(text).digest('hex')!==row.sha256)throw new Error('Additive source drift');
  }
  if (JSON.stringify(entries) !== JSON.stringify([...manifest.edgeEntrypoints.map(x => x.file),'supabase/functions/public-walkin-recovery/index.ts'].sort())) throw new Error('Endpoint directory drift');
  for (const major of [17, 18]) {
    const parser = require('./parser.cjs')(major);
    await parser.loadModule();
    let statements = 0;
    for (const migration of manifest.migrations) {
      statements += parser.parseSync(readFileSync(new URL('supabase/migrations/' + migration.file, root), 'utf8').replace(/^\uFEFF/, '')).stmts.length;
    }
    for (const file of ['01-explicit-routine-acls.sql', '02-postgres-future-routine-defaults.sql']) {
      parser.parseSync(readFileSync(new URL('supabase/recovery/proposals/' + file, root), 'utf8'));
    }
    parser.parseSync(readFileSync(new URL('supabase/recovery/phase61/001-public-walkin-recovery.sql',root),'utf8'));
    console.log(`PASS PG${major} grammar: 37 migration files, ${statements} top-level statements, two proposals. Bodies require runtime tests.`);
  }
  console.log('PASS: separate Phase 6.1 LF-canonical additive fingerprints and PG17/18 grammar; original manifests unchanged.');
  console.log(`PASS reviewed SHA-256: 37 migrations, 21 entrypoints, 17 shared runtime modules; ${gitBlobChecks}/75 HEAD blobs checked; ${75-gitBlobChecks}/75 pinned source-archive checks. Explicit legacy-byte layouts; not hosted/history verification.`);
} catch { console.error('HOLD: local source/hash/grammar validation failed; no SQL executed.'); process.exitCode = 2; }
