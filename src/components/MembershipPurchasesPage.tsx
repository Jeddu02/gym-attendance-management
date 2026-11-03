import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';

type Member = {
  id: string;
  memberCode: string;
  fullName: string;
  status: 'active';
};

type Plan = {
  id: string;
  name: string;
  pricePhp: number | string;
  isActive: boolean;
};

type PurchaseStatus =
  | 'pending_payment'
  | 'pending_activation'
  | 'active'
  | 'expired'
  | 'payment_review';

type Purchase = {
  id: string;
  memberName: string;
  memberCode: string;
  planName: string;
  pricePhp: number | string;
  purchaseStatus: PurchaseStatus;
  activationDate: string | null;
  expiryDate: string | null;
  createdAt: string;
};

const pageSize = 50;
const statusOptions: { value: 'all' | PurchaseStatus; label: string }[] = [
  { value: 'all', label: 'All statuses' },
  { value: 'pending_payment', label: 'Pending payment' },
  { value: 'pending_activation', label: 'Pending activation' },
  { value: 'active', label: 'Active' },
  { value: 'expired', label: 'Expired' },
  { value: 'payment_review', label: 'Payment review' },
];

function formatPrice(value: number | string): string {
  const amount = Number(value);
  return Number.isFinite(amount)
    ? amount.toLocaleString('en-PH', { style: 'currency', currency: 'PHP' })
    : '—';
}

function formatDate(value: string | null): string {
  if (!value) return '—';
  const date = new Date(`${value.slice(0, 10)}T00:00:00+08:00`);
  return Number.isNaN(date.getTime())
    ? '—'
    : date.toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric', timeZone: 'Asia/Manila' });
}

