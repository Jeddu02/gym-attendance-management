import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
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
  active: 'Registration approved',
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

const pageSize = 50;

function PinHandoffDialog({ member, purpose, onClose }: {
  member: Member;
  purpose: 'enrollment' | 'reset';
  onClose: () => void;
}) {
  const [identityVerified, setIdentityVerified] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [privateLink, setPrivateLink] = useState('');
  const [expiresAt, setExpiresAt] = useState('');
  const [message, setMessage] = useState('');
  const mounted = useRef(false);
  const inFlight = useRef(false);
  const reasonInput = useRef<HTMLTextAreaElement>(null);
  const linkInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const previousFocus = document.activeElement;
    mounted.current = true;
    reasonInput.current?.focus();
    return () => {
      mounted.current = false;
      if (previousFocus instanceof HTMLElement && previousFocus.isConnected) previousFocus.focus();
    };
  }, []);

  useEffect(() => {
    if (privateLink) linkInput.current?.focus();
  }, [privateLink]);

  async function generate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const reviewedReason = reason.trim();
    if (inFlight.current || privateLink || !identityVerified || reviewedReason.length < 5 || reviewedReason.length > 500) return;
    inFlight.current = true;
    setBusy(true);
    setMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        purpose === 'enrollment' ? 'owner-create-pin-enrollment-token' : 'owner-create-pin-recovery-token',
        { method: 'POST', body: { memberId: member.id, identityVerified: true, reason: reviewedReason } },
      );
      if (!mounted.current) return;
      if (error) {
        const context = 'context' in error ? error.context : undefined;
        if (context instanceof Response && context.status === 503) {
          setMessage('PIN links are unavailable. Please try again later.');
          return;
        }
        throw error;
      }
      if (typeof data?.token !== 'string' || !/^[A-Za-z0-9_-]{40,128}$/.test(data.token)
        || data.purpose !== purpose || typeof data.expiresAt !== 'string' || !Number.isFinite(new Date(data.expiresAt).getTime())) {
        throw new Error('Invalid PIN link response');
      }
      const link = new URL(purpose === 'enrollment' ? '/pin-setup' : '/pin-reset', window.location.origin);
      link.hash = new URLSearchParams({ token: data.token }).toString();
      setPrivateLink(link.toString());
      setExpiresAt(data.expiresAt);
      setReason('');
    } catch {
      if (mounted.current) setMessage('The private PIN link could not be created. Please try again later.');
    } finally {
      inFlight.current = false;
      if (mounted.current) setBusy(false);
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(privateLink);
      if (mounted.current) setMessage('Link copied. Hand it only to the verified member on their own phone.');
    } catch {
      if (mounted.current) {
        linkInput.current?.select();
        setMessage('Copy is unavailable. Select and copy the private link manually.');
      }
    }
  }

  return (
    <div className="member-modal-backdrop" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget && !busy) onClose();
    }}>
      <section className="member-modal" role="dialog" aria-modal="true" aria-labelledby="pin-handoff-title" aria-describedby="pin-handoff-description" onKeyDown={(event) => {
        if (event.key === 'Escape' && !busy) { event.preventDefault(); onClose(); }
        if (event.key === 'Tab') {
          const controls = event.currentTarget.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), textarea:not(:disabled)');
          const first = controls[0];
          const last = controls[controls.length - 1];
          if (!controls.length) { event.preventDefault(); return; }
          if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
          else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        }
      }}>
        <div className="member-modal-heading">
          <div><p className="eyebrow">PRIVATE PIN HANDOFF</p><h2 id="pin-handoff-title">{purpose === 'enrollment' ? 'PIN setup link' : 'PIN reset link'}</h2></div>
          <button type="button" className="modal-close" aria-label="Close PIN handoff" disabled={busy} onClick={onClose}>Close</button>
        </div>
        <p id="pin-handoff-description">{member.fullName} ({member.memberCode}). Verify identity in person. The member must choose their PIN privately on their own phone; never ask them to share it.</p>
        {privateLink ? (
          <div>
            <p className="members-footnote">This one-use private link is shown only here. Share it only with the verified member. Closing this dialog removes it from this screen.</p>
            <label className="member-form-field">Private member link<input ref={linkInput} value={privateLink} readOnly autoComplete="off" spellCheck={false} onFocus={(event) => event.currentTarget.select()} /></label>
            <p>Expires {new Date(expiresAt).toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' })} (Asia/Manila).</p>
            <div className="member-modal-actions"><button type="button" className="secondary-button" onClick={() => void copyLink()}>Copy private link</button><button type="button" className="primary-button" onClick={onClose}>Finish handoff</button></div>
          </div>
        ) : (
          <form onSubmit={generate}>
            <label className="member-form-field">Verification reason (5 to 500 characters)<textarea ref={reasonInput} value={reason} onChange={(event) => setReason(event.target.value)} required minLength={5} maxLength={500} disabled={busy} /></label>
            <label className="payment-evidence-attestation"><input type="checkbox" checked={identityVerified} onChange={(event) => setIdentityVerified(event.target.checked)} required disabled={busy} /><span>I verified this member's identity in person and will hand the private link directly to them.</span></label>
            <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={busy || !identityVerified || reason.trim().length < 5}>{busy ? 'Creating private link...' : 'Create private link'}</button></div>
          </form>
        )}
        {message && <p className="feedback" role="status" aria-live="polite">{message}</p>}
      </section>
    </div>
  );
}

