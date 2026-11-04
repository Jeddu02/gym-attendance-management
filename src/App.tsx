import { useEffect, useState, type FormEvent } from 'react';
import { MembersPage } from './components/MembersPage';
import { MembershipPlansPage } from './components/MembershipPlansPage';
import { MembershipPurchasesPage } from './components/MembershipPurchasesPage';
import { PaymentsPage } from './components/PaymentsPage';
import {
  getSupabaseClient,
  SupabaseConfigurationError,
} from './lib/supabase';

const navigation = [
  { id: 'overview', label: 'Overview', icon: '▦' },
  { id: 'members', label: 'Members', icon: '♙' },
  { id: 'memberships', label: 'Memberships', icon: '▣' },
  { id: 'payments', label: 'Payments', icon: '₱' },
  { id: 'attendance', label: 'Attendance', icon: '◷' },
  { id: 'settings', label: 'Settings', icon: '⚙' },
] as const;

type Section = (typeof navigation)[number]['id'];

const sectionDescriptions: Record<Section, string> = {
  overview: 'Monitor your gym operations from one place.',
  members: 'Register members and manage their membership information.',
  memberships: 'Manage membership plans and member subscriptions.',
  payments: 'Review payments and manage financial records.',
  attendance: 'Monitor member check-ins and attendance records.',
  settings: 'Manage your gym configuration.',
};

export function App() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [signedIn, setSignedIn] = useState(false);
  const [authReady, setAuthReady] = useState(false);
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
    useEffect(() => {
    let active = true;

    async function restoreOwnerSession() {
      try {
        const supabase = getSupabaseClient();

        const { data: sessionData, error: sessionError } =
          await supabase.auth.getSession();

        if (sessionError) throw sessionError;

        if (!sessionData.session) return;

        const { data, error } = await supabase.functions.invoke(
          'owner-status',
          {
            method: 'POST',
            body: {},
          },
        );

        if (error) {
          await supabase.auth.signOut();
          return;
        }

        if (
          data?.authenticated !== true ||
          data?.isActiveOwner !== true ||
          data?.authorizationReady !== true
        ) {
          await supabase.auth.signOut();
          return;
        }

        if (active) {
          setActiveSection('overview');
          setSignedIn(true);
        }
      } catch {
        if (active) {
          setMessage('Unable to restore your session. Please sign in again.');
        }
      } finally {
        if (active) setAuthReady(true);
      }
    }

    void restoreOwnerSession();

    return () => {
      active = false;
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

      setActiveSection('overview');
      setSignedIn(true);
      setPassword('');
      setMessage('');
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
      setActiveSection('overview');
      setMobileMenuOpen(false);
      setMessage('');
    } catch {
      setMessage('Unable to sign out right now. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  function handleNavigation(section: Section) {
    setActiveSection(section);
    setMobileMenuOpen(false);
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
) : activeSection === 'memberships' ? (
  <>
    <MembershipPlansPage />
    <MembershipPurchasesPage />
  </>
) : activeSection === 'overview' ? (
            <>
              <section className="welcome-panel">
                <div>
                  <p className="welcome-eyebrow">OWNER DASHBOARD</p>
                  <h2>Welcome back, Owner.</h2>
                  <p>
                    Manage your gym's members, memberships, payments, and
                    attendance in one place.
                  </p>
                </div>
                <div className="welcome-decoration" aria-hidden="true">
                  G
                </div>
              </section>

              <section className="section-heading">
                <div>
                  <h2>Gym overview</h2>
                  <p>Your management summaries will appear here.</p>
                </div>
                <span className="data-badge">Awaiting connection</span>
              </section>

              <div className="summary-grid">
                {[
                  { label: 'Total Members', icon: '♙' },
                  { label: 'Active Memberships', icon: '▣' },
                  { label: "Today's Attendance", icon: '◷' },
                  { label: "Today's Payments", icon: '₱' },
                ].map((card) => (
                  <article className="summary-card" key={card.label}>
                    <div className="summary-card-top">
                      <span>{card.label}</span>
                      <span className="summary-icon">{card.icon}</span>
                    </div>
                    <div className="summary-value">—</div>
                    <p>Not connected to live data</p>
                  </article>
                ))}
              </div>

              <section className="overview-grid">
                <article className="content-card activity-card">
                  <div className="card-heading">
                    <div>
                      <h2>Recent activity</h2>
                      <p>Latest gym management activity.</p>
                    </div>
                  </div>
                  <div className="empty-state">
                    <div className="empty-icon">◷</div>
                    <strong>No activity to display</strong>
                    <p>
                      Activity records will appear here once the dashboard
                      is connected to the database.
                    </p>
                  </div>
                </article>

                <article className="content-card quick-card">
                  <div className="card-heading">
                    <div>
                      <h2>Management sections</h2>
                      <p>Navigate to a management area.</p>
                    </div>
                  </div>

                  <div className="quick-links">
                    {navigation.slice(1, 5).map((item) => (
                      <button
                        type="button"
                        className="quick-link"
                        key={item.id}
                        onClick={() => handleNavigation(item.id)}
                      >
                        <span className="quick-link-icon">{item.icon}</span>
                        <span>{item.label}</span>
                        <span className="quick-arrow">→</span>
                      </button>
                    ))}
                  </div>
                </article>
              </section>
            </>
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

