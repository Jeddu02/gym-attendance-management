import test from 'node:test';
import assert from 'node:assert/strict';
import { compareCatalog, validateCatalog, verifySourceManifest } from '../scripts/recovery/compare-catalog.mjs';
import { readFileSync } from 'node:fs';
import { planChecks } from '../scripts/recovery/plan-checks.mjs';
import { compareHistory } from '../scripts/recovery/compare-history.mjs';
const row = (key, fingerprint = 'a'.repeat(64)) => ({ key, fingerprint });
const catalog = objects => ({ format: 1, fingerprintAlgorithm: 'sha256', serverMajor: 17, objects });

test('history validates prefix, duplicate, unknown and missing middle versions without certifying SQL bytes', () => {
  const manifest = JSON.parse(readFileSync(new URL('../supabase/recovery/source-manifest.json', import.meta.url), 'utf8')).migrations;
  const versions = manifest.slice(0, 20).map(x => x.version);
  const check = values => compareHistory(manifest, { format: 1, versions: values });
  const result = check(versions);
  assert.equal(result.recordedKnown, 20); assert.equal(result.unrecordedLocal, 17);
  assert.equal(result.orderedPrefix, true); assert.equal(result.differsFromSupplied, 0);
  assert.equal(result.appliedSourceBytes, 'NOT_VERIFIED'); assert.equal(result.productionDecision, 'HOLD');
  assert.equal(check([...versions, versions[0]]).duplicateOccurrences, 1);
  assert.equal(check([...versions, '20990101000000']).unknownVersions, 1);
  assert.equal(check(versions.filter((_, i) => i !== 4)).gaps, 1);
  assert.equal(check([...versions].reverse()).orderedPrefix, true);
  assert.equal(check([]).unrecordedLocal, 37);
  assert.throws(() => check([17])); assert.throws(() => check(['bad']));
  assert.throws(() => compareHistory(manifest, { versions }));
  assert.throws(() => compareHistory(manifest.map((x, i) => i === 0 ? { ...x, version: '20990101000000' } : x), { format: 1, versions }));
});
test('reference source manifest pins all 37 original migration files', () => {
  const manifest = JSON.parse(readFileSync(new URL('../supabase/recovery/source-manifest.json', import.meta.url), 'utf8')).migrations;
  verifySourceManifest(manifest);
  assert.equal(manifest.filter(x => !x.recordedInSuppliedHistory).length, 17);
  assert.throws(() => verifySourceManifest(manifest.slice(1)));
  assert.throws(() => verifySourceManifest(manifest.map((x, i) => i === 0 ? { ...x, sha256: '0'.repeat(64) } : x)));
});
test('reconciliation distinguishes absence, altered definitions, overloads and unexpected objects', () => {
  const expected = catalog([row('routine|api|f(uuid)'), row('policy|private|members|owner'), row('column|private|p|id')]);
  const actual = catalog([row('routine|api|f(uuid)', 'b'.repeat(64)), row('routine|api|f(text)'), row('column|private|p|id')]);
  assert.deepEqual(compareCatalog(expected, actual).counts,
    { EXACT_METADATA: 1, ABSENT: 1, PRESENT_DIFFERENT: 1, UNEXPECTED: 1 });
});
test('exact metadata never implies applied history, correct data or production GO', () => {
  const value = catalog([row('relation|private|members')]);
  assert.equal(compareCatalog(value, value).metadataMatches, true);
  assert.equal(compareCatalog(value, value).productionDecision, 'HOLD');
  assert.equal(compareCatalog(value, value).history, 'NOT_VERIFIED');
});
test('comparison is repeatable and does not mutate inputs', () => {
  const value = catalog([Object.freeze(row('schema|api'))]); Object.freeze(value.objects); Object.freeze(value);
  assert.deepEqual(compareCatalog(value, value), compareCatalog(value, value));
});
test('malformed, duplicate and cross-version snapshots fail closed', () => {
  assert.throws(() => validateCatalog(catalog([row('schema|api'), row('schema|api')])));
  assert.throws(() => validateCatalog(catalog([row('schema|api', 'bad')])));
  assert.throws(() => validateCatalog({ format: 1, serverMajor: 17 }));
  const other = { ...catalog([row('schema|api')]), serverMajor: 18 };
  assert.throws(() => compareCatalog(catalog([]), other));
  assert.throws(() => compareCatalog(catalog([]), catalog([])));
  assert.throws(() => compareCatalog(other, other));
  assert.equal(compareCatalog(other, other, { engineControl: true }).engineControl, true);
});
test('legacy prerequisite planning never approves filtered, denied or missing-column checks', () => {
  const checks = [{ id: 'payment', file: 'review.sql', tables: [{ name: 'payment_records', columns: ['operation_id'] }] }];
  const relation = { ...row('relation|private|payment_records'), readable: true, filtered: false };
  const column = row('column|private|payment_records|operation_id');
  assert.equal(planChecks(catalog([relation, column]), checks)[0].status, 'READY_FOR_OWNER_REVIEW');
  for (const objects of [[], [relation], [{ ...relation, filtered: true }, column], [{ ...relation, readable: false }, column]]) {
    assert.equal(planChecks(catalog(objects), checks)[0].status, 'UNKNOWN');
  }
});
test('migration-only legacy preconditions require explicit stage and do not condemn later valid history', () => {
  const checks = [{ id: 'legacy', file: 'review.sql', beforeVersion: '20261110160000', tables: [] }];
  assert.equal(planChecks(catalog([]), checks)[0].status, 'UNKNOWN');
  assert.equal(planChecks(catalog([]), checks, { beforeVersion: '20261110160000' })[0].status, 'READY_FOR_OWNER_REVIEW');
  assert.equal(planChecks(catalog([]), checks, { beforeVersion: '20261110200000' })[0].status, 'NOT_APPLICABLE_TO_STAGE');
  assert.throws(() => planChecks(catalog([]), checks, { beforeVersion: '../bad' }));
  assert.throws(() => planChecks(catalog([]), checks, { beforeVersion: '20990101000000' }));
});
