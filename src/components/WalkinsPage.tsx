import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { functionErrorMessage } from '../lib/function-error';

type PaymentMethod = 'cash' | 'gcash' | 'bank_transfer';
type WalkinRequest = {
  id: string;
  feePhp: string | number;
  currency: 'PHP';
  paymentMethod: PaymentMethod;
  createdAt: string;
  expiresAt: string;
  status: string;
  confirmedAt?: string | null;
};
type ConfirmAttempt = {
  action: 'confirm';
  requestId: string;
  operationId: string;
  amountPhp: string;
  paymentMethod: PaymentMethod;
  evidenceReviewed: boolean;
};

const pageSize = 50;
const methodLabels: Record<PaymentMethod, string> = { cash: 'Cash', gcash: 'GCash', bank_transfer: 'Bank transfer' };

function php(value: string | number): string {
  const amount = Number(value);
  return Number.isFinite(amount) ? amount.toLocaleString('en-PH', { style: 'currency', currency: 'PHP' }) : 'Unavailable';
}

function gymTime(value: string): string {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date.toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' }) : 'Unavailable';
}

export function WalkinsPage() {
  const requestGeneration = useRef(0);
  const mounted = useRef(false);
  const mutationInFlight = useRef(false);
  const confirmationAttempt = useRef<ConfirmAttempt | null>(null);
  const amountInput = useRef<HTMLInputElement>(null);
  const [requests, setRequests] = useState<WalkinRequest[]>([]);
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [loadError, setLoadError] = useState('');
  const [feePhp, setFeePhp] = useState('');
  const [feeReason, setFeeReason] = useState('');
  const [selected, setSelected] = useState<WalkinRequest | null>(null);
  const [amountPhp, setAmountPhp] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('cash');
  const [evidenceReviewed, setEvidenceReviewed] = useState(false);
  const [retryPending, setRetryPending] = useState(false);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  useEffect(() => {
    let active = true;
    const ticket = ++requestGeneration.current;
    async function load() {
      setLoading(true);
      setRequests([]);
      setLoadError('');
      try {
        const { data, error } = await getSupabaseClient().functions.invoke('owner-walkins', {
          method: 'POST', body: { action: 'list', limit: pageSize, offset: page * pageSize },
        });
        if (!active || ticket !== requestGeneration.current) return;
        if (error) throw error;
        if (data?.success !== true || !Array.isArray(data.requests)) throw new Error('Invalid walk-in list response');
        setRequests(data.requests as WalkinRequest[]);
      } catch (error) {
        const message = await functionErrorMessage(error, 'Could not load walk-in requests. Check your connection and retry.');
        if (active && ticket === requestGeneration.current) setLoadError(message);
      } finally {
        if (active && ticket === requestGeneration.current) setLoading(false);
      }
    }
    const timer = window.setTimeout(() => void load(), 0);
    return () => { active = false; window.clearTimeout(timer); };
  }, [page, refresh]);

  useEffect(() => {
    if (!selected) return;
    const previousFocus = document.activeElement;
    amountInput.current?.focus();
    return () => {
      if (previousFocus instanceof HTMLElement && previousFocus.isConnected) previousFocus.focus();
    };
  }, [selected]);

  function reload() {
    ++requestGeneration.current;
    setLoading(true);
    setRequests([]);
    setRefresh((current) => current + 1);
  }

  async function updateFee(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const reason = feeReason.trim();
    if (mutationInFlight.current || retryPending || !/^[0-9]{1,10}(?:\.[0-9]{1,2})?$/.test(feePhp) || Number(feePhp) <= 0 || reason.length < 5 || reason.length > 500) return;
    mutationInFlight.current = true;
    setBusy(true);
    setErrorMessage('');
    setNotice('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-walkins', {
        method: 'POST', body: { action: 'fee', feePhp, reason },
      });
      if (!mounted.current) return;
      if (error || data?.success !== true || !data.fee) throw new Error('Fee update unavailable');
      setFeePhp('');
      setFeeReason('');
      setNotice('Walk-in fee updated. Existing requests retain their original fee snapshot.');
      reload();
    } catch {
      if (mounted.current) setErrorMessage('The fee update could not be verified. Check the current fee with the Owner before retrying.');
    } finally {
      mutationInFlight.current = false;
      if (mounted.current) setBusy(false);
    }
  }

  function openReceipt(request: WalkinRequest) {
    if (mutationInFlight.current || retryPending || loading) return;
    setSelected(request);
    setAmountPhp('');
    setPaymentMethod(request.paymentMethod);
    setEvidenceReviewed(false);
    setErrorMessage('');
    setNotice('');
  }

  async function confirmReceipt(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (mutationInFlight.current || !selected || !evidenceReviewed || !/^[0-9]{1,10}(?:\.[0-9]{1,2})?$/.test(amountPhp) || Number(amountPhp) <= 0) return;
    const attempt: ConfirmAttempt = confirmationAttempt.current ?? {
      action: 'confirm', requestId: selected.id, operationId: crypto.randomUUID(), amountPhp, paymentMethod, evidenceReviewed,
    };
    confirmationAttempt.current = attempt;
    mutationInFlight.current = true;
    setBusy(true);
    setErrorMessage('');
    setNotice('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-walkins', { method: 'POST', body: attempt });
      if (!mounted.current) return;
      const result = data?.result;
      if (error || data?.success !== true || result?.requestId !== attempt.requestId || typeof result.paymentId !== 'string'
        || !['confirmed', 'receipt_review'].includes(result.outcome)
        || (result.outcome === 'confirmed' && typeof result.attendanceId !== 'string')) throw new Error('Receipt confirmation unavailable');
      confirmationAttempt.current = null;
      setRetryPending(false);
      setSelected(null);
      setAmountPhp('');
      setEvidenceReviewed(false);
      setNotice(result.outcome === 'confirmed'
        ? 'Actual payment confirmed and walk-in attendance validated by the server.'
        : 'Actual receipt preserved for Owner review. It does not grant attendance or count as confirmed income. The original request was not revived.');
      reload();
    } catch {
      if (mounted.current) {
        setRetryPending(true);
        setErrorMessage('The result could not be verified. Retry submits the same receipt details and operation ID; do not record the money again as a new receipt.');
      }
    } finally {
      mutationInFlight.current = false;
      if (mounted.current) setBusy(false);
    }
  }

  return (
    <section className="plans-module">
      <div className="plans-toolbar"><div><strong>Walk-in requests</strong><p>Only actual money received may be confirmed. Eligibility and expiry are checked by the server.</p></div><button type="button" className="secondary-button" disabled={loading || busy || retryPending} onClick={() => { setErrorMessage(''); reload(); }}>Refresh requests</button></div>
      {notice && <p className="members-notice" role="status">{notice}</p>}
      {loadError && <p className="members-error" role="alert">{loadError}</p>}
      {errorMessage && !selected && <p className="members-error" role="alert">{errorMessage}</p>}
      <div className="members-table-card purchase-form-card">
        <div className="members-table-heading"><div><h2>Set walk-in fee</h2><p>Applies to new requests only. Existing request amounts cannot be changed.</p></div></div>
        <form className="purchase-form" onSubmit={updateFee}>
          <label className="member-form-field">New fee (PHP)<input value={feePhp} inputMode="decimal" autoComplete="off" required maxLength={13} onChange={(event) => setFeePhp(event.target.value)} disabled={busy || retryPending} /></label>
          <label className="member-form-field">Change reason (5 to 500 characters)<textarea value={feeReason} required minLength={5} maxLength={500} onChange={(event) => setFeeReason(event.target.value)} disabled={busy || retryPending} /></label>
          <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={busy || retryPending || !feePhp || feeReason.trim().length < 5}>Save fee for new requests</button></div>
        </form>
      </div>
      <div className="members-table-card">
        <div className="members-table-heading"><div><h2>Request history</h2><p>{loading ? 'Loading requests...' : loadError ? 'Requests unavailable' : `${requests.length} requests on this page`}</p></div></div>
        <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Reference</th><th>Fee snapshot</th><th>Requested method</th><th>Created (Manila)</th><th>Server expiry (Manila)</th><th>Status</th><th>Action</th></tr></thead><tbody>
          {loading ? <tr><td colSpan={7} className="members-empty">Loading walk-in requests...</td></tr> : loadError ? <tr><td colSpan={7} className="members-empty">Walk-in history unavailable. Refresh requests to retry.</td></tr> : requests.length === 0 ? <tr><td colSpan={7} className="members-empty">No requests on this page.</td></tr> : requests.map((request) => <tr key={request.id}>
            <td className="payment-reference">{request.id}</td><td>{php(request.feePhp)}</td><td>{methodLabels[request.paymentMethod]}</td><td>{gymTime(request.createdAt)}</td><td>{gymTime(request.expiresAt)}</td><td>{request.status}</td>
            <td>{!['confirmed', 'receipt_review'].includes(request.status) && <button type="button" className="secondary-button" disabled={busy || retryPending} onClick={() => openReceipt(request)}>Record actual receipt</button>}</td>
          </tr>)}
        </tbody></table></div>
        <div className="purchase-history-pagination"><button type="button" className="secondary-button" disabled={loading || busy || retryPending || page === 0} onClick={() => { ++requestGeneration.current; setLoading(true); setPage((current) => current - 1); }}>Previous</button><span>Page {page + 1}</span><button type="button" className="secondary-button" disabled={loading || busy || retryPending || requests.length < pageSize} onClick={() => { ++requestGeneration.current; setLoading(true); setPage((current) => current + 1); }}>Next</button></div>
      </div>
      <p className="members-footnote">Record any money actually received even if the request expired or the amount differs. The server preserves those receipts for review without granting attendance or reviving the request.</p>
      {selected && <div className="member-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy && !retryPending) setSelected(null); }}>
        <section className="member-modal" role="dialog" aria-modal="true" aria-labelledby="walkin-receipt-title" onKeyDown={(event) => {
          if (event.key === 'Escape' && !busy && !retryPending) { event.preventDefault(); setSelected(null); }
          if (event.key === 'Tab') {
            const controls = event.currentTarget.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled)');
            const first = controls[0]; const last = controls[controls.length - 1];
            if (!controls.length) { event.preventDefault(); return; }
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
          }
        }}>
          <div className="member-modal-heading"><div><p className="eyebrow">ACTUAL MONEY RECEIVED</p><h2 id="walkin-receipt-title">Record walk-in receipt</h2></div><button type="button" className="modal-close" disabled={busy || retryPending} onClick={() => setSelected(null)}>Close</button></div>
          <p>Request {selected.id}. Original fee: {php(selected.feePhp)}. Expiry: {gymTime(selected.expiresAt)} (Asia/Manila).</p>
          <form onSubmit={confirmReceipt}>
            <label className="member-form-field">Actual amount received (PHP)<input ref={amountInput} value={amountPhp} inputMode="decimal" autoComplete="off" required maxLength={13} disabled={busy || retryPending} onChange={(event) => setAmountPhp(event.target.value)} /></label>
            <label className="member-form-field">Actual payment method<select value={paymentMethod} disabled={busy || retryPending} onChange={(event) => { setPaymentMethod(event.target.value as PaymentMethod); setEvidenceReviewed(false); }}>{Object.entries(methodLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
            <label className="payment-evidence-attestation"><input type="checkbox" required checked={evidenceReviewed} disabled={busy || retryPending} onChange={(event) => setEvidenceReviewed(event.target.checked)} /><span>{paymentMethod === 'cash' ? 'I physically received the actual cash amount entered above.' : 'I reviewed the actual transfer evidence and verified receipt of the amount entered above.'}</span></label>
            <p className="members-footnote">An amount mismatch or expired request is sent to Owner receipt review. It does not grant attendance or confirmed income.</p>
            {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
            <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={busy || !evidenceReviewed || !amountPhp}>{busy ? 'Recording receipt...' : retryPending ? 'Retry same receipt' : 'Confirm actual receipt'}</button></div>
          </form>
        </section>
      </div>}
    </section>
  );
}
