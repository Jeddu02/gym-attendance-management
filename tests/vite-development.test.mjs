import assert from 'node:assert/strict';
import { once } from 'node:events';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { mkdir, writeFile, unlink } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import test from 'node:test';
import { createServer, resolveConfig } from 'vite';

test('real Vite serves CSS and the SDK without watching generated private test artifacts', { timeout: 30000 }, async () => {
  const root = resolve(import.meta.dirname, '..');
  const name = `phase56-watch-${randomUUID()}.ts`;
  const source = resolve(root, 'src', name);
  const artifact = resolve(root, '.cache', name);
  const events = [];
  const server = await createServer({ root, server: { host: '127.0.0.1', port: 0 }, logLevel: 'error' });
  try {
    const ready = once(server.watcher, 'ready', { signal: AbortSignal.timeout(10000) });
    await server.listen();
    await ready;
    server.watcher.on('all', (_event, path) => events.push(resolve(path)));
    const origin = `http://127.0.0.1:${server.httpServer.address().port}`;
    const get = async path => {
      const response = await fetch(origin + path, { signal: AbortSignal.timeout(10000) });
      assert.equal(response.status, 200, path);
      return response.text();
    };
    const css = await get('/src/style.css');
    assert.ok(css.includes('--color-bg'), 'Serve the actual stylesheet');
    const module = await get('/src/lib/supabase.ts');
    const sdk = module.match(/from\s+["']([^"']*\/deps\/@supabase_supabase-js\.js[^"']*)["']/)?.[1];
    assert.ok(sdk, 'Resolve the actual browser SDK through Vite');
    const sdkModule = await get(sdk);
    assert.ok(sdkModule.includes('createClient'));
    await mkdir(resolve(root, '.cache'), { recursive: true });
    await writeFile(artifact, '// synthetic ignored artifact\n');
    const defaults = await resolveConfig({ configFile: false, logLevel: 'silent' }, 'serve');
    for (const rule of defaults.server.fs.deny) assert.ok(server.config.server.fs.deny.includes(rule), 'Keep every installed Vite default deny rule');
    for (const path of [`/.cache/${name}`, `/@fs/${artifact.split('\\').join('/')}`, `/.cache/${name}?raw`, `/.cache/${name}?raw&import`, `/.CACHE/${name}`]) {
      const response = await fetch(origin + path, { signal: AbortSignal.timeout(10000) });
      const body = await response.text();
      // Vite can reject a denied file with 403 or let its SPA fallback serve
      // index.html with 200. Neither response may disclose the artifact.
      assert.equal(body.includes('// synthetic ignored artifact'), false, `Private artifact leaked at ${path}`);
      if (response.status === 200) {
        assert.match(response.headers.get('content-type') ?? '', /^text\/html(?:;|$)/i,
          `Only an HTML SPA fallback may return 200 for ${path}`);
        assert.match(body, /<html\\b/i, `Expected HTML fallback for ${path}`);
        assert.match(body, /<div\\s+id=["']root["']/i, `Expected app shell for ${path}`);
      } else {
        assert.ok([403, 404].includes(response.status),
          `Unexpected private artifact response ${response.status} for ${path}`);
      }
    }
    await writeFile(source, '// synthetic source watch probe\n');
    const deadline = Date.now() + 5000;
    while (!events.includes(source) && Date.now() < deadline) await delay(50);
    assert.ok(events.includes(source), 'Real source-file events must still arrive');
    await delay(500);
    assert.equal(events.includes(artifact), false, 'Generated private artifacts must not emit watcher events');
  } finally {
    await server.close();
    await Promise.all([source, artifact].map(path => unlink(path).catch(error => { if (error.code !== 'ENOENT') throw error; })));
  }
});
