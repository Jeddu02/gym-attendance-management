import { useEffect, useRef, useState, type FormEvent } from 'react';
import { OfflineClaimQueue } from './lib/offline-claim';
import { MembersPage } from './components/MembersPage';
import { MembershipPlansPage } from './components/MembershipPlansPage';
import { MembershipPurchasesPage } from './components/MembershipPurchasesPage';
import { PaymentsPage } from './components/PaymentsPage';
import { OverviewPage } from './components/OverviewPage';
import { AuditLogPage } from './components/AuditLogPage';
import { WalkinsPage } from './components/WalkinsPage';
import { SettingsPage } from './components/SettingsPage';
import { AttendancePage } from './components/AttendancePage';
import { ReceiptReviewPage } from './components/ReceiptReviewPage';
import { CashDrawerPage } from './components/CashDrawerPage';
import { ClaimReviewPage } from './components/ClaimReviewPage';
import { ReportsPage } from './components/ReportsPage';
import { OwnerUpdateNotice } from './components/OwnerUpdateNotice';
import {
  getSupabaseClient,
  SupabaseConfigurationError,
} from './lib/supabase';

const navigation = [
  { id: 'overview', label: 'Overview', icon: '▦' },
  { id: 'members', label: 'Members', icon: '♙' },
  { id: 'memberships', label: 'Memberships', icon: '▣' },
  { id: 'payments', label: 'Payments', icon: '₱' },
  { id: 'receipts', label: 'Receipt review', icon: 'R' },
  { id: 'cash', label: 'Cash drawer', icon: 'C' },
  { id: 'attendance', label: 'Attendance', icon: '◷' },
  { id: 'claims', label: 'Presence review', icon: 'P' },
  { id: 'walkins', label: 'Walk-ins', icon: 'W' },
  { id: 'audit', label: 'Audit history', icon: 'A' },
  { id: 'reports', label: 'Reports', icon: '▤' },
  { id: 'settings', label: 'Settings', icon: '⚙' },
] as const;

type Section = (typeof navigation)[number]['id'];

const sectionDescriptions: Record<Section, string> = {
  overview: 'Monitor your gym operations from one place.',
  members: 'Register members and manage their membership information.',
  memberships: 'Manage membership plans and member subscriptions.',
  payments: 'Review payments and manage financial records.',
  receipts: 'Preserve actual receipts and document erroneous confirmations.',
  cash: 'Reconcile verified physical cash separately from income.',
  attendance: 'Monitor member check-ins and attendance records.',
  claims: 'Review provisional presence claims separately from valid attendance.',
  settings: 'Manage your gym configuration.',
  audit: 'Review recorded Owner actions and system events.',
  reports: 'Review confirmed income and upcoming membership expiries.',
  walkins: 'Manage walk-in fees, provisional requests, and actual receipts.',
};

