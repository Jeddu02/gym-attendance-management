import { useEffect, useRef, useState } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';

type AuditEvent = {
  id: string;
  actorUserId: string | null;
  eventType: string;
  subjectType: string;
  subjectId: string | null;
  createdAt: string;
  reason: string | null;
};

const pageSize = 50;

function formatDateTime(value: string): string {
  const date = new Date(value);
  return Number.isFinite(date.getTime())
    ? date.toLocaleString('en-PH', { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Manila' })
    : 'Unavailable';
}

export function AuditLogPage() {
  const request = useRef(0);
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [search, setSearch] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState('');

  function invalidate() {
    ++request.current;
    setLoading(true);
    setEvents([]);
  }

  useEffect(() => {
    let active = true;
    const ticket = ++request.current;
    async function load() {
      setLoading(true);
      setEvents([]);
      setErrorMessage('');
      try {
        if (fromDate && toDate && fromDate > toDate) {
          setErrorMessage('The end date must be on or after the start date.');
          return;
        }
        const { data, error } = await getSupabaseClient().functions.invoke('owner-reporting', {
          method: 'POST', body: { action: 'audit', search: search.trim(), fromDate, toDate, limit: pageSize, offset: page * pageSize },
        });
        if (!active || ticket !== request.current) return;
        if (error || data?.success !== true || !Array.isArray(data.events)) throw new Error('Invalid audit response');
        setEvents(data.events as AuditEvent[]);
      } catch {
        if (active && ticket === request.current) setErrorMessage('Could not load audit history. Please try again.');
      } finally {
        if (active && ticket === request.current) setLoading(false);
      }
    }
    const timer = window.setTimeout(() => void load(), 250);
    return () => { active = false; window.clearTimeout(timer); };
  }, [search, fromDate, toDate, page, refresh]);

  return (
    <section className="plans-module" aria-label="Audit history">
      <div className="plans-toolbar">
        <div><strong>Audit history</strong><p>Read-only history of recorded Owner actions and system events.</p></div>
        <button type="button" className="secondary-button" disabled={loading || events.length === 0} onClick={() => downloadCsv(
          `gymforce-audit-page-${page + 1}.csv`,
          ['Time (Asia/Manila)', 'Event', 'Subject type', 'Subject reference', 'Actor', 'Reason'],
          events.map((event) => [formatDateTime(event.createdAt), event.eventType, event.subjectType, event.subjectId, event.actorUserId, event.reason]),
        )}>Export this page (CSV)</button>
        <button type="button" className="secondary-button" disabled={loading} onClick={() => { invalidate(); setRefresh((current) => current + 1); }}>Refresh audit history</button>
      </div>
      <div className="purchase-history-filters">
        <label>Search audit history<input type="search" value={search} maxLength={80} placeholder="Event or subject" onChange={(event) => { invalidate(); setSearch(event.target.value); setPage(0); }} /></label>
        <label>From gym date<input type="date" value={fromDate} max={toDate || undefined} onChange={(event) => { invalidate(); setFromDate(event.target.value); setPage(0); }} /></label>
        <label>Through gym date<input type="date" value={toDate} min={fromDate || undefined} onChange={(event) => { invalidate(); setToDate(event.target.value); setPage(0); }} /></label>
      </div>
      {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
      <div className="members-table-card">
        <div className="members-table-heading"><div><h2>Recorded events</h2><p>{loading ? 'Loading events...' : `${events.length} event${events.length === 1 ? '' : 's'} on this page`}</p></div></div>
        <div className="members-table-wrap">
          <table className="members-table">
            <thead><tr><th>Time (Asia/Manila)</th><th>Event</th><th>Subject</th><th>Actor</th><th>Reason</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={5} className="members-empty">Loading audit history...</td></tr>
                : events.length === 0 ? <tr><td colSpan={5} className="members-empty"><strong>No events found</strong><span>Adjust the search or gym-date range to review other events.</span></td></tr>
                  : events.map((event) => (
                    <tr key={event.id}>
                      <td>{formatDateTime(event.createdAt)}</td>
                      <td>{event.eventType}</td>
                      <td>{event.subjectType}<small className="payment-subline">{event.subjectId || 'No subject reference'}</small></td>
                      <td>{event.actorUserId || 'No user actor recorded'}</td>
                      <td>{event.reason || 'No reason recorded'}</td>
                    </tr>
                  ))}
            </tbody>
          </table>
        </div>
        <div className="purchase-history-pagination">
          <button type="button" className="secondary-button" disabled={loading || page === 0} onClick={() => { invalidate(); setPage((current) => current - 1); }}>Previous</button>
          <span>Page {page + 1}</span>
          <button type="button" className="secondary-button" disabled={loading || events.length < pageSize || (page + 1) * pageSize > 100000} onClick={() => { invalidate(); setPage((current) => current + 1); }}>Next</button>
        </div>
      </div>
      <p className="members-footnote">Date filters use Asia/Manila business dates. Audit records are displayed without raw event payloads.</p>
    </section>
  );
}
