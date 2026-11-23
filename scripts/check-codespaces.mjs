// Read-only prerequisite discovery. Never loads .env, starts services or prints secrets.
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const config = JSON.parse(readFileSync(resolve(root, '.devcontainer/devcontainer.json'), 'utf8'));
if (config.remoteUser !== 'node' || JSON.stringify(config.forwardPorts) !== '[5173]'
    || config.otherPortsAttributes?.onAutoForward !== 'ignore'
    || config.customizations?.vscode?.settings?.['remote.autoForwardPorts'] !== false
    || config.postStartCommand || config.containerEnv || config.remoteEnv
    || config.privileged || config.mounts || config.runArgs) {
  throw Error('Unexpected container privilege, startup, environment or forwarding configuration');
}
console.log('PASS: devcontainer JSON and restricted frontend configuration (not full schema validation)');
if (Number(process.versions.node.split('.')[0]) !== 24) throw Error('Node 24 required for this checkpoint');
console.log(`Node ${process.versions.node}; platform ${process.platform}/${process.arch}`);
for (const command of ['git', 'deno', 'psql', 'postgres', 'initdb', 'postgrest', 'chromium', 'google-chrome']) {
  try {
    // No shell interpolation, environment dump or runtime configuration discovery.
    const value = execFileSync(command, ['--version'], { encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true });
    console.log(`${command}: ${value.trim().split(/\r?\n/)[0].slice(0, 140)}`);
  } catch { console.log(`UNAVAILABLE on PATH: ${command}`); }
}
for (const file of ['node_modules/vite/package.json', 'tools/recovery-parser/node_modules/pg17/package.json', 'tools/recovery-parser/node_modules/pg18/package.json']) {
  console.log(`${existsSync(resolve(root, file)) ? 'PRESENT' : 'MISSING'}: ${file}`);
}
console.log('Linux database/HTTP runners: BLOCKED pending reviewed port; Windows executables cannot be reused.');
console.log('Codespaces runtime readiness: UNVERIFIED until install, checks and private preview run inside Codespaces.');
