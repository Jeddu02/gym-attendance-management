import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';

type PaymentMethod = 'cash' | 'gcash' | 'bank_transfer';
type WalkinRequest = {
  id: string;
  feePhp: string | number;
  currency: 'PHP';
  paymentMethod: PaymentMethod;
  createdAt: string;
  expiresAt: string;
};

const methods: Record<PaymentMethod, string> = { cash: 'Cash', gcash: 'GCash', bank_transfer: 'Bank transfer' };

export function EntrancePage() {
  const [section, setSection] = useState<'member' | 'walkin'>('member');
  const [online, setOnline] = useState(() => navigator.onLine);
  const [identifier, setIdentifier] = useState('');
  const [pin, setPin] = useState('');
  const [checkinBusy, setCheckinBusy] = useState(false);
  const [checkinMessage, setCheckinMessage] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('cash');
  const [request, setRequest] = useState<WalkinRequest | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const mounted = useRef(false);
  const inFlight = useRef(false);
  const checkinInFlight = useRef(false);

  useEffect(() => {
    mounted.current = true;
    const updateConnection = () => setOnline(navigator.onLine);
    window.addEventListener('online', updateConnection);
    window.addEventListener('offline', updateConnection);
    return () => {
      mounted.current = false;
      window.removeEventListener('online', updateConnection);
      window.removeEventListener('offline', updateConnection);
    };
  }, []);

  async function checkIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (checkinInFlight.current) return;
    checkinInFlight.current = true;
    setCheckinBusy(true);
    setCheckinMessage('');
    try {
      if (!navigator.onLine) {
        setCheckinMessage('Member check-in requires internet access. Reconnect and submit again.');
        return;
      }
      if (!identifier.trim() || !/^\d{6}$/.test(pin)) {
        setCheckinMessage('Check-in could not be completed. Review your details or speak with the Owner.');
        return;
      }
      const { data, error } = await getSupabaseClient().functions.invoke('member-checkin', {
        method: 'POST', body: { identifier: identifier.trim(), pin },
      });
      if (!mounted.current) return;
      if (error) {
        const context = 'context' in error ? error.context : undefined;
        if (context instanceof Response && context.status === 503) {
          setCheckinMessage('Member check-in is unavailable. Please speak with the Owner.');
          return;
        }
        throw error;
      }
      if (data?.success !== true || data?.message !== 'CHECKIN_ACCEPTED') throw new Error('Check-in unavailable');
      setIdentifier('');
      setCheckinMessage('Check-in accepted for today.');
    } catch {
      if (mounted.current) setCheckinMessage('Check-in could not be completed. Reconnect and retry, or speak with the Owner.');
    } finally {
      checkinInFlight.current = false;
      if (mounted.current) {
        setPin('');
        setCheckinBusy(false);
      }
    }
  }

  async function createRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (inFlight.current || request || !navigator.onLine) return;
    inFlight.current = true;
    setBusy(true);
    setMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('public-walkin-request', {
        method: 'POST', body: { paymentMethod },
      });
      if (!mounted.current) return;
      if (error) {
        const context = 'context' in error ? error.context : undefined;
        if (context instanceof Response && context.status === 503) {
          setMessage('Walk-in requests are unavailable. Please speak with the Owner.');
          return;
        }
        throw error;
      }
      const next = data?.request;
      if (data?.success !== true || typeof next?.id !== 'string' || next.currency !== 'PHP'
        || !['cash', 'gcash', 'bank_transfer'].includes(next.paymentMethod)
        || !Number.isFinite(Number(next.feePhp)) || Number(next.feePhp) <= 0
        || !Number.isFinite(new Date(next.createdAt).getTime()) || !Number.isFinite(new Date(next.expiresAt).getTime())) {
        throw new Error('Invalid walk-in request response');
      }
      setRequest(next as WalkinRequest);
    } catch {
      if (mounted.current) setMessage('The request could not be completed. Speak with the Owner before retrying if you have already paid.');
    } finally {
      inFlight.current = false;
      if (mounted.current) setBusy(false);
    }
  }

  return (
    <main className="login-page entrance-page">
      <section className="login-panel">
        <div className="brand-mark">G</div>
        <p className="eyebrow">GYM ENTRANCE</p>
        <h1>Welcome to GYMFORCE</h1>
        <p className="login-subtitle">Choose member check-in or a provisional walk-in request.</p>
        <div className="member-modal-actions" role="tablist" aria-label="Entrance options" onKeyDown={(event) => {
          if (busy || checkinBusy || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
          event.preventDefault();
          const next = event.key === 'Home' ? 'member' : event.key === 'End' ? 'walkin' : section === 'member' ? 'walkin' : 'member';
          setSection(next);
          setPin('');
          setIdentifier('');
          setCheckinMessage('');
          event.currentTarget.querySelector<HTMLButtonElement>(`#entrance-${next}-tab`)?.focus();
        }}>
          {(['member', 'walkin'] as const).map((option) => <button key={option} id={`entrance-${option}-tab`} type="button" role="tab" className="secondary-button" aria-selected={section === option} aria-controls={`entrance-${option}-panel`} tabIndex={section === option ? 0 : -1} disabled={busy || checkinBusy} onClick={() => {
            setSection(option);
            setPin('');
            setIdentifier('');
            setCheckinMessage('');
          }}>{option === 'member' ? 'Member check-in' : 'Walk-in visit'}</button>)}
        </div>
        {!online && <p className="feedback" role="status">You are offline. Member check-in and walk-in requests require internet access. Nothing will be queued or confirmed offline.</p>}
        {section === 'member' ? (
          <section id="entrance-member-panel" role="tabpanel" aria-labelledby="entrance-member-tab">
            <p className="security-note">Enter your details privately. Never share your PIN, including with the Owner.</p>
            <form onSubmit={checkIn}>
              <div className="field"><label htmlFor="checkin-identifier">Member ID or registered mobile number</label><input id="checkin-identifier" value={identifier} onChange={(event) => setIdentifier(event.target.value)} maxLength={80} autoComplete="off" autoCapitalize="none" spellCheck={false} required disabled={checkinBusy} /></div>
              <div className="field"><label htmlFor="checkin-pin">Six-digit PIN</label><input id="checkin-pin" type="password" inputMode="numeric" autoComplete="off" pattern="[0-9]{6}" minLength={6} maxLength={6} value={pin} onChange={(event) => setPin(event.target.value)} required disabled={checkinBusy} /></div>
              <button type="submit" className="primary-button" disabled={checkinBusy || !online}>{checkinBusy ? 'Submitting...' : 'Check in'}</button>
            </form>
            {checkinMessage && <p className="feedback" role="status" aria-live="polite">{checkinMessage}</p>}
          </section>
        ) : <section id="entrance-walkin-panel" role="tabpanel" aria-labelledby="entrance-walkin-tab">
        <p className="security-note">The Owner must confirm actual receipt of payment before walk-in attendance is valid.</p>
        {request ? (
          <section aria-label="Pending walk-in request">
            <h2>Awaiting Owner confirmation</h2>
            <dl>
              <dt>Walk-in fee</dt><dd>{Number(request.feePhp).toLocaleString('en-PH', { style: 'currency', currency: request.currency })}</dd>
              <dt>Payment method</dt><dd>{methods[request.paymentMethod]}</dd>
              <dt>Request reference</dt><dd className="payment-reference">{request.id}</dd>
              <dt>Server expiry (Asia/Manila)</dt><dd>{new Date(request.expiresAt).toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' })}</dd>
            </dl>
            <p className="feedback" role="status">Show this reference to the Owner. This request does not confirm payment or attendance.</p>
            <p className="security-note">The server checks expiry when the Owner confirms payment. Expired requests cannot be reused. If you already paid, keep this reference and ask the Owner to review the receipt.</p>
          </section>
        ) : (
          <form onSubmit={createRequest}>
            <div className="field">
              <label htmlFor="walkin-payment-method">Walk-in payment method</label>
              <select id="walkin-payment-method" value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value as PaymentMethod)} disabled={busy}>
                {Object.entries(methods).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
            </div>
            <button type="submit" className="primary-button" disabled={busy || !online}>{busy ? 'Requesting...' : 'Request a walk-in visit'}</button>
          </form>
        )}
        {message && <p className="feedback" role="status" aria-live="polite">{message}</p>}
        </section>}
      </section>
    </main>
  );
}
