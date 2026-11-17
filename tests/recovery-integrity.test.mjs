import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { canonicalLf, legacyBytes, verifyReviewedBytes, verifyReviewedSource } from '../scripts/recovery/source-bytes.mjs';

const sha = value => createHash('sha256').update(value).digest('hex');
const lf = Buffer.from('\ufeffSELECT 1;\nSELECT 2;\n');
const crlf = Buffer.from('\ufeffSELECT 1;\r\nSELECT 2;\r\n');

test('LF and CRLF checkouts verify against the same committed LF blob and unchanged legacy digest', () => {
  for (const layout of [undefined, 'all', [2]]) {
    const expected = sha(legacyBytes(lf, layout));
    for (const checkout of [lf, crlf]) {
      const result = verifyReviewedBytes(checkout, expected, layout, lf);
      assert.deepEqual(result.bytes, lf);
      assert.equal(result.canonicalSha256, sha(lf));
      assert.equal(result.gitBlobChecked, true);
    }
  }
});

test('source archive verification retains pinned hashes without a Git dependency', () => {
  for (const checkout of [lf, crlf]) assert.deepEqual(verifyReviewedBytes(checkout, sha(lf)).bytes, lf);
  assert.throws(() => verifyReviewedBytes(Buffer.from('SELECT 9;\n'), sha(lf)));
});

test('working, committed and manifest tampering fail independently', () => {
  const changed = Buffer.from('\ufeffSELECT 9;\nSELECT 2;\n');
  assert.throws(() => verifyReviewedBytes(changed, sha(lf), undefined, lf));
  assert.throws(() => verifyReviewedBytes(lf, sha(lf), undefined, changed));
  assert.throws(() => verifyReviewedBytes(changed, sha(lf), undefined, changed));
  assert.throws(() => verifyReviewedBytes(lf, '0'.repeat(64), undefined, lf));
  assert.throws(() => verifyReviewedBytes(lf, sha(lf), undefined, crlf));
});

test('BOM, spaces, tabs, lone CR, final newline and byte corruption are not ignored', () => {
  for (const input of [Buffer.from('SELECT 1;\nSELECT 2;\n'), Buffer.from('\ufeffSELECT  1;\nSELECT 2;\n'),
    Buffer.from('\ufeffSELECT\t1;\nSELECT 2;\n'), Buffer.from('\ufeffSELECT 1;\rSELECT 2;\n'),
    Buffer.from('\ufeffSELECT 1;\nSELECT 2;'), Buffer.concat([lf, Buffer.from([0xff])])]) {
    assert.throws(() => verifyReviewedBytes(input, sha(lf)));
  }
  assert.deepEqual(canonicalLf(crlf), lf);
  assert.equal(canonicalLf(lf).subarray(0, 3).toString('hex'), 'efbbbf');
});

test('legacy line maps are exact, validated and cannot conceal content changes', () => {
  assert.equal(legacyBytes(lf, [2]).toString(), '\ufeffSELECT 1;\nSELECT 2;\r\n');
  for (const map of [[0], [-1], [2, 1], [1, 1], [3], ['1'], 'guess']) assert.throws(() => legacyBytes(lf, map));
  assert.throws(() => verifyReviewedBytes(crlf, sha(crlf), [2], lf));
});

test('real isolated Git repository checks HEAD and dirty files instead of silently using archive mode', async () => {
  const cache = new URL('../.cache/', import.meta.url);
  mkdirSync(cache, { recursive: true });
  const fixture = mkdtempSync(new URL('integrity-git-', cache));
  mkdirSync(resolve(fixture, 'scripts/recovery'), { recursive: true });
  for (const name of ['source-bytes.mjs', 'source-byte-policy.json']) {
    copyFileSync(new URL('../scripts/recovery/' + name, import.meta.url), resolve(fixture, 'scripts/recovery', name));
  }
  const file = 'fixture.sql';
  writeFileSync(resolve(fixture, file), lf);
  const git = (...args) => execFileSync('git', ['-c', 'core.autocrlf=false', '-c', 'commit.gpgsign=false',
    '-c', 'core.hooksPath=' + resolve(fixture, '.git/hooks'), '-c', 'user.name=Synthetic integrity test',
    '-c', 'user.email=synthetic@example.test', ...args], { cwd: fixture, stdio: 'ignore' });
  git('init', '--quiet'); git('add', '.'); git('commit', '--quiet', '-m', 'synthetic integrity fixture');
  const reader = await import(pathToFileURL(resolve(fixture, 'scripts/recovery/source-bytes.mjs')).href);
  assert.equal(reader.verifyReviewedSource(file, sha(lf)).gitBlobChecked, true);
  writeFileSync(resolve(fixture, file), crlf);
  assert.deepEqual(reader.verifyReviewedSource(file, sha(lf)).bytes, lf);
  writeFileSync(resolve(fixture, file), Buffer.from('SELECT 9;\n'));
  assert.throws(() => reader.verifyReviewedSource(file, sha(lf)), /committed LF blob/);
  git('add', file); git('commit', '--quiet', '-m', 'synthetic unauthorized-content fixture');
  assert.throws(() => reader.verifyReviewedSource(file, sha(lf)), /fingerprint changed/);
});

test('every historical migration and runtime manifest hash is preserved under both checkout encodings', () => {
  const root = new URL('../', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('supabase/recovery/source-manifest.json', root)));
  const policy = JSON.parse(readFileSync(new URL('scripts/recovery/source-byte-policy.json', root)));
  assert.equal(Object.keys(policy.legacyCRLF).length, 18);
  let count = 0;
  for (const key of ['migrations', 'edgeEntrypoints', 'sharedRuntime']) for (const row of manifest[key]) {
    const file = (key === 'migrations' ? 'supabase/migrations/' : '') + row.file;
    const verified = verifyReviewedSource(file, row.sha256);
    const canonical = verified.bytes;
    // A clean-room source archive intentionally has no .git. The same digest
    // contract must still be tested; live repository runs also check HEAD blobs.
    const blob = verified.gitBlobChecked ? execFileSync('git', ['show', 'HEAD:' + file], { cwd: root }) : undefined;
    for (const input of [canonical, legacyBytes(canonical, 'all')]) {
      assert.deepEqual(verifyReviewedBytes(input, row.sha256, policy.legacyCRLF[file], blob).bytes, canonical);
    }
    const tampered = Buffer.concat([canonical, Buffer.from('-- unauthorized content\n')]);
    assert.throws(() => verifyReviewedBytes(tampered, row.sha256, policy.legacyCRLF[file], blob));
    count++;
  }
  assert.equal(count, 75);
});
