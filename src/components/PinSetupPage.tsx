import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { privatePinToken } from '../lib/public-entry-contract';

type Props = { purpose: 'enrollment' | 'reset' };

export function PinSetupPage({ purpose }: Props) {
  const [token, setToken] = useState(() => privatePinToken(window.location.hash, purpose));
  const [pin, setPin] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [busy, setBusy] = useState(false);
  const [complete, setComplete] = useState(false);
  const [message, setMessage] = useState('');
  const mounted = useRef(false);
  const inFlight = useRef(false);

  useLayoutEffect(() => {
    // Remove the capability before paint. It is never read from query strings.
    const removeFragment = () => window.history.replaceState(window.history.state, '', `${window.location.pathname}${window.location.search}`);
    const receivePrivateLink = () => {
      const next = privatePinToken(window.location.hash, purpose);
      removeFragment();
      if (inFlight.current) {
        setMessage('A PIN request is in progress. Wait for its result before opening another private link.');
        return;
      }
      setToken(next);
      setPin('');
      setConfirmation('');
      setComplete(false);
      setMessage('');
    };
    removeFragment();
    window.addEventListener('hashchange', receivePrivateLink);
    return () => window.removeEventListener('hashchange', receivePrivateLink);
  }, [purpose]);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token || inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setMessage('');
    try {
      if (!/^\d{6}$/.test(pin) || pin !== confirmation) {
        setMessage('Enter the same six-digit PIN in both fields.');
        return;
      }
      const { data, error } = await getSupabaseClient().functions.invoke(
        purpose === 'enrollment' ? 'member-enroll-pin' : 'member-reset-pin',
        { method: 'POST', body: { token, pin } },
      );
      if (!mounted.current) return;
      if (error) {
        const context = 'context' in error ? error.context : undefined;
        if (context instanceof Response && context.status === 503) {
          setMessage('PIN service is unavailable. Please try again later or ask the Owner for a new private link.');
          return;
        }
        throw error;
      }
      if (data?.success !== true) throw new Error('Request unavailable');
      setToken('');
      setComplete(true);
      setMessage('Your PIN request is complete. Keep your PIN private.');
    } catch {
      if (mounted.current) setMessage('The request could not be completed. You may retry, or ask the Owner for a new private link.');
    } finally {
      inFlight.current = false;
      if (mounted.current) {
        setPin('');
        setConfirmation('');
        setBusy(false);
      }
    }
  }

  return (
    <main className="login-page">
      <section className="login-panel">
        <div className="brand-mark">G</div>
        <p className="eyebrow">PRIVATE MEMBER PIN</p>
        <h1>{purpose === 'enrollment' ? 'Set your PIN' : 'Reset your PIN'}</h1>
        <p className="login-subtitle">Use your own phone. Enter your PIN privately and never share it with anyone, including the Owner.</p>
        {!token && !complete ? <p className="feedback" role="status">Ask the Owner for a new private PIN link after in-person identity verification.</p> : !complete && (
          <form onSubmit={handleSubmit}>
            <div className="field">
              <label htmlFor="member-pin">Six-digit PIN</label>
              <input id="member-pin" type="password" inputMode="numeric" autoComplete="new-password" pattern="[0-9]{6}" minLength={6} maxLength={6} required disabled={busy} value={pin} onChange={(event) => setPin(event.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="confirm-member-pin">Confirm six-digit PIN</label>
              <input id="confirm-member-pin" type="password" inputMode="numeric" autoComplete="new-password" pattern="[0-9]{6}" minLength={6} maxLength={6} required disabled={busy} value={confirmation} onChange={(event) => setConfirmation(event.target.value)} />
            </div>
            <button type="submit" className="primary-button" disabled={busy}>{busy ? 'Submitting...' : purpose === 'enrollment' ? 'Set PIN' : 'Reset PIN'}</button>
          </form>
        )}
        {message && <p className="feedback" role="status" aria-live="polite">{message}</p>}
      </section>
    </main>
  );
}
