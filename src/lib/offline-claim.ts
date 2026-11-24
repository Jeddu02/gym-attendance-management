export type OfflineClaim = { action: 'submit'; operationId: string; memberCode: string; claimedLocalDate: string };
type Entry = { id: string; owner: string; iv: Uint8Array<ArrayBuffer>; ciphertext: ArrayBuffer; created: number };
function request<T>(r: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
}
function complete(t: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => { t.oncomplete = () => resolve(); t.onabort = t.onerror = () => reject(t.error); });
}
async function openDb(): Promise<IDBDatabase> {
  const r = indexedDB.open('gymforce-offline-claims-v1', 1);
  r.onupgradeneeded = () => {
    r.result.createObjectStore('keys');
    r.result.createObjectStore('claims', { keyPath: 'id' }).createIndex('owner', 'owner');
  };
  return request(r);
}
export class OfflineClaimQueue {
  private entries: Entry[] = [];
  private closed = false;
  private constructor(private db: IDBDatabase, private owner: string, private key: CryptoKey) {}
  static async open(owner: string) {
    const db = await openDb();
    try {
      const candidate = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
      const t = db.transaction('keys', 'readwrite'); const done = complete(t);
      const store = t.objectStore('keys');
      const existing = await request(store.get(owner)) as CryptoKey | undefined;
      if (!existing) store.add(candidate, owner);
      await done;
      const queue = new OfflineClaimQueue(db, owner, existing ?? candidate);
      await queue.reload();
      return queue;
    } catch (error) { db.close(); throw error; }
  }
  get size() { return this.entries.length; }
  private async reload() {
    this.entries = (await request(this.db.transaction('claims').objectStore('claims').index('owner').getAll(this.owner)) as Entry[]).sort((a,b) => a.created-b.created || a.id.localeCompare(b.id));
  }
  async add(memberCode: string, claimedLocalDate: string, leaseUntil: number) {
    if (this.closed || !/^MBR-[0-9A-F]{12}$/.test(memberCode) || !/^\d{4}-\d{2}-\d{2}$/.test(claimedLocalDate)) throw Error('Invalid claim');
    const date = new Date(claimedLocalDate + 'T00:00:00Z');
    if (claimedLocalDate.startsWith('0000') || !Number.isFinite(date.getTime()) || date.toISOString().slice(0,10) !== claimedLocalDate) throw Error('Invalid date');
    return navigator.locks.request('gymforce-offline-claims:' + this.owner, async () => {
      await this.reload();
      for (const entry of this.entries) {
        const existing = await this.decrypt(entry);
        if (existing.memberCode === memberCode && existing.claimedLocalDate === claimedLocalDate) return false;
      }
      const payload: OfflineClaim = { action: 'submit', operationId: crypto.randomUUID(), memberCode, claimedLocalDate };
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: new TextEncoder().encode(this.owner) }, this.key, new TextEncoder().encode(JSON.stringify(payload)));
      if (this.closed || !Number.isFinite(leaseUntil) || Date.now() >= leaseUntil) throw Error('Authorization expired');
      const t = this.db.transaction('claims','readwrite'); const done = complete(t);
      const store = t.objectStore('claims');
      if (await request(store.index('owner').count(this.owner)) >= 50) { await done; throw Error('Queue full'); }
      store.add({ id: payload.operationId, owner: this.owner, iv, ciphertext, created: Date.now() });
      await done; await this.reload();
      return true;
    });
  }
  async first(): Promise<OfflineClaim | null> {
    if (this.closed) throw Error('Queue closed');
    await this.reload();
    const entry = this.entries[0]; if (!entry) return null;
    return this.decrypt(entry);
  }
  private async decrypt(entry: Entry): Promise<OfflineClaim> {
    const bytes = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: entry.iv, additionalData: new TextEncoder().encode(this.owner) }, this.key, entry.ciphertext);
    if (this.closed) throw Error('Queue closed');
    const payload = JSON.parse(new TextDecoder().decode(bytes)) as OfflineClaim;
    if (payload.operationId !== entry.id || payload.action !== 'submit') throw Error('Invalid queue entry');
    return payload;
  }
  async remove(operationId: string) {
    if (this.closed) throw Error('Queue closed');
    const t = this.db.transaction('claims','readwrite'); const done = complete(t);
    const store = t.objectStore('claims');
    const entry = await request(store.get(operationId)) as Entry | undefined;
    if (entry?.owner === this.owner) store.delete(operationId);
    await done; await this.reload();
  }
  clear() { this.closed = true; this.entries = []; this.db.close(); }
}
