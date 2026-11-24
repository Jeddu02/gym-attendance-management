export type OfflineClaim = { action: 'submit'; operationId: string; memberCode: string; claimedLocalDate: string };
type Entry = { iv: Uint8Array<ArrayBuffer>; ciphertext: ArrayBuffer };
/** Session-scoped queue: no plaintext persistence or reusable keys on disk. */
export class OfflineClaimQueue {
  private key = crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  private entries: Entry[] = [];
  private generation = 0;
  get size() { return this.entries.length; }
  async add(memberCode: string, claimedLocalDate: string) {
    const generation = this.generation;
    if (!/^MBR-[0-9A-F]{12}$/.test(memberCode) || !/^\d{4}-\d{2}-\d{2}$/.test(claimedLocalDate)) throw new Error('Invalid claim');
    const date = new Date(claimedLocalDate + 'T00:00:00Z');
    if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== claimedLocalDate) throw new Error('Invalid date');
    const payload: OfflineClaim = { action: 'submit', operationId: crypto.randomUUID(), memberCode, claimedLocalDate };
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await this.key, new TextEncoder().encode(JSON.stringify(payload)));
    if (generation !== this.generation || this.entries.length >= 50) throw new Error('Queue unavailable or full');
    this.entries.push({ iv, ciphertext });
  }
  async first(): Promise<OfflineClaim | null> {
    const entry = this.entries[0];
    if (!entry) return null;
    const generation = this.generation;
    const bytes = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: entry.iv }, await this.key, entry.ciphertext);
    if (generation !== this.generation) throw new Error('Queue cleared');
    return JSON.parse(new TextDecoder().decode(bytes)) as OfflineClaim;
  }
  removeFirst() { this.entries.shift(); }
  clear() { this.generation++; this.entries = []; this.key = crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']); }
}
