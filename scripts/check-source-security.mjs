import { readFile, readdir } from 'node:fs/promises';
import { resolve, relative } from 'node:path';
import { pathToFileURL } from 'node:url';

// This is a deliberately conservative source regression gate, not a JS/TOML
// parser, credential scanner, authorization proof, or hosted configuration test.
// New caching strategies and authentication architectures require human review.
// Diagnostics contain rule names/paths only: never print source or key values.
export function checkConfig(text) {
  const issues = [];
  const sections = new Map();
  let section = new Map(); // TOML permits root keys such as project_id.
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    if (line.startsWith('[')) {
      const match = /^\[([\w.-]+)\]\s*(?:#.*)?$/.exec(line);
      if (!match || sections.has(match[1])) {
        issues.push('config-section-unsupported-or-duplicate');
        section = undefined;
        continue;
      }
      section = new Map();
      sections.set(match[1], section);
      continue;
    }
    const setting = /^(\w+)\s*=\s*(.*?)\s*(?:#.*)?$/.exec(line);
    if (!setting || !section) {
      issues.push('config-setting-unsupported');
      continue;
    }
    if (section.has(setting[1])) issues.push('config-setting-duplicate');
    section.set(setting[1], setting[2]);
  }
  const api = sections.get('api');
  // JSON's quoted one-line array is the supported TOML subset for schemas.
  let schemas;
  try { schemas = JSON.parse(api?.get('schemas') ?? 'null'); } catch { /* fail closed below */ }
  if (!Array.isArray(schemas) || schemas.length !== 1 || schemas[0] !== 'api') {
    issues.push('config-api-schema-allowlist');
  }
  if (api?.get('auto_expose_new_tables') !== 'false') issues.push('config-auto-exposure');
  for (const name of ['auth', 'auth.email', 'auth.sms']) {
    if (sections.get(name)?.get('enable_signup') !== 'false') issues.push(`config-signup:${name}`);
  }
  if (sections.get('auth')?.get('enable_anonymous_sign_ins') !== 'false') {
    issues.push('config-anonymous-signin');
  }
  return issues;
}

export function checkBrowserSource(text) {
  const issues = [];
  // Scan names anywhere, including dynamic/computed access and string assembly
  // when the full dangerous name is present. Obfuscated names are out of scope.
  if (/VITE_[A-Z0-9_]*(?:SECRET|SERVICE_ROLE|PRIVATE_KEY|DATABASE_PASSWORD|DB_PASSWORD|TOKEN)/.test(text)) {
    issues.push('browser-privileged-environment-name');
  }
  if (/\bsb_secret_[A-Za-z0-9_-]{8,}/.test(text)) issues.push('browser-secret-key-literal');
  for (const match of text.matchAll(/\beyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+/g)) {
    try {
      if (JSON.parse(Buffer.from(match[1], 'base64url').toString()).role === 'service_role') {
        issues.push('browser-service-role-jwt-literal');
      }
    } catch { /* malformed JWT is not classified as a privileged JWT */ }
  }
  if (/\.\s*(?:signUp|signInAnonymously)\s*\(/.test(text)) issues.push('browser-public-account-creation');
  if (/\.\s*schema\s*\(\s*['"]private['"]\s*\)/.test(text)) issues.push('browser-private-schema');
  if (/\b(?:localStorage|sessionStorage|indexedDB|caches)\s*(?:\.|\[)/.test(text)) {
    issues.push('browser-persistence-requires-review');
  }
  return [...new Set(issues)];
}

export function checkPwaSource(text) {
  const issues = [];
  // Default VitePWA precaches the built shell only. Any custom runtime cache,
  // worker or external precache is blocked until separately reviewed.
  if (/\b(?:runtimeCaching|additionalManifestEntries|manifestTransforms|importScripts|injectManifest|swSrc)\s*:/.test(text) ||
      /\bstrategies\s*:\s*['"]injectManifest['"]/.test(text)) {
    issues.push('pwa-custom-caching-requires-review');
  }
  return issues;
}

export function checkOwnerHandler(text, { registrationService = false } = {}) {
  const issues = [];
  // Structural tripwires only. Presence does not establish control flow or the
  // correctness of denial branches, RPC grants, RLS, token validation or actors.
  if (!/\.auth\.getUser\s*\(/.test(text)) issues.push('owner-auth-validation-marker-missing');
  const actors = [...text.matchAll(/p_(?:actor_)?user_id\s*:\s*([^,}\n]+)/g)].map((match) => match[1].trim());
  if (actors.length === 0) issues.push('owner-actor-wiring-marker-missing');
  for (const actor of actors) {
    const directVerifiedUser = /^(?:authData|userData|data)\.user\.id$/.test(actor);
    const registrationAdapter = registrationService && /^(?:userId|input\.actorUserId)$/.test(actor);
    if (!directVerifiedUser && !registrationAdapter) issues.push('owner-actor-wiring-requires-review');
  }
  return [...new Set(issues)];
}

async function sourceFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error('Source symlinks require review');
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) files.push(...await sourceFiles(path));
    else if (/\.(?:[cm]?[jt]sx?|html|svg)$/.test(entry.name)) files.push(path);
  }
  return files;
}

export async function inspectSourceSecurity(root) {
  const results = [];
  async function inspect(path, check) {
    const issues = check(await readFile(path, 'utf8'));
    results.push(...issues.map((rule) => ({ path: relative(root, path).replaceAll('\\', '/'), rule })));
  }
  await inspect(resolve(root, 'supabase/config.toml'), checkConfig);
  await inspect(resolve(root, 'vite.config.ts'), checkPwaSource);
  for (const folder of ['src', 'public']) {
    for (const path of await sourceFiles(resolve(root, folder))) await inspect(path, checkBrowserSource);
  }
  await inspect(resolve(root, 'index.html'), checkBrowserSource);
  for (const entry of await readdir(resolve(root, 'supabase/functions'), { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.startsWith('owner-')) continue;
    await inspect(resolve(root, 'supabase/functions', entry.name, 'index.ts'),
      (text) => checkOwnerHandler(text, { registrationService: entry.name === 'owner-register-member' }));
  }
  return results;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const results = await inspectSourceSecurity(resolve(import.meta.dirname, '..'));
    for (const result of results) console.error(`${result.path}: ${result.rule}`);
    if (results.length) process.exitCode = 1;
    else console.log('PASS: static source boundary regression checks. Runtime authorization, RLS, migration execution and hosted configuration remain unverified. Environment files are never read.');
  } catch {
    console.error('Source security check could not complete; inspect expected source paths. No file contents are reported.');
    process.exitCode = 1;
  }
}
