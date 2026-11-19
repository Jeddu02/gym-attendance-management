/** Best-effort cleanup must never delay rejection or dispatch business work. */
function cancelUnread(request: Request): void {
  try {
    if (request.body && !request.body.locked) void request.body.cancel().catch(() => {});
  } catch { /* Closed, disturbed or unsupported bodies remain rejected. */ }
}

/** Recovery-only body boundary. PIN routes retain their independent contract. */
export async function readIngressBody(request: Request, signal: AbortSignal): Promise<unknown> {
  if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json'
    || request.headers.has('content-encoding')) { cancelUnread(request); throw new Error('INVALID_REQUEST'); }
  const length = request.headers.get('content-length');
  if (length !== null && (!/^\d+$/.test(length) || !Number.isSafeInteger(Number(length)) || Number(length) > 2048))
    { cancelUnread(request); throw new Error('INVALID_REQUEST'); }
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  try { reader = request.body?.getReader(); } catch { cancelUnread(request); throw new Error('INVALID_REQUEST'); }
  if (!reader) throw new Error('INVALID_REQUEST');
  let rejectAbort: (reason: unknown) => void = () => {};
  const aborted = new Promise<never>((_, reject) => { rejectAbort = reject; });
  const stop = () => {
    rejectAbort(new DOMException('Request unavailable', 'AbortError'));
    void reader.cancel().catch(() => {});
  };
  const chunks: Uint8Array[] = []; let size = 0;
  signal.addEventListener('abort', stop, { once: true });
  try {
    if (signal.aborted) stop();
    while (true) {
      const { value, done } = await Promise.race([reader.read(), aborted]);
      if (done) break;
      size += value.byteLength;
      if (size > 2048) { void reader.cancel().catch(() => {}); throw new Error('INVALID_REQUEST'); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  } finally { signal.removeEventListener('abort', stop); reader.releaseLock(); }
}
