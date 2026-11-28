import { useEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { parseWalkinRequest, type PaymentMethod, type WalkinRequest } from '../lib/public-entry-contract';
import { formatPhp } from '../lib/money';
import { activeWalkin } from '../lib/walkin-recovery-store';
import { TurnstileChallenge } from './TurnstileChallenge';

const siteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY?.trim() ?? '';
const loopback = (name: string) => ['localhost', '127.0.0.1', '[::1]'].includes(name);
const localRecovery = (() => {
  try { return loopback(window.location.hostname) && loopback(new URL(import.meta.env.VITE_SUPABASE_URL ?? '').hostname); }
  catch { return false; }
})();

const methods: Record<PaymentMethod, string> = { cash: 'Cash', gcash: 'GCash', bank_transfer: 'Bank transfer' };

export function EntrancePage() {
  const [section, setSection] = useState<'member' | 'walkin'>('member');
  const [online, setOnline] = useState(() => navigator.onLine);
  const [identifier, setIdentifier] = useState('');
  const [pin, setPin] = useState('');
  const [challengeToken, setChallengeToken] = useState('');
  const [challengeGeneration, setChallengeGeneration] = useState(0);
  const [checkinBusy, setCheckinBusy] = useState(false);
  const [checkinMessage, setCheckinMessage] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('cash');
  const [request, setRequest] = useState<WalkinRequest | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [uncertain, setUncertain] = useState(false);
  const [storageReady, setStorageReady] = useState(false);
  const [hasActive, setHasActive] = useState(false);
  const [closed, setClosed] = useState(false);
  const creationAttempted = useRef(false);
  const mounted = useRef(false);
  const inFlight = useRef(false);
  const checkinInFlight = useRef(false);

  useEffect(() => {
    mounted.current = true;
    void activeWalkin().then(active => {
      if (!mounted.current) return;
      if (active) {
        setPaymentMethod(active.paymentMethod);
        setHasActive(true);
        setUncertain(true);
        creationAttempted.current = true;
        setMessage('An existing request needs recovery. Do not submit or pay again. Recover it or ask the Owner to review it.');
      }
      setStorageReady(true);
    }).catch(() => {
      if (mounted.current) setMessage('Recovery storage is unavailable. No new request was submitted by this page. An earlier request may still exist; please speak with the Owner.');
    });
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
      if (!localRecovery && (!siteKey || !challengeToken)) {
        setCheckinMessage('Complete the security check before submitting.');
        return;
      }
      const { data, error } = await getSupabaseClient().functions.invoke('member-checkin', {
        method: 'POST', body: { identifier: identifier.trim(), pin, ...(!localRecovery ? {turnstileToken: challengeToken} : {}) },
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
        setChallengeToken('');
        setChallengeGeneration(n => n + 1);
        setCheckinBusy(false);
      }
    }
  }

  async function createRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (inFlight.current || creationAttempted.current || request || !navigator.onLine || !storageReady) return;
    await submitWalkin('create');
  }

  async function submitWalkin(action: 'create' | 'lookup') {
    if (!localRecovery) {setMessage('Hosted walk-in recovery is unavailable. Please speak with the Owner.'); return;}
    if (inFlight.current || !navigator.onLine || !storageReady) return;
    inFlight.current = true;
    setBusy(true);
    setMessage('');
    try {
      const client = getSupabaseClient();
      const active = await activeWalkin(action === 'create' ? paymentMethod : undefined);
      if (!active) throw new Error('No active operation');
      if (!mounted.current) return;
      setHasActive(true);
      if (active.paymentMethod !== paymentMethod) {
        setPaymentMethod(active.paymentMethod);
        creationAttempted.current = true;
        setUncertain(true);
        setMessage('Another tab selected a different method. Recover the original request or speak with the Owner.');
        return;
      }
      if (!navigator.onLine) throw new Error('Public recovery requires internet');
      creationAttempted.current = true;
      const { data, error } = await client.functions.invoke('public-walkin-recovery', {
        method: 'POST', body: action === 'create'
          ? { action, capability: active.capability, paymentMethod: active.paymentMethod }
          : { action, capability: active.capability },
      });
      if (!mounted.current) return;
      if (error) {
        const context = 'context' in error ? error.context : undefined;
        if (context instanceof Response && [404,409,410].includes(context.status)) {
          const payload = await context.clone().json().catch(() => null);
          const messages: Record<string,string> = {
            RECOVERY_CLOSED: 'Recovery is closed. This does not confirm payment or attendance. Ask the Owner to review the original request before any replacement.',
            OPERATION_CONFLICT: 'The saved request conflicts with this submission. Do not submit or pay again; speak with the Owner.',
            NO_RECOVERABLE_OUTCOME: 'No recoverable outcome was found. An earlier request may still arrive. Keep the saved request and speak with the Owner or explicitly retry that same request.',
          };
          const expected: Record<number,string> = {404:'NO_RECOVERABLE_OUTCOME',409:'OPERATION_CONFLICT',410:'RECOVERY_CLOSED'};
          if (payload?.error === expected[context.status]) {
            setUncertain(true); setClosed(context.status === 410);
            setMessage(messages[payload.error]); return;
          }
        }
        throw error;
      }
      const next = parseWalkinRequest(data?.request, paymentMethod);
      if (data?.success !== true || !next || !['PROVISIONAL_CREATED', 'PROVISIONAL_RECOVERED'].includes(data.classification)
        || (action === 'lookup' && data.classification !== 'PROVISIONAL_RECOVERED')) {
        throw new Error('Invalid walk-in request response');
      }
      setRequest(next);
    } catch {
      if (mounted.current) {
        setUncertain(creationAttempted.current);
        setMessage(creationAttempted.current
          ? 'The request outcome could not be verified. A walk-in request may already exist. Do not submit or pay again; recover the saved request or ask the Owner to review it. This message does not confirm payment or attendance.'
          : 'Walk-in requests or recovery storage are unavailable. Nothing was dispatched by this attempt. An earlier request may still exist; please speak with the Owner.');
      }
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
          setChallengeToken('');
          setPin('');
          setIdentifier('');
          setCheckinMessage('');
          event.currentTarget.querySelector<HTMLButtonElement>(`#entrance-${next}-tab`)?.focus();
        }}>
          {(['member', 'walkin'] as const).map((option) => <button key={option} id={`entrance-${option}-tab`} type="button" role="tab" className="secondary-button" aria-selected={section === option} aria-controls={`entrance-${option}-panel`} tabIndex={section === option ? 0 : -1} disabled={busy || checkinBusy} onClick={() => {
            setSection(option);
            setChallengeToken('');
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
              {!localRecovery && online && (siteKey ? <TurnstileChallenge key={challengeGeneration} siteKey={siteKey} onToken={setChallengeToken} /> : <p role="status">Security check unavailable. Please speak with the Owner.</p>)}
              <button type="submit" className="primary-button" disabled={checkinBusy || !online || (!localRecovery && (!siteKey || !challengeToken))}>{checkinBusy ? 'Submitting...' : 'Check in'}</button>
            </form>
            {checkinMessage && <p className="feedback" role="status" aria-live="polite">{checkinMessage}</p>}
          </section>
        ) : <section id="entrance-walkin-panel" role="tabpanel" aria-labelledby="entrance-walkin-tab">
        <p className="security-note">The Owner must confirm actual receipt of payment before walk-in attendance is valid.</p>
        {!localRecovery ? <p role="status">Online walk-in recovery is not yet available. Ask the Owner before paying or submitting another request.</p> : request ? (
          <section aria-label="Pending walk-in request">
            <h2>Awaiting Owner confirmation</h2>
            <dl>
              <dt>Walk-in fee</dt><dd>{formatPhp(request.feePhp)}</dd>
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
              <select id="walkin-payment-method" value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value as PaymentMethod)} disabled={busy || uncertain || !storageReady}>
                {Object.entries(methods).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
            </div>
            <button type="submit" className="primary-button" disabled={busy || uncertain || !online || !storageReady}>{busy ? 'Requesting...' : uncertain ? 'Owner review required' : 'Request a walk-in visit'}</button>
          </form>
        )}
        {localRecovery && hasActive && !request && <div className="member-modal-actions">
          <button type="button" className="secondary-button" disabled={busy || !online} onClick={() => void submitWalkin('lookup')}>Recover existing request</button>
          <button type="button" className="secondary-button" disabled={busy || !online || closed} onClick={() => void submitWalkin('create')}>Retry same request</button>
        </div>}
        {message && <p className="feedback" role="status" aria-live="polite">{message}</p>}
        </section>}
      </section>
    </main>
  );
}
