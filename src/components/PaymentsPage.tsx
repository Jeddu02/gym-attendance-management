import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';

type PaymentMethod = 'cash' | 'gcash' | 'bank_transfer';
type PaymentStatus = 'recorded' | 'confirmed' | 'rejected';
type StatusFilter = 'all' | PaymentStatus;

type PayablePurchase = {
  id: string;
  memberName: string;
  memberCode: string;
  planName: string;
  pricePhp: number | string;
};

type Payment = {
  id: string;
  purchaseId: string;
  memberName: string;
  memberCode: string;
  planName: string;
  purchasePricePhp: number | string;
  amountPhp: number | string;
  paymentMethod: PaymentMethod;
  verificationStatus: PaymentStatus;
  externalReference: string | null;
  createdAt: string;
  receivedAt: string;
  decisionReason: string | null;
};

const pageSize = 50;
const statusLabels: Record<PaymentStatus, string> = {
  recorded: 'Awaiting review',
  confirmed: 'Confirmed',
  rejected: 'Rejected',
};
const methodLabels: Record<PaymentMethod, string> = {
  cash: 'Cash',
  gcash: 'GCash',
  bank_transfer: 'Bank transfer',
};

function formatPrice(value: number | string): string {
  const amount = Number(value);
  return Number.isFinite(amount)
    ? amount.toLocaleString('en-PH', { style: 'currency', currency: 'PHP' })
    : '—';
}

function formatDateTime(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? '—'
    : date.toLocaleString('en-PH', {
        year: 'numeric', month: 'short', day: 'numeric',
        hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Manila',
      });
}

function paymentStatusClass(status: PaymentStatus): string {
  if (status === 'confirmed') return 'member-status-active';
  if (status === 'rejected') return 'member-status-suspended';
  return 'member-status-pending';
}

function friendlyError(error: unknown): string {
  const message = error && typeof error === 'object' && 'message' in error
    ? String(error.message)
    : '';
  if (message.includes('PURCHASE_NOT_AWAITING_PAYMENT')) return 'This purchase is no longer awaiting payment.';
  if (message.includes('PAYMENT_AWAITING_DECISION')) return 'A payment attempt for this purchase is awaiting a decision.';
  if (message.includes('PAYMENT_NOT_AWAITING_DECISION')) return 'This payment has already been confirmed or rejected. Refresh the history.';
  if (message.includes('PAYMENT_EVIDENCE_REVIEW_REQUIRED')) return 'Review the actual payment evidence before confirming this transfer.';
  if (message.includes('DUPLICATE_PAYMENT')) return 'This transaction reference or payment attempt was already recorded. Refresh the history.';
  if (message.includes('OWNER_ACCESS_REQUIRED')) return 'Your account does not have active Owner access.';
  return 'The payment request could not be completed. Please refresh and try again.';
}