export function MembersPage() {
  const request = useRef(0);
  const mounted = useRef(false);
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [members, setMembers] = useState<Member[]>([]);
  const [loadFailed, setLoadFailed] = useState(false);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<MemberStatus>('all');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [approvalMember, setApprovalMember] = useState<Member | null>(null);
  const [approvalReason, setApprovalReason] = useState('');
  const [pinHandoff, setPinHandoff] = useState<{ member: Member; purpose: 'enrollment' | 'reset' } | null>(null);
  const approvalReasonInput = useRef<HTMLTextAreaElement>(null);
  const approvalInFlight = useRef(false);
  const [fullName, setFullName] = useState('');
  const [mobile, setMobile] = useState('');
  const [notice, setNotice] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const loadMembers = useCallback(async () => {
    const ticket = ++request.current;
    setLoading(true);
    setMembers([]);
    setLoadFailed(false);
    setErrorMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-list-members',
        {
          method: 'POST',
          body: { search: search.trim(), status, limit: pageSize, offset: page * pageSize },
        },
      );
      if (!mounted.current || ticket !== request.current) return;
      if (error) throw error;
      if (!data || !Array.isArray(data.members)) {
        throw new Error('Invalid member-list response');
      }
      setMembers(data.members as Member[]);
    } catch (error) {
      if (mounted.current && ticket === request.current) { setLoadFailed(true); setErrorMessage(friendlyError(error)); }
    } finally {
      if (mounted.current && ticket === request.current) setLoading(false);
    }
  }, [page, search, status]);

  useEffect(() => {
    const invalidate = () => { ++request.current; };
    mounted.current = true;
    return () => { mounted.current = false; invalidate(); };
  }, []);

  useEffect(() => {
    const invalidate = () => { ++request.current; };
    const timer = window.setTimeout(() => void loadMembers(), 250);
    return () => { window.clearTimeout(timer); invalidate(); };
  }, [loadMembers, refresh]);

  useEffect(() => {
    if (!approvalMember) return;
    const previousFocus = document.activeElement;
    approvalReasonInput.current?.focus();
    return () => {
      if (previousFocus instanceof HTMLElement && previousFocus.isConnected) previousFocus.focus();
    };
  }, [approvalMember]);

  async function handleApprove(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const reason = approvalReason.trim();
    if (!approvalMember || approvalInFlight.current || reason.length < 5 || reason.length > 500) return;
    const memberId = approvalMember.id;
    approvalInFlight.current = true;
    setSubmitting(true);
    setNotice('');
    setErrorMessage('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke('owner-membership-lifecycle', {
        method: 'POST', body: { action: 'approve', memberId, reason },
      });
      if (!mounted.current) return;
      if (error) throw error;
      if (data?.success !== true || data?.member?.id !== memberId || data?.member?.status !== 'active') {
        throw new Error('Invalid registration approval response');
      }
      setApprovalMember(null);
      setApprovalReason('');
      setNotice('Registration approved. Membership access still requires a fully paid, server-validated term.');
      ++request.current;
      setLoading(true);
      setRefresh((current) => current + 1);
    } catch (error) {
      if (mounted.current) setErrorMessage(friendlyError(error));
    } finally {
      approvalInFlight.current = false;
      if (mounted.current) setSubmitting(false);
    }
  }

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
      if (!mounted.current) return;
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
      ++request.current;
      setRefresh((current) => current + 1);
    } catch (error) {
      if (mounted.current) setErrorMessage(friendlyError(error));
    } finally {
      if (mounted.current) setSubmitting(false);
    }
  }

  return (
    <section className="members-module">
      <div className="members-toolbar">
        <div className="members-search">
          <span aria-hidden="true">⌕</span>
          <input
            value={search}
            onChange={(event) => { ++request.current; setLoading(true); setSearch(event.target.value); setPage(0); }}
            placeholder="Search name or member ID"
            aria-label="Search members"
            maxLength={80}
          />
        </div>
        <select
          value={status}
          onChange={(event) => { ++request.current; setLoading(true); setStatus(event.target.value as MemberStatus); setPage(0); }}
          aria-label="Filter members by status"
        >
          {Object.entries(statusLabels).map(([value, label]) => (
            <option key={value} value={value}>{label}</option>
          ))}
        </select>
        <button type="button" className="primary-button members-add-button" disabled={submitting} onClick={() => {
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
          <button type="button" className="secondary-button" disabled={loading || submitting} onClick={() => {
            ++request.current; setLoading(true); setRefresh((value) => value + 1);
          }}>Refresh members</button>
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
                <th>Registration status</th>
                <th>Date registered</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={5} className="members-empty">Loading members…</td></tr>
              ) : loadFailed ? <tr><td colSpan={5} className="members-empty">Member directory unavailable. Refresh to retry.</td></tr> : members.length === 0 ? (
                <tr><td colSpan={5} className="members-empty">
                  <strong>No members found</strong>
                  <span>Register a member to begin testing the member workflow.</span>
                </td></tr>
              ) : members.map((member) => (
                <tr key={member.id}>
                  <td><strong>{member.fullName}</strong></td>
                  <td className="member-code">{member.memberCode}</td>
                  <td><span className={`member-status member-status-${member.status}`}>{statusLabels[member.status]}</span></td>
                  <td>{new Date(member.createdAt).toLocaleDateString('en-PH', {
                    year: 'numeric', month: 'short', day: 'numeric', timeZone: 'Asia/Manila',
                  })}</td>
                  <td>{member.status === 'pending' && (
                    <button type="button" className="secondary-button" disabled={submitting} onClick={() => {
                      setApprovalReason('');
                      setErrorMessage('');
                      setNotice('');
                      setApprovalMember(member);
                    }} aria-label={`Approve registration for ${member.fullName}, ${member.memberCode}`}>Approve registration</button>
                  )}{member.status === 'active' && <div className="payment-row-actions">
                    <button type="button" className="secondary-button" disabled={submitting} onClick={() => setPinHandoff({ member, purpose: 'enrollment' })}>PIN setup link</button>
                    <button type="button" className="secondary-button" disabled={submitting} onClick={() => setPinHandoff({ member, purpose: 'reset' })}>PIN reset link</button>
                  </div>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="purchase-history-pagination">
        <button type="button" className="secondary-button" onClick={() => { ++request.current; setLoading(true); setPage((current) => current - 1); }} disabled={loading || page === 0}>Previous</button>
        <span>Page {page + 1}</span>
        <button type="button" className="secondary-button" onClick={() => { ++request.current; setLoading(true); setPage((current) => current + 1); }} disabled={loading || members.length < pageSize}>Next</button>
      </div>

      <p className="members-footnote">
        New registrations are saved as <strong>Pending</strong>. No payment or membership is created by registration.
      </p>

      {pinHandoff && <PinHandoffDialog member={pinHandoff.member} purpose={pinHandoff.purpose} onClose={() => setPinHandoff(null)} />}

      {approvalMember && (
        <div className="member-modal-backdrop" role="presentation" onMouseDown={(event) => {
          if (event.target === event.currentTarget && !submitting) setApprovalMember(null);
        }}>
          <section className="member-modal" role="dialog" aria-modal="true" aria-labelledby="approve-member-title" aria-describedby="approve-member-description" onKeyDown={(event) => {
            if (event.key === 'Escape' && !submitting) { event.preventDefault(); setApprovalMember(null); }
            if (event.key === 'Tab') {
              const controls = event.currentTarget.querySelectorAll<HTMLElement>('button:not(:disabled), textarea:not(:disabled)');
              const first = controls[0];
              const last = controls[controls.length - 1];
              if (controls.length === 0) { event.preventDefault(); return; }
              if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
              else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
            }
          }}>
            <div className="member-modal-heading">
              <div>
                <p className="eyebrow">REGISTRATION REVIEW</p>
                <h2 id="approve-member-title">Approve registration</h2>
                <p id="approve-member-description">{approvalMember.fullName} ({approvalMember.memberCode}). Approval alone does not grant membership access or confirm payment.</p>
              </div>
              <button type="button" className="modal-close" onClick={() => setApprovalMember(null)} disabled={submitting} aria-label="Close approval dialog">Close</button>
            </div>
            <form onSubmit={handleApprove}>
              <label className="member-form-field" htmlFor="approval-reason">Approval reason (5 to 500 characters)
                <textarea id="approval-reason" ref={approvalReasonInput} value={approvalReason} onChange={(event) => setApprovalReason(event.target.value)} required minLength={5} maxLength={500} disabled={submitting} />
              </label>
              {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
              <div className="member-modal-actions">
                <button type="button" className="secondary-button" onClick={() => setApprovalMember(null)} disabled={submitting}>Close</button>
                <button type="submit" className="primary-button" disabled={submitting || approvalReason.trim().length < 5}>{submitting ? 'Approving registration...' : 'Approve registration'}</button>
              </div>
            </form>
          </section>
        </div>
      )}

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
