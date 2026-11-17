// Explicit, separately locked development tooling. Never fall back to .cache.
const { createRequire } = require('node:module');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const base = path.resolve(__dirname, '../../tools/recovery-parser');
const pinned = { 17: '17.8.2', 18: '18.1.4' };
module.exports = function parserFor(major) {
  if (!Object.hasOwn(pinned, major)) throw Error('Unsupported parser major');
  const lock = JSON.parse(readFileSync(path.join(base, 'package-lock.json'), 'utf8'));
  const alias = `pg${major}`;
  const record = lock.packages[`node_modules/${alias}`];
  if (record?.version !== pinned[major] || !record.integrity?.startsWith('sha512-')) {
    throw Error('Pinned parser lock differs');
  }
  const installed = JSON.parse(readFileSync(path.join(base, 'node_modules', alias, 'package.json'), 'utf8'));
  if (installed.version !== pinned[major]) throw Error('Installed parser version differs; run documented npm ci');
  return createRequire(path.join(base, 'package.json'))(alias);
};
