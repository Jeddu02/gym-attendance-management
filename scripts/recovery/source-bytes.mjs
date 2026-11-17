// Byte-level newline handling only. No SQL, network, hash replacement or BOM removal.
import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const policy = JSON.parse(readFileSync(new URL('./source-byte-policy.json', import.meta.url), 'utf8'));
if (policy.format !== 1 || policy.canonical !== 'git-blob-lf-v1') throw Error('Unsupported byte policy');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');

export function canonicalLf(input) {
  const bytes = Buffer.from(input);
  return Buffer.from(bytes.filter((value, index) => value !== 13 || bytes[index + 1] !== 10));
}

export function legacyBytes(canonical, layout) {
  if (layout !== undefined && layout !== 'all' && (!Array.isArray(layout)
    || layout.some((n, i) => !Number.isInteger(n) || n < 1 || (i && n <= layout[i - 1])))) {
    throw Error('Invalid reviewed newline layout');
  }
  const result = []; let line = 1;
  for (const value of canonical) {
    if (value === 10) {
      if (layout === 'all' || layout?.includes(line)) result.push(13);
      line++;
    }
    result.push(value);
  }
  if (Array.isArray(layout) && layout.some(n => n >= line)) throw Error('Reviewed newline outside source');
  return Buffer.from(result);
}

export function verifyReviewedBytes(input, expectedHash, layout, committedBlob) {
  if (!/^[a-f0-9]{64}$/.test(expectedHash)) throw Error('Invalid reviewed SHA-256');
  const bytes = canonicalLf(input);
  if (committedBlob !== undefined && (!Buffer.from(committedBlob).equals(canonicalLf(committedBlob))
    || !bytes.equals(Buffer.from(committedBlob)))) throw Error('Working content differs from committed LF blob');
  const reviewedBytes = legacyBytes(bytes, layout);
  if (sha(reviewedBytes) !== expectedHash) throw Error('Source content or reviewed fingerprint changed');
  return { bytes, reviewedBytes, canonicalSha256: sha(bytes), gitBlobChecked: committedBlob !== undefined };
}

let gitRoot;
function isRepositoryRoot() {
  if (gitRoot !== undefined) return gitRoot;
  if (!existsSync(resolve(root, '.git'))) return (gitRoot = false);
  const top = execFileSync('git', ['-C', root, 'rev-parse', '--show-toplevel'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  if (realpathSync(top) !== realpathSync(root)) throw Error('Unexpected Git root');
  gitRoot = true;
  return gitRoot;
}

export function readCanonicalSource(file) {
  if (!/^[a-zA-Z0-9_./-]+$/.test(file) || file.split('/').some(x => !x || x === '.' || x === '..')) {
    throw Error('Invalid source path');
  }
  const absolute = resolve(root, file);
  if (!realpathSync(absolute).startsWith(realpathSync(root) + sep)) throw Error('Source escapes root');
  const bytes = canonicalLf(readFileSync(absolute));
  if (isRepositoryRoot()) {
    // If Git is present, a missing object is an error, never an archive fallback.
    const blob = execFileSync('git', ['-C', root, 'show', 'HEAD:' + file],
      { maxBuffer: 4 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
    if (!blob.equals(canonicalLf(blob)) || !blob.equals(bytes)) throw Error('Source differs from committed LF blob');
    return blob;
  }
  // Isolated source archives have no HEAD; callers still enforce the pinned hash.
  return bytes;
}

export function verifyReviewedSource(file, expectedHash) {
  return { ...verifyReviewedBytes(readCanonicalSource(file), expectedHash, policy.legacyCRLF[file]),
    gitBlobChecked: isRepositoryRoot() };
}