function formatDateTime(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? '—'
    : date.toLocaleString('en-PH', { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Manila' });
}

function statusLabel(status: PurchaseStatus): string {
  return statusOptions.find((option) => option.value === status)?.label ?? status;
}

function statusClass(status: PurchaseStatus): string {
  if (status === 'active') return 'member-status-active';
  if (status === 'payment_review' || status === 'expired') return 'member-status-suspended';
  return 'member-status-pending';
}

export function MembershipPurchasesPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [memberId, setMemberId] = useState('');
  const [planId, setPlanId] = useState('');
  const [loadingOptions, setLoadingOptions] = useState(true);
  const [loadingPurchases, setLoadingPurchases] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [optionsError, setOptionsError] = useState('');
  const [historyError, setHistoryError] = useState('');
  const [notice, setNotice] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<'all' | PurchaseStatus>('all');
  const [page, setPage] = useState(0);
  const [purchases, setPurchases] = useState<Purchase[]>([]);

  const loadOptions = useCallback(async () => {
    setLoadingOptions(true);
    setOptionsError('');
    try {
      const [memberResult, planResult] = await Promise.all([
        getSupabaseClient().functions.invoke('owner-list-members', {
          method: 'POST', body: { search: '', status: 'active', limit: 100, offset: 0 },
        }),
        getSupabaseClient().functions.invoke('owner-list-membership-plans', {
          method: 'POST', body: {},
        }),
      ]);
      if (memberResult.error) throw memberResult.error;
      if (planResult.error) throw planResult.error;
      if (!Array.isArray(memberResult.data?.members) || !Array.isArray(planResult.data?.plans)) {
        throw new Error('Invalid purchase options response');
      }
      const activeMembers = memberResult.data.members as Member[];
      const activePlans = (planResult.data.plans as Plan[]).filter((plan) => plan.isActive);
      setMembers(activeMembers);
      setPlans(activePlans);
      setMemberId((current) => activeMembers.some((member) => member.id === current) ? current : activeMembers[0]?.id ?? '');
      setPlanId((current) => activePlans.some((plan) => plan.id === current) ? current : activePlans[0]?.id ?? '');
    } catch {
      setOptionsError('Could not load active members and plans. Please refresh and try again.');
    } finally {
      setLoadingOptions(false);
    }
  }, []);

  const loadPurchases = useCallback(async () => {
    setLoadingPurchases(true);
    setHistoryError('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-list-membership-purchases',
        { method: 'POST', body: { search, status, limit: pageSize, offset: page * pageSize } },
      );
      if (error) throw error;
      if (!Array.isArray(data?.purchases)) throw new Error('Invalid purchase history response');
      setPurchases(data.purchases as Purchase[]);
    } catch {
      setHistoryError('Could not load purchase history. Please refresh and try again.');
    } finally {
      setLoadingPurchases(false);
    }
  }, [page, search, status]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadOptions(), 0);
    return () => window.clearTimeout(timer);
  }, [loadOptions]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadPurchases(), 0);
    return () => window.clearTimeout(timer);
  }, [loadPurchases]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(0);
      setSearch(searchInput.trim());
    }, 250);
    return () => window.clearTimeout(timer);
  }, [searchInput]);

  const selectedPlan = plans.find((plan) => plan.id === planId);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!memberId || !planId) return;
    setSubmitting(true);
    setOptionsError('');
    setNotice('');
    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-create-membership-purchase',
        { method: 'POST', body: { memberId, planId } },
      );
      if (error) throw error;
      if (data?.success !== true || !data?.purchase?.id) throw new Error('Invalid purchase response');
      setNotice(`Purchase created. Reference: ${data.purchase.id}. Status: Pending payment.`);
      setPage(0);
      setSearchInput('');
      setSearch('');
      setStatus('all');
      await loadPurchases();
    } catch (error) {
      const message = error && typeof error === 'object' && 'message' in error ? String(error.message) : '';
      if (message.includes('MEMBER_NOT_ACTIVE')) setOptionsError('This member is no longer active. Refresh the list.');
      else if (message.includes('MEMBERSHIP_PLAN_NOT_ACTIVE')) setOptionsError('This plan is no longer active. Refresh the list.');
      else if (message.includes('OWNER_ACCESS_REQUIRED')) setOptionsError('Your account does not have active Owner access.');
      else setOptionsError('Purchase could not be created. Please refresh and try again.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="plans-module purchase-module">
      <div className="plans-toolbar">
        <div>
          <strong>New membership purchase</strong>
          <p>Create a purchase for an active member using an active plan.</p>
        </div>
        <button type="button" className="secondary-button" onClick={() => void loadOptions()} disabled={loadingOptions || submitting}>
          Refresh options
        </button>
      </div>

      {notice && <p className="members-notice" role="status">{notice}</p>}
      {optionsError && <p className="members-error" role="alert">{optionsError}</p>}

      <div className="members-table-card purchase-form-card">
        <div className="members-table-heading">
          <div><h2>Purchase details</h2><p>{loadingOptions ? 'Loading available options…' : 'Select the member and membership plan.'}</p></div>
        </div>
        {loadingOptions ? <p className="members-empty">Loading active members and plans…</p> : (
          <form className="purchase-form" onSubmit={handleCreate}>
            <label className="member-form-field">Active member
              <select value={memberId} onChange={(event) => setMemberId(event.target.value)} required disabled={submitting || members.length === 0}>
                {members.length === 0 ? <option value="">No active members available</option> : members.map((member) => <option key={member.id} value={member.id}>{member.fullName} — {member.memberCode}</option>)}
              </select>
            </label>
            <label className="member-form-field">Active membership plan
              <select value={planId} onChange={(event) => setPlanId(event.target.value)} required disabled={submitting || plans.length === 0}>
                {plans.length === 0 ? <option value="">No active plans available</option> : plans.map((plan) => <option key={plan.id} value={plan.id}>{plan.name} — {formatPrice(plan.pricePhp)}</option>)}
              </select>
            </label>
            <div className="purchase-price-preview"><span>Purchase price</span><strong>{selectedPlan ? formatPrice(selectedPlan.pricePhp) : '—'}</strong><small>This price is saved as a snapshot and will not change if the plan is edited later.</small></div>
            {(members.length === 0 || plans.length === 0) && <p className="members-footnote">{members.length === 0 ? 'At least one active member is required. Pending registrations must be approved first.' : 'Create or activate a membership plan before creating a purchase.'}</p>}
            <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={submitting || loadingOptions || !memberId || !planId}>{submitting ? 'Creating purchase…' : 'Create pending purchase'}</button></div>
          </form>
        )}
      </div>

      <div className="members-table-card purchase-history-card">
        <div className="members-table-heading">
          <div><h2>Purchase history</h2><p>{loadingPurchases ? 'Loading purchases…' : `${purchases.length} purchase${purchases.length === 1 ? '' : 's'} on this page`}</p></div>
          <button type="button" className="secondary-button" onClick={() => void loadPurchases()} disabled={loadingPurchases}>Refresh history</button>
        </div>
        <div className="purchase-history-filters">
          <label>Search purchases
            <input type="search" value={searchInput} onChange={(event) => setSearchInput(event.target.value)} maxLength={80} placeholder="Reference, member, code, or plan" />
          </label>
          <label>Status
            <select value={status} onChange={(event) => { setStatus(event.target.value as 'all' | PurchaseStatus); setPage(0); }}>
              {statusOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>
        </div>
        {historyError && <p className="members-error purchase-history-error" role="alert">{historyError}</p>}
        <div className="members-table-wrap">
          <table className="members-table purchase-history-table">
            <thead><tr><th>Purchase reference</th><th>Member</th><th>Member code</th><th>Plan</th><th>Price snapshot</th><th>Status</th><th>Activation</th><th>Expiry</th><th>Created</th></tr></thead>
            <tbody>
              {loadingPurchases ? <tr><td colSpan={9} className="members-empty">Loading purchase history…</td></tr>
                : purchases.length === 0 ? <tr><td colSpan={9} className="members-empty"><strong>No purchases found</strong><span>Purchases matching your search and status will appear here.</span></td></tr>
                  : purchases.map((purchase) => <tr key={purchase.id}>
                    <td><strong className="purchase-reference">{purchase.id}</strong></td>
                    <td>{purchase.memberName}</td><td>{purchase.memberCode}</td><td>{purchase.planName}</td>
                    <td className="plan-price">{formatPrice(purchase.pricePhp)}</td>
                    <td><span className={`member-status ${statusClass(purchase.purchaseStatus)}`}>{statusLabel(purchase.purchaseStatus)}</span></td>
                    <td>{formatDate(purchase.activationDate)}</td><td>{formatDate(purchase.expiryDate)}</td><td>{formatDateTime(purchase.createdAt)}</td>
                  </tr>)}
            </tbody>
          </table>
        </div>
        <div className="purchase-history-pagination">
          <button type="button" className="secondary-button" onClick={() => setPage((current) => Math.max(0, current - 1))} disabled={loadingPurchases || page === 0}>Previous</button>
          <span>Page {page + 1}</span>
          <button type="button" className="secondary-button" onClick={() => setPage((current) => current + 1)} disabled={loadingPurchases || purchases.length < pageSize}>Next</button>
        </div>
      </div>

      <p className="members-footnote">Creating a purchase does not record payment or activate membership. Payment must be recorded and verified before activation.</p>
    </section>
  );
}