export function PaymentsPage() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [purchases, setPurchases] = useState<PayablePurchase[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [notice, setNotice] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<StatusFilter>('all');
  const [page, setPage] = useState(0);
  const [purchaseId, setPurchaseId] = useState('');
  const [amount, setAmount] = useState('');
  const [method, setMethod] = useState<PaymentMethod>('cash');
  const [externalReference, setExternalReference] = useState('');
  const [decisionPayment, setDecisionPayment] = useState<Payment | null>(null);
  const [evidenceReviewed, setEvidenceReviewed] = useState(false);
  const [rejectReason, setRejectReason] = useState('');

  const loadPayments = useCallback(async () => {
    setLoading(true);
    setErrorMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-membership-payments',
        {
          method: 'POST',
          body: { action: 'list', search, status, limit: pageSize, offset: page * pageSize },
        },
      );
      if (error) throw error;
      if (!Array.isArray(data?.result?.payments) || !Array.isArray(data?.result?.payablePurchases)) {
        throw new Error('Invalid payment list response');
      }
      const nextPayments = data.result.payments as Payment[];
      const nextPurchases = data.result.payablePurchases as PayablePurchase[];
      setPayments(nextPayments);
      setPurchases(nextPurchases);
      setPurchaseId((current) => nextPurchases.some((purchase) => purchase.id === current)
        ? current
        : nextPurchases[0]?.id ?? '');
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setLoading(false);
    }
  }, [page, search, status]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadPayments(), 0);
    return () => window.clearTimeout(timer);
  }, [loadPayments]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(0);
      setSearch(searchInput.trim());
    }, 250);
    return () => window.clearTimeout(timer);
  }, [searchInput]);

  const selectedPurchase = purchases.find((purchase) => purchase.id === purchaseId);

  async function invokePayment(body: Record<string, unknown>) {
    const { data, error } = await getSupabaseClient().functions.invoke(
      'owner-membership-payments',
      { method: 'POST', body },
    );
    if (error) throw error;
    if (data?.success !== true) throw new Error('Invalid payment response');
    return data;
  }

  async function handleRecord(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedPurchase || !/^[0-9]{1,10}(?:\.[0-9]{1,2})?$/.test(amount) || Number(amount) <= 0) {
      setErrorMessage('Enter a valid positive amount with up to two decimal places.');
      return;
    }
    setSubmitting(true);
    setErrorMessage('');
    setNotice('');
    try {
      const data = await invokePayment({
        action: 'record',
        operationId: crypto.randomUUID(),
        membershipPurchaseId: purchaseId,
        amountPhp: amount,
        paymentMethod: method,
        externalReference: externalReference.trim(),
      });
      if (!data.payment?.id) throw new Error('Invalid payment record response');
      if (data.payment.verificationStatus === 'rejected') {
        setNotice(`Payment recorded as rejected. The amount must exactly match the purchase price of ${formatPrice(selectedPurchase.pricePhp)}. The rejected attempt remains in history.`);
      } else {
        setNotice('Payment recorded. It is not confirmed and has not activated membership. Review it in payment history.');
      }
      setAmount('');
      setExternalReference('');
      await loadPayments();
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setSubmitting(false);
    }
  }

  async function decidePayment(action: 'confirm' | 'reject') {
    if (!decisionPayment) return;
    if (action === 'confirm' && decisionPayment.paymentMethod !== 'cash' && !evidenceReviewed) {
      setErrorMessage('Confirm only after reviewing the actual GCash or bank transfer receipt/evidence.');
      return;
    }
    if (action === 'reject' && rejectReason.trim().length < 5) {
      setErrorMessage('Enter a rejection reason of at least five characters.');
      return;
    }
    setSubmitting(true);
    setErrorMessage('');
    setNotice('');
    try {
      const data = await invokePayment(action === 'confirm'
        ? { action, paymentId: decisionPayment.id, evidenceReviewed }
        : { action, paymentId: decisionPayment.id, reason: rejectReason.trim() });
      if (action === 'confirm' && data.confirmation?.purchaseStatus !== 'pending_activation') {
        throw new Error('Invalid payment confirmation response');
      }
      setNotice(action === 'confirm'
        ? 'Full payment confirmed. The purchase is pending activation; membership has not been activated.'
        : 'Payment rejected. The payment and rejection reason remain in history.');
      setDecisionPayment(null);
      setEvidenceReviewed(false);
      setRejectReason('');
      await loadPayments();
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setSubmitting(false);
    }
  }

  function openDecision(payment: Payment) {
    setDecisionPayment(payment);
    setEvidenceReviewed(false);
    setRejectReason('');
    setErrorMessage('');
  }

  return (
    <section className="plans-module payments-module">
      <div className="plans-toolbar">
        <div>
          <strong>Record membership payment</strong>
          <p>Record one full payment attempt against a pending purchase. Recording does not confirm payment.</p>
        </div>
        <button type="button" className="secondary-button" onClick={() => void loadPayments()} disabled={loading || submitting}>Refresh payments</button>
      </div>

      {notice && <p className="members-notice" role="status">{notice}</p>}
      {errorMessage && !decisionPayment && <p className="members-error" role="alert">{errorMessage}</p>}

      <div className="members-table-card payment-form-card">
        <div className="members-table-heading">
          <div><h2>Payment details</h2><p>Select a purchase awaiting full payment.</p></div>
        </div>
        {loading && purchases.length === 0 ? <p className="members-empty">Loading payable purchases…</p> : purchases.length === 0 ? (
          <div className="members-empty payment-no-purchases"><strong>No purchases awaiting payment</strong><span>Pending purchases appear here when no payment attempt is awaiting a decision.</span></div>
        ) : (
          <form className="purchase-form" onSubmit={handleRecord}>
            <label className="member-form-field">Membership purchase
              <select value={purchaseId} onChange={(event) => { setPurchaseId(event.target.value); setAmount(''); }} required disabled={submitting}>
                {purchases.map((purchase) => <option key={purchase.id} value={purchase.id}>{purchase.memberName} — {purchase.memberCode} — {purchase.planName} — {formatPrice(purchase.pricePhp)}</option>)}
              </select>
            </label>
            <div className="purchase-price-preview"><span>Required full payment</span><strong>{selectedPurchase ? formatPrice(selectedPurchase.pricePhp) : '—'}</strong><small>One transaction must match this price exactly. Partial payments are rejected.</small></div>
            <label className="member-form-field">Amount received (PHP)
              <input type="text" inputMode="decimal" autoComplete="off" value={amount} onChange={(event) => setAmount(event.target.value)} maxLength={13} placeholder="e.g. 999.00" required disabled={submitting} />
            </label>
            <label className="member-form-field">Payment method
              <select value={method} onChange={(event) => setMethod(event.target.value as PaymentMethod)} disabled={submitting}>
                <option value="cash">Cash</option><option value="gcash">GCash</option><option value="bank_transfer">Bank transfer</option>
              </select>
            </label>
            {method !== 'cash' && <label className="member-form-field">Transaction reference (optional)
              <input value={externalReference} onChange={(event) => setExternalReference(event.target.value)} maxLength={120} autoComplete="off" disabled={submitting} placeholder="Provider receipt or transfer reference" />
              <span>Enter a provider transaction reference only. Do not enter card numbers or security codes. Evidence review is still required before confirmation.</span>
            </label>}
            <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={submitting || !selectedPurchase}>{submitting ? 'Recording payment…' : 'Record payment attempt'}</button></div>
          </form>
        )}
      </div>

      <div className="members-table-card payment-history-card">
        <div className="members-table-heading">
          <div><h2>Payment history</h2><p>{loading ? 'Loading payments…' : `${payments.length} payment${payments.length === 1 ? '' : 's'} on this page`}</p></div>
          <button type="button" className="secondary-button" onClick={() => void loadPayments()} disabled={loading}>Refresh history</button>
        </div>
        <div className="payment-history-filters">
          <label>Search payments<input type="search" value={searchInput} onChange={(event) => setSearchInput(event.target.value)} maxLength={80} placeholder="Payment, purchase, member, or reference" /></label>
          <label>Status<select value={status} onChange={(event) => { setStatus(event.target.value as StatusFilter); setPage(0); }}><option value="all">All statuses</option><option value="recorded">Awaiting review</option><option value="confirmed">Confirmed</option><option value="rejected">Rejected</option></select></label>
        </div>
        {errorMessage && decisionPayment && <p className="members-error payment-history-error" role="alert">{errorMessage}</p>}
        <div className="members-table-wrap">
          <table className="members-table payment-history-table">
            <thead><tr><th>Payment reference</th><th>Purchase / member</th><th>Amount</th><th>Method</th><th>Status</th><th>Transaction reference</th><th>Recorded</th><th>Decision / action</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={8} className="members-empty">Loading payment history…</td></tr>
                : payments.length === 0 ? <tr><td colSpan={8} className="members-empty"><strong>No payment records found</strong><span>Recorded payment attempts will appear here.</span></td></tr>
                  : payments.map((payment) => <tr key={payment.id}>
                    <td><strong className="payment-reference" title={payment.id}>{payment.id}</strong></td>
                    <td><strong>{payment.memberName}</strong><small className="payment-subline">{payment.memberCode} · {payment.planName}</small></td>
                    <td className="plan-price">{formatPrice(payment.amountPhp)}<small className="payment-subline">Due {formatPrice(payment.purchasePricePhp)}</small></td>
                    <td>{methodLabels[payment.paymentMethod]}</td>
                    <td><span className={`member-status ${paymentStatusClass(payment.verificationStatus)}`}>{statusLabels[payment.verificationStatus]}</span></td>
                    <td>{payment.externalReference || '—'}</td><td>{formatDateTime(payment.createdAt)}</td>
                    <td>{payment.verificationStatus === 'recorded'
                      ? <div className="payment-row-actions"><button type="button" className="secondary-button" onClick={() => openDecision(payment)}>Review</button></div>
                      : <span className="payment-decision-reason">{payment.decisionReason || '—'}</span>}</td>
                  </tr>)}
            </tbody>
          </table>
        </div>
        <div className="purchase-history-pagination">
          <button type="button" className="secondary-button" onClick={() => setPage((current) => Math.max(0, current - 1))} disabled={loading || page === 0}>Previous</button><span>Page {page + 1}</span>
          <button type="button" className="secondary-button" onClick={() => setPage((current) => current + 1)} disabled={loading || payments.length < pageSize}>Next</button>
        </div>
      </div>

      <p className="members-footnote">Only an explicitly confirmed full payment advances a purchase to pending activation. Membership activation is not part of this workflow.</p>

      {decisionPayment && (
        <div className="member-modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !submitting) setDecisionPayment(null); }}>
          <section className="member-modal payment-decision-modal" role="dialog" aria-modal="true" aria-labelledby="payment-decision-title">
            <div className="member-modal-heading"><div><p className="eyebrow">PAYMENT VERIFICATION</p><h2 id="payment-decision-title">Review payment</h2><p>{methodLabels[decisionPayment.paymentMethod]} · {formatPrice(decisionPayment.amountPhp)} · {decisionPayment.memberName}</p></div><button type="button" className="modal-close" aria-label="Close" onClick={() => setDecisionPayment(null)} disabled={submitting}>×</button></div>
            {decisionPayment.paymentMethod !== 'cash' ? (
              <label className="payment-evidence-attestation"><input type="checkbox" checked={evidenceReviewed} onChange={(event) => setEvidenceReviewed(event.target.checked)} disabled={submitting} /><span><strong>I reviewed the actual receipt/evidence and confirm the full amount was received.</strong><small>Reference: {decisionPayment.externalReference || 'not provided'}. The system stores this review attestation, not an uploaded receipt.</small></span></label>
            ) : <p className="members-footnote payment-cash-confirmation">Confirm only if you physically received the full cash amount shown above.</p>}
            <label className="member-form-field">Rejection reason (required to reject)<textarea value={rejectReason} onChange={(event) => setRejectReason(event.target.value)} minLength={5} maxLength={500} rows={3} disabled={submitting} placeholder="Explain why this payment is rejected" /></label>
            {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
            <div className="member-modal-actions payment-decision-actions"><button type="button" className="secondary-button payment-reject-button" onClick={() => void decidePayment('reject')} disabled={submitting || rejectReason.trim().length < 5}>{submitting ? 'Saving…' : 'Reject payment'}</button><button type="button" className="primary-button" onClick={() => void decidePayment('confirm')} disabled={submitting || (decisionPayment.paymentMethod !== 'cash' && !evidenceReviewed)}>{submitting ? 'Confirming…' : decisionPayment.paymentMethod === 'cash' ? 'Confirm cash received' : 'Confirm full payment'}</button></div>
          </section>
        </div>
      )}
    </section>
  );
}
