// Local operational adapter. No automatic scheduling or external destination.
const fields = ['attempts', 'denied', 'minute', 'timeouts', 'unavailable'];
export class IngressMonitor {
  #delivered = new Set();
  #clock = 0;
  constructor(deliver = null) { this.deliver = deliver; }
  async evaluate(rows, minute) {
    if (!Number.isSafeInteger(minute) || minute < this.#clock) throw Error('MONITOR_CLOCK_UNAVAILABLE');
    if (!Array.isArray(rows) || rows.length > 2 || rows.some(row => !row ||
      Object.keys(row).sort().join() !== fields.join() || fields.some(k => !Number.isSafeInteger(row[k]) || row[k] < 0) ||
      row.minute > minute || row.minute < minute - 1)) throw Error('MONITOR_INPUT_UNAVAILABLE');
    this.#clock = minute;
    for (const key of this.#delivered) if (Number(key.split(':')[0]) <= minute - 2880) this.#delivered.delete(key);
    const alerts = [];
    for (const row of rows) for (const [kind, threshold] of [['denied', 20], ['unavailable', 1], ['timeouts', 5]]) {
      if (row[kind] >= threshold) alerts.push({ minute: row.minute, kind, count: row[kind] });
    }
    for (const alert of alerts) {
      const key = `${alert.minute}:${alert.kind}`;
      if (!this.deliver || this.#delivered.has(key)) continue;
      if (this.#delivered.size >= 11520) throw Error('MONITOR_CAPACITY_UNAVAILABLE');
      // Destination must deduplicate this non-identifying key on uncertain delivery.
      await this.deliver(Object.freeze({ ...alert, key }));
      this.#delivered.add(key);
    }
    return alerts.length;
  }
  async failure(minute) {
    await this.evaluate([], minute);
    const key = `${minute}:maintenance_unavailable`;
    if (!this.deliver || this.#delivered.has(key)) return;
    if (this.#delivered.size >= 11520) throw Error('MONITOR_CAPACITY_UNAVAILABLE');
    await this.deliver(Object.freeze({ minute, kind: 'maintenance_unavailable', count: 1, key }));
    this.#delivered.add(key);
  }
  get retained() { return this.#delivered.size; }
}
export async function localMaintenanceTick(rpc, monitor, minute) {
  // Caller supplies a real transport in integration; tests may inject failures.
  // Never logs the response/error, releases a business lease or retries mutations.
  try {
    const result = await rpc();
    if (!result || result.error || !Array.isArray(result.data)) throw Error('MAINTENANCE_UNAVAILABLE');
    return await monitor.evaluate(result.data, minute);
  } catch {
    try { await monitor.failure(minute); } catch { /* Caller still receives failure; no private error logging. */ }
    throw Error('MAINTENANCE_UNAVAILABLE');
  }
}
