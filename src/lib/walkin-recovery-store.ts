import type { PaymentMethod } from './public-entry-contract';

export type ActiveWalkin = { capability: string; version: 1; paymentMethod: PaymentMethod };
const database = 'gymforce-walkin-recovery-v1';
const store = 'active';
function projectSlot(): string {
  const target = new URL(import.meta.env.VITE_SUPABASE_URL?.trim() ?? '');
  if (!['https:', 'http:'].includes(target.protocol) || target.username || target.password || target.search || target.hash)
    throw new Error('Recovery project unavailable');
  return 'public-walkin-v1:' + target.origin;
}

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (!globalThis.indexedDB || !globalThis.crypto?.getRandomValues) { reject(new Error('Recovery storage unavailable')); return; }
    const request = indexedDB.open(database, 1);
    let failed = false;
    const unavailable = () => { failed = true; reject(new Error('Recovery storage unavailable')); };
    request.onupgradeneeded = () => request.result.createObjectStore(store);
    request.onerror = unavailable;
    request.onblocked = unavailable;
    request.onsuccess = () => {
      if (failed) { request.result.close(); return; }
      request.result.onversionchange = () => request.result.close(); resolve(request.result);
    };
  });
}
function valid(value: unknown): value is ActiveWalkin {
  if (!value || typeof value !== 'object') return false;
  const v = value as ActiveWalkin;
  return Object.keys(v).sort().join(',') === 'capability,paymentMethod,version'
    && v.version === 1 && typeof v.capability === 'string' && /^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(v.capability)
    && ['cash', 'gcash', 'bank_transfer'].includes(v.paymentMethod);
}
/** The only allocation happens inside one serialized readwrite transaction. */
export async function activeWalkin(method?: PaymentMethod): Promise<ActiveWalkin | null> {
  const slot = projectSlot();
  const db = await open();
  if (!db.objectStoreNames.contains(store)) { db.close(); throw new Error('Recovery storage unavailable'); }
  return new Promise((resolve, reject) => {
    let result: ActiveWalkin | null = null;
    const tx = db.transaction(store, method ? 'readwrite' : 'readonly');
    tx.oncomplete = () => { db.close(); resolve(result); };
    tx.onabort = tx.onerror = () => { db.close(); reject(new Error('Recovery storage unavailable')); };
    const request = tx.objectStore(store).get(slot);
    request.onsuccess = () => {
      if (request.result !== undefined) {
        if (!valid(request.result)) { tx.abort(); return; }
        result = request.result;
      } else if (method) {
        try {
          const raw = crypto.getRandomValues(new Uint8Array(32));
          const capability = btoa(String.fromCharCode(...raw)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
          result = { capability, version: 1, paymentMethod: method };
          tx.objectStore(store).add(result, slot);
        } catch { tx.abort(); }
      }
    };
  });
}
// No automatic deletion, token export, offline queue or new-operation reset.
// Shared-browser cleanup/new-visit policy remains an explicit Owner decision.