export function App() {
  const authGeneration = useRef(0);
  const offlineLeaseUntil = useRef(0);
  const offlineLeaseMs = 15 * 60 * 1000;
  const queue = useRef<OfflineClaimQueue | null>(null);
  const [queueAllowed, setQueueAllowed] = useState(false);
  const [queueCount, setQueueCount] = useState(0);
  const [offlineMember, setOfflineMember] = useState('');
  const [offlineDate, setOfflineDate] = useState('');
  const [queueMessage, setQueueMessage] = useState('');
  const queueBusy = useRef(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [signedIn, setSignedIn] = useState(false);
  const [authReady, setAuthReady] = useState(false);
  const [connectionLocked, setConnectionLocked] = useState(false);
  const retryAuthorization = useRef<() => void>(() => {});
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  useEffect(() => {
    let active = true;
    const invalidate = () => { ++authGeneration.current; };
    let hasSession = false;
    let verifiedUser: string | null = null;
    let sessionUser: string | null = null;
    let timer: number | undefined;
    let leaseTimer: number | undefined;
    let subscription: { unsubscribe: () => void } | undefined;

    function clearOwnerView() {
      offlineLeaseUntil.current = 0;
      window.clearTimeout(leaseTimer);
      setSignedIn(false);
      setConnectionLocked(false);
      queue.current?.clear(); queue.current = null;
      setQueueAllowed(false); setQueueCount(0); setOfflineMember(''); setOfflineDate(''); setQueueMessage('');
      setPassword('');
      setPasswordVisible(false);
      setActiveSection('overview');
      setMobileMenuOpen(false);
    }

    try {
      const supabase = getSupabaseClient();
      function lockConnection() {
        setSignedIn(false);
        setConnectionLocked(true);
        setQueueAllowed(!!verifiedUser && verifiedUser === sessionUser && !!queue.current && Date.now() < offlineLeaseUntil.current && !navigator.onLine);
        setAuthReady(true);
        setMessage('Connection or authorization service unavailable. Management is locked until online authorization succeeds.');
      }

      async function verifyOwner(ticket: number) {
        try {
          if (!navigator.onLine) {
            if (active && ticket === authGeneration.current) lockConnection();
            return;
          }
          const { data, error } = await supabase.functions.invoke('owner-status', {
            method: 'POST', body: {},
          });
          if (!active || ticket !== authGeneration.current) return;
          if (error) {
            const status = (error as { context?: { status?: number } }).context?.status;
            if (status !== 401 && status !== 403) {
              lockConnection();
              return;
            }
          }
          if (error || data?.authenticated !== true || data?.isActiveOwner !== true || data?.authorizationReady !== true) {
            verifiedUser = null;
            clearOwnerView();
            setMessage('Owner access could not be verified. Please sign in again.');
            setAuthReady(true);
            await supabase.auth.signOut({ scope: 'local' });
            return;
          }
          verifiedUser = sessionUser;
          offlineLeaseUntil.current = Date.now() + offlineLeaseMs;
          window.clearTimeout(leaseTimer);
          leaseTimer = window.setTimeout(() => setQueueAllowed(false), offlineLeaseMs);
          if (sessionUser && !queue.current) {
            try {
              const opened = await OfflineClaimQueue.open(sessionUser);
              if (!active || ticket !== authGeneration.current) { opened.clear(); return; }
              queue.current = opened; setQueueCount(opened.size);
            } catch {
              if (!active || ticket !== authGeneration.current) return;
              setQueueMessage('Encrypted offline storage unavailable on this device.');
            }
          }
          setQueueAllowed(false);
          setConnectionLocked(false);
          setSignedIn(true);
          setMessage('');
        } catch {
          if (active && ticket === authGeneration.current) lockConnection();
        } finally {
          if (active && ticket === authGeneration.current) setAuthReady(true);
        }
      }

      function scheduleVerification() {
        const ticket = ++authGeneration.current;
        setSignedIn(false);
        setAuthReady(false);
        window.clearTimeout(timer);
        if (!navigator.onLine) {
          lockConnection();
          return;
        }
        timer = window.setTimeout(() => void verifyOwner(ticket), 0);
      }
      retryAuthorization.current = scheduleVerification;

      const result = supabase.auth.onAuthStateChange((event, session) => {
        if (!active) return;
        hasSession = event !== 'SIGNED_OUT' && Boolean(session);
        sessionUser = session?.user.id ?? null;
        if (verifiedUser !== sessionUser) { verifiedUser = null; clearOwnerView(); }
        if (!hasSession) {
          ++authGeneration.current;
          window.clearTimeout(timer);
          clearOwnerView();
          setAuthReady(true);
          return;
        }
        // Never await Supabase operations inside this callback.
        scheduleVerification();
      });
      subscription = result.data.subscription;

      function recheckOnFocus() {
        if (hasSession && document.visibilityState === 'visible') scheduleVerification();
      }
      function onOffline() {
        if (hasSession) { invalidate(); window.clearTimeout(timer); lockConnection(); }
      }
      window.addEventListener('offline', onOffline);
      window.addEventListener('online', recheckOnFocus);
      window.addEventListener('focus', recheckOnFocus);
      document.addEventListener('visibilitychange', recheckOnFocus);
      return () => {
        active = false;
        invalidate();
        window.clearTimeout(timer);
        subscription?.unsubscribe();
        retryAuthorization.current = () => {};
        window.clearTimeout(leaseTimer);
        offlineLeaseUntil.current = 0;
        window.removeEventListener('offline', onOffline);
        window.removeEventListener('online', recheckOnFocus);
        window.removeEventListener('focus', recheckOnFocus);
        document.removeEventListener('visibilitychange', recheckOnFocus);
      };
    } catch {
      timer = window.setTimeout(() => {
        if (!active) return;
        setAuthReady(true);
        setMessage('Unable to restore your session. Please sign in again.');
      }, 0);
    }
    return () => {
      active = false;
      invalidate();
      window.clearTimeout(timer);
      subscription?.unsubscribe();
    };
  }, []);
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

      // The Auth subscription verifies server-side Owner access before rendering.
      setPassword('');
      setPasswordVisible(false);
    } catch (error) {
      if (supabase !== undefined) {
        try {
          await supabase.auth.signOut();
        } catch {
          // Preserve the original error.
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
    ++authGeneration.current;
    offlineLeaseUntil.current = 0;
    // Remove sensitive components immediately, including while offline.
    queue.current?.clear(); queue.current = null;
    setQueueAllowed(false); setQueueCount(0); setOfflineMember(''); setOfflineDate(''); setQueueMessage('');
    setConnectionLocked(false);
    setSignedIn(false);
    setEmail('');
    setPassword('');
    setPasswordVisible(false);
    setActiveSection('overview');
    setMobileMenuOpen(false);
    setBusy(true);
    setMessage('');
    try {
      const { error } = await getSupabaseClient().auth.signOut({ scope: 'local' });
      if (error) setMessage('Unable to end the local session. Please retry signing out.');
    } catch {
      setMessage('Unable to end the local session. Please retry signing out.');
    } finally {
      setBusy(false);
    }
  }

  async function saveOfflineClaim(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!queueAllowed || navigator.onLine || queueBusy.current) return;
    if (Date.now() >= offlineLeaseUntil.current) { setQueueAllowed(false); setQueueMessage('Offline authorization expired. Reconnect to continue.'); return; }
    queueBusy.current = true;
    try {
      const current = queue.current;
      if (!current) throw Error('Queue unavailable');
      await current.add(offlineMember.trim().toUpperCase(), offlineDate);
      if (queue.current !== current) return;
      setQueueCount(current.size); setOfflineMember(''); setOfflineDate('');
      setQueueMessage('Saved in encrypted device storage. No attendance recorded.');
    } catch { setQueueMessage('Unable to queue claim. Check the fields or queue capacity.'); }
    finally { queueBusy.current = false; }
  }

  async function syncOfflineClaims() {
    if (!signedIn || !navigator.onLine || queueBusy.current || !queue.current) return;
    queueBusy.current = true;
    const current = queue.current;
    const ticket = authGeneration.current;
    try {
      const client = getSupabaseClient();
      const { data, error } = await client.functions.invoke('owner-status', { method: 'POST', body: {} });
      if (error || data?.authenticated !== true || data?.isActiveOwner !== true || data?.authorizationReady !== true) throw Error();
      while (current.size && queue.current === current && ticket === authGeneration.current && navigator.onLine) {
        const payload = await current.first();
        if (!payload || queue.current !== current || ticket !== authGeneration.current || !navigator.onLine) break;
        const result = await client.functions.invoke('owner-attendance-claims', { body: payload });
        if (queue.current !== current) return;
        if (result.error || result.data?.success !== true) throw Error();
        await current.remove(payload.operationId); if (queue.current !== current) return; setQueueCount(current.size);
      }
      setQueueMessage(current.size ? 'Pending claims retained. Retry after authorization.' : 'Claims synchronized for review only.');
    } catch { setQueueMessage('Synchronization unconfirmed. Retry the same queued claims; do not create replacements.'); }
    finally { queueBusy.current = false; }
  }

  function handleNavigation(section: Section) {
    setActiveSection(section);
    setMobileMenuOpen(false);
  }

  if (connectionLocked && !signedIn) {
    return <main className="login-page"><section className="login-panel">
      <div className="brand-mark">G</div><h1>Management temporarily locked</h1>
      <p role="status">{message}</p>
      <p>No attendance, payments or membership changes can be recorded until authorization is restored.</p>
      {queueAllowed && <form onSubmit={(event) => void saveOfflineClaim(event)}><h2>Offline provisional claim</h2><p>Encrypted on this device. Offline entry expires 15 minutes after online verification. Pending claims can be recovered after online owner authorization. No attendance is granted.</p><label>Member ID<input required pattern="MBR-[0-9A-Fa-f]{12}" value={offlineMember} onChange={(event) => setOfflineMember(event.target.value)} /></label><label>Claimed Manila date<input type="date" required value={offlineDate} onChange={(event) => setOfflineDate(event.target.value)} /></label><button className="primary-button">Queue provisional claim</button></form>}
      <p role="status">{queueCount} pending. {queueMessage}</p>
      <button className="primary-button" disabled={!authReady} onClick={() => retryAuthorization.current()}>Retry authorization</button>
      <button className="secondary-button" disabled={busy} onClick={() => void handleSignOut()}>Sign out</button>
    </section></main>;
  }
  if (!signedIn) {
    if (!authReady) {
  return (
    <main className="login-page">
      <section className="login-panel">
        <div className="brand-mark">G</div>
        <p className="eyebrow">GYM MANAGEMENT SYSTEM</p>
        <h1>Gym Attendance</h1>
        <p className="login-subtitle">
          Restoring your secure owner session...
        </p>
      </section>
    </main>
  );
}
    return (
      <main className="login-page">
        <section className="login-panel">
          <div className="brand-mark">G</div>

          <p className="eyebrow">GYM MANAGEMENT SYSTEM</p>
          <h1>Gym Attendance</h1>
          <p className="login-subtitle">
            Owner access to membership and attendance management.
          </p>
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
              <div className="password-control">
                <input
                  id="password"
                  type={passwordVisible ? 'text' : 'password'}
                  autoComplete="current-password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="Enter your password"
                  required
                  maxLength={128}
                  disabled={busy}
                />
                <button
                  className="password-toggle"
                  type="button"
                  aria-label={passwordVisible ? 'Hide password' : 'Show password'}
                  aria-pressed={passwordVisible}
                  onClick={() => setPasswordVisible((visible) => !visible)}
                  disabled={busy}
                >
                  {passwordVisible ? 'Hide' : 'Show'}
                </button>
              </div>
            </div>

            <button className="primary-button" type="submit" disabled={busy}>
              {busy ? 'Verifying access...' : 'Sign in'}
            </button>
          </form>

          {message && (
            <p className="feedback" role="status" aria-live="polite">
              {message}
            </p>
          )}

          <p className="security-note">
            Authorized management access only. Member and walk-in check-in
            will use a separate QR flow.
          </p>
        </section>
      </main>
    );
  }

  const activeItem = navigation.find(
    (item) => item.id === activeSection,
  );

  return (
    <div className="dashboard">
      {mobileMenuOpen && (
        <button
          className="sidebar-backdrop"
          aria-label="Close navigation"
          onClick={() => setMobileMenuOpen(false)}
        />
      )}

      <aside className={`sidebar ${mobileMenuOpen ? 'sidebar-open' : ''}`}>
        <div className="sidebar-brand">
          <div className="brand-mark sidebar-logo">G</div>
          <div>
            <strong>GYMFORCE</strong>
            <span>Management System</span>
          </div>
        </div>

        <div className="sidebar-label">MANAGEMENT</div>

        <nav className="navigation" aria-label="Main navigation">
          {navigation.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`nav-item ${
                activeSection === item.id ? 'nav-item-active' : ''
              }`}
              onClick={() => handleNavigation(item.id)}
              aria-current={activeSection === item.id ? 'page' : undefined}
            >
              <span className="nav-icon" aria-hidden="true">
                {item.icon}
              </span>
              <span>{item.label}</span>
              {activeSection === item.id && (
                <span className="nav-indicator" />
              )}
            </button>
          ))}
        </nav>

        <div className="sidebar-bottom">
          <div className="sidebar-security">
            <span className="security-dot" />
            <div>
              <strong>Owner session</strong>
              <span>Authorization verified</span>
            </div>
          </div>

          <button
            type="button"
            className="signout-button"
            onClick={handleSignOut}
            disabled={busy}
          >
            <span aria-hidden="true">↪</span>
            {busy ? 'Signing out...' : 'Sign out'}
          </button>
        </div>
      </aside>

      <main className="dashboard-main">
        <header className="topbar">
          <div className="topbar-left">
            <button
              type="button"
              className="menu-button"
              aria-label="Open navigation"
              onClick={() => setMobileMenuOpen(true)}
            >
              ☰
            </button>
            <div>
              <p className="topbar-label">GYM MANAGEMENT</p>
              <span className="breadcrumb">
                Management <span>/</span> {activeItem?.label}
              </span>
            </div>
          </div>

          <div className="owner-profile">
            <div className="owner-avatar">O</div>
            <div className="owner-profile-text">
              <strong>Owner</strong>
              <span>Administrator</span>
            </div>
          </div>
        </header>

        <div className="dashboard-content">
          <OwnerUpdateNotice />
          {(queueCount > 0 || queueMessage) && <section className="content-card"><p role="status">{queueCount} pending offline claims. {queueMessage}</p><button className="secondary-button" disabled={!queueCount} onClick={() => void syncOfflineClaims()}>Synchronize pending claims</button></section>}
          <section className="page-heading">
            <div>
              <p className="eyebrow">MANAGEMENT PORTAL</p>
              <h1>{activeItem?.label}</h1>
              <p className="page-description">
                {sectionDescriptions[activeSection]}
              </p>
            </div>
            <div className="system-status">
              <span className="status-dot" />
              Owner access verified
            </div>
          </section>

