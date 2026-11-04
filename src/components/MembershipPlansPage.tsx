import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { getSupabaseClient } from '../lib/supabase';

type MembershipPlan = {
  id: string;
  name: string;
  pricePhp: number | string;
  isActive: boolean;
  createdAt: string;
};

function friendlyError(error: unknown): string {
  const message = error && typeof error === 'object' && 'message' in error
    ? String(error.message)
    : '';

  if (message.includes('MEMBERSHIP_PLAN_NAME_EXISTS')) {
    return 'A plan with the same name already exists.';
  }
  if (message.includes('MEMBERSHIP_PLAN_NOT_FOUND')) {
    return 'This plan no longer exists. Refresh and try again.';
  }
  if (message.includes('OWNER_ACCESS_REQUIRED')) {
    return 'Your account does not have active Owner access.';
  }

  return 'The request could not be completed. Please try again.';
}

function formatPrice(value: number | string): string {
  const amount = Number(value);

  return Number.isFinite(amount)
    ? amount.toLocaleString('en-PH', {
        style: 'currency',
        currency: 'PHP',
      })
    : '—';
}

export function MembershipPlansPage() {
  const [plans, setPlans] = useState<MembershipPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<MembershipPlan | null>(null);
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [notice, setNotice] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const fetchPlans = useCallback(async (): Promise<MembershipPlan[]> => {
    const { data, error } = await getSupabaseClient().functions.invoke(
      'owner-list-membership-plans',
      {
        method: 'POST',
        body: {},
      },
    );

    if (error) throw error;

    if (!data || !Array.isArray(data.plans)) {
      throw new Error('Invalid plan-list response');
    }

    return data.plans as MembershipPlan[];
  }, []);

  const loadPlans = useCallback(async () => {
    setLoading(true);
    setErrorMessage('');

    try {
      const fetchedPlans = await fetchPlans();
      setPlans(fetchedPlans);
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setLoading(false);
    }
  }, [fetchPlans]);

  useEffect(() => {
    let cancelled = false;

    async function initializePlans() {
      try {
        const fetchedPlans = await fetchPlans();

        if (!cancelled) {
          setPlans(fetchedPlans);
        }
      } catch (error) {
        if (!cancelled) {
          setErrorMessage(friendlyError(error));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void initializePlans();

    return () => {
      cancelled = true;
    };
  }, [fetchPlans]);

  function openCreate() {
    setEditing(null);
    setName('');
    setPrice('');
    setIsActive(true);
    setNotice('');
    setErrorMessage('');
    setModalOpen(true);
  }

  function openEdit(plan: MembershipPlan) {
    setEditing(plan);
    setName(plan.name);
    setPrice(String(plan.pricePhp));
    setIsActive(plan.isActive);
    setNotice('');
    setErrorMessage('');
    setModalOpen(true);
  }

  async function handleSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const normalizedPrice = price.trim();

    if (
      !/^\d{1,10}(?:\.\d{1,2})?$/.test(normalizedPrice) ||
      Number(normalizedPrice) <= 0
    ) {
      setErrorMessage('Enter a valid price with up to two decimal places.');
      return;
    }

    setSubmitting(true);
    setErrorMessage('');
    setNotice('');

    try {
      const { data, error } = await getSupabaseClient().functions.invoke(
        'owner-save-membership-plan',
        {
          method: 'POST',
          body: {
            ...(editing ? { id: editing.id } : {}),
            name: name.trim(),
            pricePhp: normalizedPrice,
            isActive,
          },
        },
      );

      if (error) throw error;

      if (data?.success !== true || !data?.plan?.id) {
        throw new Error('Invalid plan-save response');
      }

      setModalOpen(false);
      setNotice(editing ? 'Membership plan updated.' : 'Membership plan created.');

      await loadPlans();
    } catch (error) {
      setErrorMessage(friendlyError(error));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="plans-module">
      <div className="plans-toolbar">
        <div>
          <strong>Membership plans</strong>
          <p>Create and maintain plans available for future purchases.</p>
        </div>

        <button
          type="button"
          className="primary-button plans-add-button"
          onClick={openCreate}
        >
          + Add plan
        </button>
      </div>

      {notice && (
        <p className="members-notice" role="status">
          {notice}
        </p>
      )}

      {errorMessage && !modalOpen && (
        <p className="members-error" role="alert">
          {errorMessage}
        </p>
      )}

      <div className="members-table-card">
        <div className="members-table-heading">
          <div>
            <h2>Plan directory</h2>
            <p>
              {loading
                ? 'Loading plans...'
                : `${plans.length} plan${plans.length === 1 ? '' : 's'}`}
            </p>
          </div>

          <button
            type="button"
            className="secondary-button"
            onClick={() => void loadPlans()}
            disabled={loading}
          >
            Refresh
          </button>
        </div>

        <div className="members-table-wrap">
          <table className="members-table plans-table">
            <thead>
              <tr>
                <th>Plan name</th>
                <th>Price</th>
                <th>Availability</th>
                <th>Created</th>
                <th>Action</th>
              </tr>
            </thead>

            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="members-empty">
                    Loading membership plans...
                  </td>
                </tr>
              ) : plans.length === 0 ? (
                <tr>
                  <td colSpan={5} className="members-empty">
                    <strong>No membership plans yet</strong>
                    <span>
                      Add a plan to make it available for future purchases.
                    </span>
                  </td>
                </tr>
              ) : (
                plans.map((plan) => (
                  <tr key={plan.id}>
                    <td>
                      <strong>{plan.name}</strong>
                    </td>

                    <td className="plan-price">
                      {formatPrice(plan.pricePhp)}
                    </td>

                    <td>
                      <span
                        className={`member-status ${
                          plan.isActive
                            ? 'member-status-active'
                            : 'member-status-suspended'
                        }`}
                      >
                        {plan.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>

                    <td>
                      {new Date(plan.createdAt).toLocaleDateString('en-PH', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                      })}
                    </td>

                    <td>
                      <button
                        type="button"
                        className="secondary-button plan-edit-button"
                        onClick={() => openEdit(plan)}
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <p className="members-footnote">
        Changes apply to future purchases only. Existing purchases retain
        their recorded price. Inactive plans remain visible but cannot be
        offered for new purchases.
      </p>

      {modalOpen && (
        <div
          className="member-modal-backdrop"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget && !submitting) {
              setModalOpen(false);
            }
          }}
        >
          <section
            className="member-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="membership-plan-title"
          >
            <div className="member-modal-heading">
              <div>
                <p className="eyebrow">MEMBERSHIP MANAGEMENT</p>
                <h2 id="membership-plan-title">
                  {editing ? 'Edit membership plan' : 'Add membership plan'}
                </h2>
                <p>
                  Plan changes do not modify existing membership purchases.
                </p>
              </div>

              <button
                type="button"
                className="modal-close"
                onClick={() => setModalOpen(false)}
                disabled={submitting}
                aria-label="Close"
              >
                ×
              </button>
            </div>

            <form onSubmit={handleSave}>
              <label className="member-form-field">
                Plan name
                <input
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  required
                  maxLength={80}
                  placeholder="e.g. Monthly Membership"
                  disabled={submitting}
                />
              </label>

              <label className="member-form-field">
                Price (PHP)
                <input
                  value={price}
                  onChange={(event) => setPrice(event.target.value)}
                  required
                  type="text"
                  inputMode="decimal"
                  maxLength={13}
                  placeholder="e.g. 999.00"
                  disabled={submitting}
                />
              </label>

              <label className="plan-active-toggle">
                <input
                  type="checkbox"
                  checked={isActive}
                  onChange={(event) => setIsActive(event.target.checked)}
                  disabled={submitting}
                />

                <span>
                  <strong>Active plan</strong>
                  <small>
                    Inactive plans cannot be used for new purchases.
                  </small>
                </span>
              </label>

              {errorMessage && (
                <p className="members-error" role="alert">
                  {errorMessage}
                </p>
              )}

              <div className="member-modal-actions">
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => setModalOpen(false)}
                  disabled={submitting}
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  className="primary-button"
                  disabled={submitting}
                >
                  {submitting
                    ? 'Saving...'
                    : editing
                    ? 'Save changes'
                    : 'Create plan'}
                </button>
              </div>
            </form>
          </section>
        </div>
      )}
    </section>
  );
}
