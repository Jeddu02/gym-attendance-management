import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';
import { operationWasRejected } from '../lib/operation-error';
type Drawer = { id: string; businessDate: string; status: string; openingFloatPhp: string;
  expectedCashPhp: string | null; countedCashPhp: string | null; variancePhp: string | null; reason: string | null; evidenceReference: string | null };
export function CashDrawerPage() {
  const [loadError, setLoadError] = useState('');
  const [rows, setRows] = useState<Drawer[]>([]);
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [evidence, setEvidence] = useState('');
  const [attested, setAttested] = useState(false);
  const [attempt, setAttempt] = useState<Record<string, unknown> | null>(null);
  const mounted = useRef(false); const inFlight = useRef(false);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  useEffect(() => {
    let active = true;
    void (async () => {
      await Promise.resolve(); if (!active) return;
      setLoading(true); setRows([]); setLoadError('');
      try {
        const { data, error } = await getSupabaseClient().functions.invoke('owner-cash', { body: { action: 'list', limit: 50, offset: page * 50 } });
        if (!active) return;
        if (error || data?.success !== true || !Array.isArray(data.result)) throw Error();
        setRows(data.result);
      } catch { if (active) setLoadError('Cash history could not be loaded.'); }
      finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, [page, refresh]);
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
  const openDrawer = rows.find((row) => row.status === 'open');
  const todayRecorded = rows.some((row) => row.businessDate === today);
  async function submit(event: FormEvent) {
    event.preventDefault(); if (inFlight.current || (!attempt && !attested)) return;
    const payload = attempt ?? (openDrawer ? { action: 'close', drawerId: openDrawer.id, countedCashPhp: amount, reason, evidenceReference: evidence }
      : { action: 'open', operationId: crypto.randomUUID(), openingFloatPhp: amount, attested: true });
    setAttempt(payload); inFlight.current = true; setBusy(true); setMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-cash', { body: payload });
      if (!mounted.current) return;
      if (error) throw error;
      if (data?.success !== true) throw Error();
      setAttempt(null); setAmount(''); setReason(''); setEvidence(''); setAttested(false); setRefresh((value) => value + 1);
      setMessage('Cash procedure recorded with audit history. Income and access were not adjusted.');
    } catch (error) {
      if (mounted.current) {
        if (operationWasRejected(error)) { setAttempt(null); setMessage('The cash request was rejected. Review the count, evidence, business date and Owner access. A stale drawer needs separate Owner review.'); }
        else setMessage('Result unconfirmed. Retry the same operation. Inspect drawer history before entering a new operation after reload.');
      }
    }
    finally { inFlight.current = false; if (mounted.current) setBusy(false); }
  }
  return <section className="plans-module" aria-label="Cash reconciliation">
    <div className="plans-toolbar"><div><strong>Physical cash drawer</strong><p>Verified cash receipts include money still awaiting allocation. Electronic payments are excluded.</p></div>
      <button className="secondary-button" disabled={loading || busy} onClick={() => setRefresh((value) => value + 1)}>Refresh</button>
      <button className="secondary-button" disabled={loading || !rows.length} onClick={() => downloadCsv('gymforce-cash-page.csv', ['Business date', 'Status', 'Float PHP', 'Expected PHP', 'Counted PHP', 'Variance PHP', 'Reason', 'Evidence reference'], rows.map((row) => [row.businessDate, row.status, row.openingFloatPhp, row.expectedCashPhp, row.countedCashPhp, row.variancePhp, row.reason, row.evidenceReference]))}>Export this page (CSV)</button></div>
    {message && <p role="status">{message}</p>}
    {page === 0 && !loading && (!todayRecorded || openDrawer || attempt) && <form className="content-card operation-form" onSubmit={(event) => void submit(event)}>
      <fieldset disabled={busy || !!attempt}><legend>{openDrawer ? 'Close the drawer' : 'Open today’s drawer'}</legend>
        <label>{openDrawer ? 'Physically counted cash (PHP)' : 'Physically counted opening float (PHP)'}<input required inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,2})?" value={amount} onChange={(event) => setAmount(event.target.value)} /></label>
        {openDrawer && <><label>Close / variance reason<textarea required minLength={5} maxLength={500} value={reason} onChange={(event) => setReason(event.target.value)} /></label><label>Evidence reference<input required maxLength={300} value={evidence} onChange={(event) => setEvidence(event.target.value)} /></label></>}
        <label><input type="checkbox" required checked={attested} onChange={(event) => setAttested(event.target.checked)} />I physically counted this amount and reviewed the evidence. Variance never changes confirmed income.</label>
      </fieldset><button className="primary-button" disabled={busy || (!attempt && !attested)}>{busy ? 'Recording…' : attempt ? 'Retry the same operation' : openDrawer ? 'Close with evidence' : 'Attest and open'}</button>
    </form>}
    <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Manila date</th><th>Status</th><th>Float PHP</th><th>Expected PHP</th><th>Counted PHP</th><th>Variance PHP</th><th>Reason / evidence</th></tr></thead><tbody>{loading ? <tr><td colSpan={7}>Loading…</td></tr> : loadError ? <tr><td colSpan={7} role="alert">Cash history unavailable. Refresh to retry.</td></tr> : rows.length === 0 ? <tr><td colSpan={7}>No drawers recorded.</td></tr> : rows.map((row) => <tr key={row.id}><td>{row.businessDate}</td><td>{row.status}</td><td>{row.openingFloatPhp}</td><td>{row.expectedCashPhp ?? 'Open'}</td><td>{row.countedCashPhp ?? 'Open'}</td><td>{row.variancePhp ?? 'Open'}</td><td>{row.reason} {row.evidenceReference}</td></tr>)}</tbody></table></div>
    <div className="purchase-history-pagination"><button disabled={loading || page === 0} onClick={() => setPage((value) => value - 1)}>Previous</button><span>Page {page + 1}</span><button disabled={loading || rows.length < 50 || (page + 1) * 50 > 100000} onClick={() => setPage((value) => value + 1)}>Next</button></div>
    <p className="members-footnote">Close each Manila business day. Closed snapshots preserve the receipt IDs and amounts counted at closing. Later receipt verification or correction does not rewrite the snapshot. A stale open drawer requires Owner review.</p>
  </section>;
}
