import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
test('malformed integration target refuses before SQL and preserves unrelated artifacts', async () => {
  const root = resolve(import.meta.dirname, '..');
  const invalid = 'invalid-' + randomUUID();
  const fixture = resolve(root, '.cache', 'security-test-' + invalid);
  const sentinel = resolve(fixture, 'http-browser', 'sentinel.txt');
  await mkdir(resolve(fixture, 'http-browser'), { recursive: true });
  await writeFile(sentinel, 'preserve');
  try {
    assert.throws(() => execFileSync(process.execPath, ['scripts/test-persisted-http.mjs', '--compatibility-fixture'], {
      cwd: root, env: { ...process.env, GYMFORCE_TEST_RUN_ID: invalid }, stdio: 'pipe', windowsHide: true,
    }));
    assert.equal(await readFile(sentinel, 'utf8'), 'preserve');
  } finally {
    assert.ok(fixture.startsWith(resolve(root, '.cache') + '\\') || fixture.startsWith(resolve(root, '.cache') + '/'));
    await rm(fixture, { recursive: true, force: true });
  }
});
