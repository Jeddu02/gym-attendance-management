import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { operationWasRejected } from '../lib/operation-error';
type Claim = { id: string; memberCode: string; claimedLocalDate: string; submittedAt: string; status: string; reason: string | null; attendanceId: string | null };
export function ClaimReviewPage() {
  const [loadError, setLoadError] = useState('');
  const [rows, setRows] = useState<Claim[]>([]);
  const [page, setPage] = useState(0); const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [message, setMessage] = useState('');
  const [memberCode, setMemberCode] = useState(''); const [claimedLocalDate, setDate] = useState('');
  const [selected, setSelected] = useState<Claim | null>(null); const [reason, setReason] = useState('');
  const [presence, setPresence] = useState(false); const [reviewed, setReviewed] = useState(false);
  const [attempt, setAttempt] = useState<Record<string, unknown> | null>(null);
  const mounted = useRef(false); const inFlight = useRef(false);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  useEffect(() => {
    let active = true;
    void (async () => {
      await Promise.resolve(); if (!active) return;
      setLoading(true); setRows([]); setLoadError('');
      try {
        const { data, error } = await getSupabaseClient().functions.invoke('owner-attendance-claims', { body: { action: 'list', limit: 50, offset: page * 50 } });
        if (!active) return;
        if (error || data?.success !== true || !Array.isArray(data.result)) throw Error();
        setRows(data.result);
      } catch { if (active) setLoadError('Presence review is unavailable. No attendance has been confirmed.'); }
      finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, [page, refresh]);
  async function submit(event: FormEvent) {
    event.preventDefault(); if (inFlight.current || (!attempt && selected && !reviewed)) return;
    const payload = attempt ?? (selected ? { action: 'resolve', claimId: selected.id, confirmCurrentPresence: presence, reason }
      : { action: 'submit', operationId: crypto.randomUUID(), memberCode: memberCode.trim().toUpperCase(), claimedLocalDate });
    setAttempt(payload); inFlight.current = true; setBusy(true); setMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-attendance-claims', { body: payload });
      if (!mounted.current) return;
      if (error) throw error;
      if (data?.success !== true) throw Error();
      setMessage(payload.action === 'submit' ? 'Provisional claim retained for review. This does not grant attendance.' : data.result?.outcome === 'current_presence_confirmed' ? 'Current presence and eligibility validated; check-in recorded.' : 'Resolved with a reason, without attendance. Original claim retained.');
      setAttempt(null); setSelected(null); setMemberCode(''); setDate(''); setReason(''); setPresence(false); setReviewed(false); setRefresh((value) => value + 1);
    } catch (error) {
      if (mounted.current) {
        if (operationWasRejected(error)) { setAttempt(null); setMessage('The request was rejected. Older, ineligible or duplicate claims remain in review; record a reason to resolve without attendance if appropriate.'); }
        else setMessage('Result unconfirmed. Retry this operation; inspect history before entering a replacement after reload.');
      }
    }
    finally { inFlight.current = false; if (mounted.current) setBusy(false); }
  }
  return <section className="plans-module" aria-label="Provisional presence review">
    <div className="plans-toolbar"><div><strong>Provisional presence claims</strong><p>Recorded claims stay separate from validated check-ins.</p></div><button disabled={loading || busy} className="secondary-button" onClick={() => setRefresh((value) => value + 1)}>Refresh</button></div>
    {message && <p role="status">{message}</p>}
    <form className="content-card operation-form" onSubmit={(event) => void submit(event)}><fieldset disabled={busy || !!attempt}>
      <legend>{selected ? `Review claim ${selected.id}` : 'Submit a provisional claim for review'}</legend>
      {selected ? <><p>{selected.memberCode} · Claimed date {selected.claimedLocalDate}</p><label>Resolution reason<textarea required minLength={5} maxLength={500} value={reason} onChange={(event) => setReason(event.target.value)} /></label>
        <label><input type="checkbox" checked={presence} onChange={(event) => setPresence(event.target.checked)} />I personally confirm this member is physically present today. The server must still validate today’s paid eligibility and duplicates.</label>
        <label><input type="checkbox" required checked={reviewed} onChange={(event) => setReviewed(event.target.checked)} />I reviewed this resolution. Without today’s presence confirmation, this closes the claim without attendance.</label>
        <button type="button" onClick={() => { setSelected(null); setPresence(false); setReviewed(false); }}>Return to claim entry</button></>
        : <><label>Member ID<input required pattern="MBR-[0-9A-Fa-f]{12}" value={memberCode} onChange={(event) => setMemberCode(event.target.value)} /></label><label>Claimed Manila date<input type="date" required value={claimedLocalDate} onChange={(event) => setDate(event.target.value)} /></label></>}
    </fieldset><button className="primary-button" disabled={busy || (!attempt && !!selected && !reviewed)}>{busy ? 'Recording…' : attempt ? 'Retry the same operation' : selected ? 'Record resolution' : 'Submit provisional claim'}</button></form>
    <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Claim</th><th>Member ID</th><th>Claimed date</th><th>Status</th><th>Resolution reason</th><th>Review</th></tr></thead><tbody>{loading ? <tr><td colSpan={6}>Loading…</td></tr> : loadError ? <tr><td colSpan={6} role="alert">Presence review unavailable. Refresh to retry.</td></tr> : rows.length === 0 ? <tr><td colSpan={6}>No claims on this page.</td></tr> : rows.map((row) => <tr key={row.id}><td>{row.id}</td><td>{row.memberCode}</td><td>{row.claimedLocalDate}</td><td>{row.status}</td><td>{row.reason}</td><td>{row.status === 'provisional' && <button disabled={busy || !!attempt} onClick={() => { setSelected(row); setReason(''); setPresence(false); setReviewed(false); }}>Review claim</button>}</td></tr>)}</tbody></table></div>
    <div className="purchase-history-pagination"><button disabled={loading || page === 0} onClick={() => setPage((value) => value - 1)}>Previous</button><span>Page {page + 1}</span><button disabled={loading || rows.length < 50 || (page + 1) * 50 > 100000} onClick={() => setPage((value) => value + 1)}>Next</button></div>
    <p className="members-footnote">Claimed dates are untrusted. Older or conflicting claims remain in review unless resolved with a reason without attendance. This form requires internet and does not save drafts on the device.</p>
  </section>;
}
