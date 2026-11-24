import { useEffect, useRef, useState, type FormEvent } from 'react';
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

function sectionFromUrl(): Section {
  const section = new URL(window.location.href).searchParams.get('section');
  return navigation.find((item) => item.id === section)?.id ?? 'overview';
}

function storeSectionInUrl(section: Section) {
  const url = new URL(window.location.href);
  if (section === 'overview') url.searchParams.delete('section');
  else url.searchParams.set('section', section);
  if (url.href !== window.location.href) window.history.replaceState(window.history.state, '', url);
}

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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [signedIn, setSignedIn] = useState(false);
  const [authReady, setAuthReady] = useState(false);
  const [activeSection, setActiveSection] = useState<Section>(sectionFromUrl);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  useEffect(() => {
    let active = true;
    const invalidate = () => { ++authGeneration.current; };
    let sessionUserId: string | undefined;
    let timer: number | undefined;
    let subscription: { unsubscribe: () => void } | undefined;

    function clearOwnerView(resetNavigation: boolean) {
      setSignedIn(false);
      setPassword('');
      setPasswordVisible(false);
      setMobileMenuOpen(false);
      if (resetNavigation) {
        storeSectionInUrl('overview');
        setActiveSection('overview');
      }
    }

    try {
      const supabase = getSupabaseClient();
      async function verifyOwner(ticket: number) {
        try {
          const { data, error } = await supabase.functions.invoke('owner-status', {
            method: 'POST', body: {},
          });
          if (!active || ticket !== authGeneration.current) return;
          if (error || data?.authenticated !== true || data?.isActiveOwner !== true || data?.authorizationReady !== true) {
            clearOwnerView(true);
            setMessage('Owner access could not be verified. Please sign in again.');
            setAuthReady(true);
            // This runs outside the Auth callback, avoiding the Auth lock.
            await supabase.auth.signOut({ scope: 'local' });
            return;
          }
          setSignedIn(true);
          setMessage('');
        } catch {
          if (active && ticket === authGeneration.current) {
            clearOwnerView(true);
            setMessage('Unable to verify owner access. Please sign in again.');
          }
        } finally {
          if (active && ticket === authGeneration.current) setAuthReady(true);
        }
      }

      function scheduleVerification() {
        const ticket = ++authGeneration.current;
        setAuthReady(false);
        window.clearTimeout(timer);
        timer = window.setTimeout(() => void verifyOwner(ticket), 0);
      }

      const result = supabase.auth.onAuthStateChange((event, session) => {
        if (!active) return;
        const nextUserId = event === 'SIGNED_OUT' ? undefined : session?.user.id;
        if (sessionUserId && nextUserId && sessionUserId !== nextUserId) clearOwnerView(true);
        sessionUserId = nextUserId;
        if (!sessionUserId) {
          ++authGeneration.current;
          window.clearTimeout(timer);
          clearOwnerView(true);
          setAuthReady(true);
          return;
        }
        // Never await Supabase operations inside this callback.
        scheduleVerification();
      });
      subscription = result.data.subscription;

      function recheckOnFocus() {
        if (sessionUserId && document.visibilityState === 'visible') scheduleVerification();
      }
      window.addEventListener('focus', recheckOnFocus);
      document.addEventListener('visibilitychange', recheckOnFocus);
      return () => {
        active = false;
        invalidate();
        window.clearTimeout(timer);
        subscription?.unsubscribe();
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
    // Remove sensitive components immediately, including while offline.
    setSignedIn(false);
    setEmail('');
    setPassword('');
    setPasswordVisible(false);
    storeSectionInUrl('overview');
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

  function handleNavigation(section: Section) {
    storeSectionInUrl(section);
    setActiveSection(section);
    setMobileMenuOpen(false);
  }

  const restoringSession = !authReady && (
    <main className="login-page">
      <section className="login-panel">
        <div className="brand-mark">G</div>
        <p className="eyebrow">GYM MANAGEMENT SYSTEM</p>
        <h1>Gym Attendance</h1>
        <p className="login-subtitle" role="status">
          Restoring your secure owner session...
        </p>
      </section>
    </main>
  );

  if (!signedIn) {
    if (!authReady) return restoringSession;
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

  // Keep the verified Owner's form state mounted behind the session check.
  return (
    <>
      {restoringSession}
    <div className="dashboard" hidden={!authReady} style={!authReady ? { display: 'none' } : undefined}>
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
    </>
  );
}

