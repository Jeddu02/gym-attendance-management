import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { operationWasRejected } from '../lib/operation-error';

type Receipt = { paymentId: string; amountPhp: string | number; paymentMethod: string; receivedAt: string;
  verificationStatus: string; actualReceiptVerified: boolean; allocated: boolean; confirmationVoided: boolean };

export function ReceiptReviewPage() {
  const [rows, setRows] = useState<Receipt[]>([]);
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [action, setAction] = useState<'record' | 'verify' | 'void' | 'allocate'>('record');
  const [targetType, setTargetType] = useState('membership');
  const [targetId, setTargetId] = useState('');
  const [presence, setPresence] = useState(false);
  const [paymentId, setPaymentId] = useState('');
  const [amount, setAmount] = useState('');
  const [method, setMethod] = useState('cash');
  const [reason, setReason] = useState('');
  const [evidence, setEvidence] = useState('');
  const [attested, setAttested] = useState(false);
  const [stillReceived, setStillReceived] = useState('');
  const [replaces, setReplaces] = useState('');
  const [attempt, setAttempt] = useState<Record<string, unknown> | null>(null);
  const mounted = useRef(false);
  const mutating = useRef(false);
  const generation = useRef(0);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  useEffect(() => {
    let active = true;
    const ticket = ++generation.current;
    void (async () => {
      await Promise.resolve();
      if (!active) return;
      setLoading(true); setRows([]);
      try {
        const { data, error } = await getSupabaseClient().functions.invoke('owner-receipt-review', { body: { action: 'list', limit: 50, offset: page * 50 } });
        if (!active || ticket !== generation.current) return;
        if (error || data?.success !== true || !Array.isArray(data.result)) throw Error();
        setRows(data.result);
      } catch { if (active && ticket === generation.current) setMessage('Receipt history could not be loaded.'); }
      finally { if (active && ticket === generation.current) setLoading(false); }
    })();
    return () => { active = false; };
  }, [page, refresh]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (mutating.current) return;
    if (!attempt && (!attested || (action === 'void' && stillReceived === ''))) return;
    const payload = attempt ?? { action, reason, evidenceReference: evidence,
      ...(action === 'record' ? { operationId: crypto.randomUUID(), amountPhp: amount, paymentMethod: method, evidenceReviewed: true, replacesPaymentId: replaces || null }
        : action === 'verify' ? { paymentId, evidenceReviewed: true }
        : action === 'allocate' ? { paymentId, purchaseId: targetType === 'membership' ? targetId : null, walkinRequestId: targetType === 'walkin' ? targetId : null, confirmCurrentPresence: targetType === 'walkin' && presence }
        : { paymentId, receiptStillReceived: stillReceived === 'yes' }) };
    setAttempt(payload); mutating.current = true; setBusy(true); setMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-receipt-review', { body: payload });
      if (!mounted.current) return;
      if (error) throw error;
      if (data?.success !== true) throw Error();
      setAttempt(null); setReason(''); setEvidence(''); setAttested(false); setStillReceived(''); setAmount(''); setReplaces('');
      setMessage(payload.action === 'allocate'
        ? data.result?.confirmationVoided ? 'This allocation was previously voided and has not been restored.'
          : data.result?.attendanceId ? 'Receipt allocated and current walk-in attendance validated.'
            : 'Receipt allocated to the purchase. Finalize the paid term in Memberships to activate access.'
        : 'Recorded with audit history. Receipt verification alone does not activate access or create confirmed income.');
      setRefresh((value) => value + 1);
    } catch (error) {
      if (mounted.current) {
        if (operationWasRejected(error)) { setAttempt(null); setMessage('The request was rejected. Review the target, exact amount, evidence and your Owner access before trying again.'); }
        else setMessage('The result could not be confirmed. Retry the same operation; after reloading, inspect history before recording again.');
      }
    }
    finally { mutating.current = false; if (mounted.current) setBusy(false); }
  }

  function select(row: Receipt, next: 'verify' | 'void' | 'allocate') {
    if (attempt) return;
    setAction(next); setPaymentId(row.paymentId); setReason(''); setEvidence(''); setAttested(false); setStillReceived(''); setTargetId(''); setPresence(false);
  }
  return <section className="plans-module" aria-label="Actual receipt review">
    <div className="plans-toolbar"><div><strong>Actual receipts and corrections</strong><p>Received money, purchase payment status and physical cash are recorded separately.</p></div>
      <button className="secondary-button" disabled={loading || busy} onClick={() => setRefresh((value) => value + 1)}>Refresh</button></div>
    {message && <p role="status" className="members-footnote">{message}</p>}
    <form className="content-card operation-form" onSubmit={(event) => void submit(event)}>
      <fieldset disabled={busy || attempt !== null}>
        <legend>{action === 'record' ? 'Record an unmatched actual receipt' : action === 'verify' ? 'Verify actual receipt' : action === 'allocate' ? 'Review whole-receipt allocation' : 'Void an erroneous confirmation'}</legend>
        <label>Operation<select value={action} onChange={(event) => { setAction(event.target.value as typeof action); setAttested(false); setPresence(false); }}><option value="record">Record actual receipt</option><option value="verify">Verify preserved receipt</option><option value="allocate">Allocate verified whole receipt</option><option value="void">Void erroneous confirmation</option></select></label>
        {action === 'record' ? <><label>PHP amount<input required inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} pattern="[0-9]+(\.[0-9]{1,2})?" /></label>
          <label>Method<select value={method} onChange={(event) => setMethod(event.target.value)}><option value="cash">Cash</option><option value="gcash">GCash</option><option value="bank_transfer">Bank transfer</option></select></label>
          <label>Replaces voided erroneous receipt proof (optional payment reference)<input value={replaces} onChange={(event) => setReplaces(event.target.value)} /></label></>
          : <label>Payment reference<input required value={paymentId} onChange={(event) => setPaymentId(event.target.value)} /></label>}
        <label>Reason<textarea required minLength={5} maxLength={500} value={reason} onChange={(event) => setReason(event.target.value)} /></label>
        <label>Evidence reference<input required maxLength={300} value={evidence} onChange={(event) => setEvidence(event.target.value)} /></label>
        {action === 'void' && <label>Was the money actually received?<select required value={stillReceived} onChange={(event) => setStillReceived(event.target.value)}><option value="">Select explicitly</option><option value="yes">Yes, preserve the actual receipt</option><option value="no">No, the original receipt proof was erroneous</option></select></label>}
        {action === 'allocate' && <><label>Allocate to<select value={targetType} onChange={(event) => { setTargetType(event.target.value); setTargetId(''); setPresence(false); }}><option value="membership">Membership purchase</option><option value="walkin">Current unexpired walk-in request</option></select></label>
          <label>{targetType === 'membership' ? 'Purchase reference' : 'Walk-in request reference'}<input required value={targetId} onChange={(event) => setTargetId(event.target.value)} /></label>
          {targetType === 'walkin' && <label><input type="checkbox" required checked={presence} onChange={(event) => setPresence(event.target.checked)} />I personally confirm the walk-in is physically present now.</label>}</>}
        <label><input type="checkbox" required checked={attested} onChange={(event) => setAttested(event.target.checked)} />I reviewed the original evidence and the reason. {action === 'void' ? 'Affected access and attendance will be invalidated; original history is preserved.' : action === 'allocate' ? 'This exact whole receipt belongs to the selected target. It cannot be allocated twice or combined with other receipts.' : 'This records verified money without automatically allocating it or granting access.'}</label>
      </fieldset>
      <button type="submit" className="primary-button" disabled={busy || (!attempt && !attested)}>{busy ? 'Recording…' : attempt ? 'Retry the same operation' : 'Record with audit history'}</button>
    </form>
    <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Payment reference</th><th>PHP amount</th><th>Method</th><th>Actual receipt</th><th>Allocation / confirmation</th><th>Review</th></tr></thead><tbody>
      {loading ? <tr><td colSpan={6}>Loading…</td></tr> : rows.length === 0 ? <tr><td colSpan={6}>No receipts on this page.</td></tr> : rows.map((row) => <tr key={row.paymentId}>
        <td>{row.paymentId}</td><td>{row.amountPhp}</td><td>{row.paymentMethod}</td><td>{row.actualReceiptVerified ? 'Verified' : 'Needs verification'}</td><td>{row.verificationStatus} · {row.allocated ? 'Allocated' : 'Unallocated'}</td><td>
          {!row.actualReceiptVerified && !row.confirmationVoided && <button type="button" disabled={busy || !!attempt} onClick={() => select(row, 'verify')}>Verify receipt</button>}
          {row.actualReceiptVerified && !row.allocated && row.verificationStatus === 'recorded' && !row.confirmationVoided && <button type="button" disabled={busy || !!attempt} onClick={() => select(row, 'allocate')}>Review allocation</button>}
          {row.verificationStatus === 'confirmed' && <button type="button" disabled={busy || !!attempt} onClick={() => select(row, 'void')}>Review erroneous confirmation</button>}</td>
      </tr>)}
    </tbody></table></div>
    <div className="purchase-history-pagination"><button disabled={loading || page === 0} onClick={() => setPage((value) => value - 1)}>Previous</button><span>Page {page + 1}</span><button disabled={loading || rows.length < 50 || (page + 1) * 50 > 100000} onClick={() => setPage((value) => value + 1)}>Next</button></div>
    <p className="members-footnote">Unmatched and underpaid receipts remain in review. Allocation to a purchase requires a separate verified allocation operation. Corrections preserve original transactions and check-ins.</p>
  </section>;
}
