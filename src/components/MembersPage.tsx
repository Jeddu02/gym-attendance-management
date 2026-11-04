import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';

type Member = {
  id: string;
  memberCode: string;
  fullName: string;
  status: 'pending' | 'active' | 'suspended';
  createdAt: string;
};

type MemberStatus = 'all' | 'pending' | 'active' | 'suspended';

const statusLabels: Record<MemberStatus, string> = {
  all: 'All members',
  pending: 'Pending',
  active: 'Active',
  suspended: 'Suspended',
};

function friendlyError(error: unknown): string {
  if (error && typeof error === 'object' && 'message' in error) {
    const message = String(error.message);
    if (message.includes('MOBILE_ALREADY_REGISTERED')) {
      return 'This mobile number is already registered.';
    }
    if (message.includes('OWNER_ACCESS_REQUIRED')) {
      return 'Your account does not have active Owner access.';
    }
    if (message.includes('OWNER_VERIFICATION_UNAVAILABLE')) {
      return 'Owner verification is temporarily unavailable.';
    }
  }
  return 'The request could not be completed. Please try again.';
}

export function MembersPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<MemberStatus>('all');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [fullName, setFullName] = useState('');
  const [mobile, setMobile] = useState('');
  const [notice, setNotice] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const loadMembers = useCallback(async () => {
    setLoading(true);
    setErrorMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-list-members',
        {
          method: 'POST',
          body: { search: search.trim(), status, limit: 100, offset: 0 },
        },
      );
      if (error) throw error;
      if (!data || !Array.isArray(data.members)) {
        throw new Error('Invalid member-list response');
      }
      setMembers(data.members as Member[]);
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setLoading(false);
    }
  }, [search, status]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadMembers(), 250);
    return () => window.clearTimeout(timer);
  }, [loadMembers]);

  async function handleRegister(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setNotice('');
    setErrorMessage('');

    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-register-member',
        {
          method: 'POST',
          body: { fullName: fullName.trim(), mobile: mobile.trim() },
        },
      );
      if (error) throw error;
      if (data?.success !== true || !data.member?.member_code && !data.member?.memberCode) {
        // The database RPC currently returns member_code in its JSON response.
        if (data?.success !== true || !data?.member?.member_code) {
          throw new Error('Invalid member-registration response');
        }
      }

      setFullName('');
      setMobile('');
      setModalOpen(false);
      setNotice('Member registered successfully. Status: Pending.');
      await loadMembers();
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="members-module">
      <div className="members-toolbar">
        <div className="members-search">
          <span aria-hidden="true">⌕</span>
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search name or member ID"
            aria-label="Search members"
            maxLength={80}
          />
        </div>
        <select
          value={status}
          onChange={(event) => setStatus(event.target.value as MemberStatus)}
          aria-label="Filter members by status"
        >
          {Object.entries(statusLabels).map(([value, label]) => (
            <option key={value} value={value}>{label}</option>
          ))}
        </select>
        <button type="button" className="primary-button members-add-button" onClick={() => {
          setNotice('');
          setErrorMessage('');
          setModalOpen(true);
        }}>
          + Register member
        </button>
      </div>

      {notice && <p className="members-notice" role="status">{notice}</p>}
      {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}

      <div className="members-table-card">
        <div className="members-table-heading">
          <div>
            <h2>Member directory</h2>
            <p>{loading ? 'Loading records…' : `${members.length} record${members.length === 1 ? '' : 's'} shown`}</p>
          </div>
          <button type="button" className="secondary-button" onClick={() => void loadMembers()} disabled={loading}>
            ↻ Refresh
          </button>
        </div>

        <div className="members-table-wrap">
          <table className="members-table">
            <thead>
              <tr>
                <th>Member</th>
                <th>Member ID</th>
                <th>Status</th>
                <th>Date registered</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={4} className="members-empty">Loading members…</td></tr>
              ) : members.length === 0 ? (
                <tr><td colSpan={4} className="members-empty">
                  <strong>No members found</strong>
                  <span>Register a member to begin testing the member workflow.</span>
                </td></tr>
              ) : members.map((member) => (
                <tr key={member.id}>
                  <td><strong>{member.fullName}</strong></td>
                  <td className="member-code">{member.memberCode}</td>
                  <td><span className={`member-status member-status-${member.status}`}>{member.status}</span></td>
                  <td>{new Date(member.createdAt).toLocaleDateString('en-PH', {
                    year: 'numeric', month: 'short', day: 'numeric',
                  })}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <p className="members-footnote">
        New registrations are saved as <strong>Pending</strong>. No payment or membership is created by registration.
      </p>

      {modalOpen && (
        <div className="member-modal-backdrop" role="presentation" onMouseDown={(event) => {
          if (event.target === event.currentTarget && !submitting) setModalOpen(false);
        }}>
          <section className="member-modal" role="dialog" aria-modal="true" aria-labelledby="register-member-title">
            <div className="member-modal-heading">
              <div>
                <p className="eyebrow">MEMBER MANAGEMENT</p>
                <h2 id="register-member-title">Register member</h2>
                <p>Registration does not activate a membership or record a payment.</p>
              </div>
              <button type="button" className="modal-close" onClick={() => setModalOpen(false)} disabled={submitting} aria-label="Close">×</button>
            </div>
            <form onSubmit={handleRegister}>
              <label className="member-form-field">
                Full name
                <input value={fullName} onChange={(event) => setFullName(event.target.value)} required maxLength={120} autoComplete="name" placeholder="Enter member's full name" disabled={submitting} />
              </label>
              <label className="member-form-field">
                Philippine mobile number
                <input value={mobile} onChange={(event) => setMobile(event.target.value)} required maxLength={20} inputMode="tel" autoComplete="tel" placeholder="09XXXXXXXXX" disabled={submitting} />
                <span>Used for secure member lookup. Stored encrypted and as a keyed lookup hash.</span>
              </label>
              {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
              <div className="member-modal-actions">
                <button type="button" className="secondary-button" onClick={() => setModalOpen(false)} disabled={submitting}>Cancel</button>
                <button type="submit" className="primary-button" disabled={submitting}>
                  {submitting ? 'Registering…' : 'Register pending member'}
                </button>
              </div>
            </form>
          </section>
        </div>
      )}
    </section>
  );
}
