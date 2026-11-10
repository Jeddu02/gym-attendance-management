import { useEffect, useRef, useState } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';
import { formatPhp } from '../lib/money';

type Summary = {
  totalMembers: number;
  approvedMembers: number;
  currentEntitlements: number;
  todayValidCheckins: number;
  confirmedMembershipIncomePhp: number | string;
  confirmedWalkinIncomePhp: number | string;
};

function php(value: number | string): string {
  try { return formatPhp(value); } catch { return 'Unavailable'; }
}

export function OverviewPage() {
  const request = useRef(0);
  const [refresh, setRefresh] = useState(0);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState('');

  useEffect(() => {
    let active = true;
    const ticket = ++request.current;
    async function load() {
      setLoading(true);
      setSummary(null);
      setErrorMessage('');
      try {
        const { data, error } = await getSupabaseClient().functions.invoke('owner-reporting', {
          method: 'POST', body: { action: 'summary' },
        });
        if (!active || ticket !== request.current) return;
        if (error || data?.success !== true || !data.summary) throw new Error('Invalid summary response');
        const next = data.summary as Summary;
        if (![next.totalMembers, next.approvedMembers, next.currentEntitlements, next.todayValidCheckins].every((value) => Number.isSafeInteger(value) && value >= 0)
          || ![next.confirmedMembershipIncomePhp, next.confirmedWalkinIncomePhp].every((value) => { try { formatPhp(value); return true; } catch { return false; } })) {
          throw new Error('Invalid summary values');
        }
        setSummary(next);
      } catch {
        if (active && ticket === request.current) setErrorMessage('Could not load the overview. Please try again.');
      } finally {
        if (active && ticket === request.current) setLoading(false);
      }
    }
    const timer = window.setTimeout(() => void load(), 0);
    return () => { active = false; window.clearTimeout(timer); };
  }, [refresh]);

  const cards = summary ? [
    { label: 'Total registered members', value: summary.totalMembers, detail: 'All registration statuses' },
    { label: 'Approved registrations', value: summary.approvedMembers, detail: 'Approval alone does not grant access' },
    { label: 'Current paid entitlements', value: summary.currentEntitlements, detail: 'Eligibility evaluated by the server' },
    { label: "Today's valid check-ins", value: summary.todayValidCheckins, detail: 'Gym date in Asia/Manila' },
    { label: 'Confirmed membership income', value: php(summary.confirmedMembershipIncomePhp), detail: 'All time; confirmed payments only' },
    { label: 'Confirmed walk-in income', value: php(summary.confirmedWalkinIncomePhp), detail: 'All time; confirmed payments only' },
  ] : [];

  return (
    <section aria-label="Gym overview">
      <div className="section-heading">
        <div><h2>Gym overview</h2><p>Server-validated membership, attendance, and confirmed income totals.</p></div>
        <button type="button" className="secondary-button" disabled={loading || !summary} onClick={() => {
          if (!summary) return;
          downloadCsv('gymforce-overview.csv', ['Metric', 'Value', 'Scope'], [
            ['Total registered members', summary.totalMembers, 'All registration statuses'],
            ['Approved registrations', summary.approvedMembers, 'Registration approval only'],
            ['Current paid entitlements', summary.currentEntitlements, 'Current gym date'],
            ['Valid check-ins', summary.todayValidCheckins, 'Current gym date (Asia/Manila)'],
            ['Confirmed membership income (PHP)', summary.confirmedMembershipIncomePhp, 'All time'],
            ['Confirmed walk-in income (PHP)', summary.confirmedWalkinIncomePhp, 'All time'],
          ]);
        }}>Export summary (CSV)</button>
        <button type="button" className="secondary-button" disabled={loading} onClick={() => {
          ++request.current;
          setLoading(true);
          setRefresh((current) => current + 1);
        }}>Refresh overview</button>
      </div>
      {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
      {loading ? <p className="members-empty" role="status">Loading overview...</p> : summary && (
        <div className="summary-grid">
          {cards.map((card) => (
            <article className="summary-card" key={card.label}>
              <div className="summary-card-top"><span>{card.label}</span></div>
              <div className="summary-value">{card.value}</div>
              <p>{card.detail}</p>
            </article>
          ))}
        </div>
      )}
      <p className="members-footnote">Confirmed income excludes receipts awaiting verification or allocation. These totals are separate from physical cash-drawer reconciliation.</p>
    </section>
  );
}