{activeSection === 'members' ? (
  <MembersPage />
) : activeSection === 'payments' ? (
  <PaymentsPage />
) : activeSection === 'receipts' ? (
  <ReceiptReviewPage />
) : activeSection === 'cash' ? (
  <CashDrawerPage />
) : activeSection === 'memberships' ? (
  <>
    <MembershipPlansPage />
    <MembershipPurchasesPage />
  </>
) : activeSection === 'overview' ? (
            <OverviewPage />
          ) : activeSection === 'audit' ? (
            <AuditLogPage />
          ) : activeSection === 'walkins' ? (
            <WalkinsPage />
          ) : activeSection === 'settings' ? (
            <SettingsPage />
          ) : activeSection === 'attendance' ? (
            <AttendancePage />
          ) : activeSection === 'claims' ? (
            <ClaimReviewPage />
          ) : activeSection === 'reports' ? (
            <ReportsPage />
          ) : (
            <section className="content-card section-placeholder">
              <div className="placeholder-icon">
                {activeItem?.icon}
              </div>
              <h2>{activeItem?.label}</h2>
              <p>{sectionDescriptions[activeSection]}</p>
              <span className="data-badge">Module not connected yet</span>
            </section>
          )}
          <footer className="dashboard-footer">
            <span>GYMFORCE Management System</span>
            <span>Secure owner access</span>
          </footer>
        </div>
      </main>
    </div>
  );
}

