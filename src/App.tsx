
import { useState, type FormEvent } from 'react';
import {
  getSupabaseClient,
  SupabaseConfigurationError,
} from './lib/supabase';

export function App() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [signedIn, setSignedIn] = useState(false);

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage('');
    setBusy(true);


 let supabase;
    try {
      
      supabase = getSupabaseClient();
      const { error: signInError } =
        await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });

      if (signInError) {
        setMessage('Sign-in failed. Check your credentials and try again.');
        return;
      }

      const { data, error: verificationError } =
        await supabase.functions.invoke('owner-status', {
          method: 'POST',
          body: {},
        });

      if (verificationError) {
        await supabase.auth.signOut();
        setMessage(
          'Owner verification is unavailable. Please try again later.',
        );
        return;
      }

      if (
        data?.authenticated !== true ||
        data?.isActiveOwner !== true ||
        data?.authorizationReady !== true
      ) {
        await supabase.auth.signOut();
        setMessage(
          'This account is not authorized for owner management access.',
        );
        return;
      }

      setSignedIn(true);
      setPassword('');
      setMessage('Owner authorization verified successfully.');
    } catch (error) {
      const client = supabase;
      if (client !== undefined) {
      try {
        await client.auth.signOut();
      } catch {
        // Keep the original failure message.
      }
    }
      setSignedIn(false);
      setMessage(
        error instanceof SupabaseConfigurationError
          ? error.message
          : 'Unable to verify owner access. Please try again.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function handleSignOut() {
    setBusy(true);
    setMessage('');

    try {
      const { error } = await getSupabaseClient().auth.signOut();

      if (error) {
        setMessage('Sign-out failed. Please try again.');
        return;
      }

      setSignedIn(false);
      setEmail('');
      setPassword('');
      setMessage('You have signed out.');
    } catch {
      setMessage('Unable to sign out right now. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="page">
      <section className="login-panel">
        <div className="brand-mark" aria-hidden="true">
          G
        </div>

        <p className="eyebrow">GYM MANAGEMENT SYSTEM</p>
        <h1>Gym Attendance</h1>
        <p className="subtitle">
          Owner access to membership and attendance management.
        </p>

        {signedIn ? (
          <div className="session-panel">
            <div className="status-icon" aria-hidden="true">
              ✓
            </div>
            <h2>Owner access verified</h2>
            <p>
              Your account is authenticated and authorized as an active owner.
              Management features can now be connected to this verified
              session.
            </p>
            <button
              className="primary-button"
              type="button"
              onClick={handleSignOut}
              disabled={busy}
            >
              {busy ? 'Signing out…' : 'Sign out'}
            </button>
          </div>
        ) : (
          <form onSubmit={handleSignIn}>
            <div className="field">
              <label htmlFor="email">Owner email</label>
              <input
                id="email"
                type="email"
                autoComplete="username"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="Enter your email"
                required
                maxLength={254}
                disabled={busy}
              />
            </div>

            <div className="field">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Enter your password"
                required
                maxLength={128}
                disabled={busy}
              />
            </div>

            <button
              className="primary-button"
              type="submit"
              disabled={busy}
            >
              {busy ? 'Verifying access…' : 'Sign in'}
            </button>
          </form>
        )}

        {message && (
          <p className="feedback" role="status" aria-live="polite">
            {message}
          </p>
        )}

        <p className="security-note">
          Authorized management access only. Member and walk-in check-in will
          use a separate QR flow.
        </p>
      </section>
    </main>
  );
}
