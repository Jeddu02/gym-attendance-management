import { useEffect, useRef, useState } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';

type AttendanceStatus = 'valid' | 'invalidated_payment' | 'invalidated_correction' | 'review';
type Attendance = {
  id: string;
  memberId: string | null;
  memberCode: string | null;
  memberName: string | null;
  walkinRequestId: string | null;
  gymLocalDate: string;
  checkedInAt: string;
  attendanceStatus: AttendanceStatus;
  resolutionReason: string | null;
};

const pageSize = 50;
const statusLabels: Record<'all' | AttendanceStatus, string> = {
  all: 'All attendance history', valid: 'Valid', invalidated_payment: 'Invalidated payment', invalidated_correction: 'Invalidated correction', review: 'Review',
};

function gymTime(value: string): string {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date.toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' }) : 'Unavailable';
}

export function AttendancePage() {
  const request = useRef(0);
  const [attendance, setAttendance] = useState<Attendance[]>([]);
  const [search, setSearch] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [status, setStatus] = useState<'all' | AttendanceStatus>('all');
  const [page, setPage] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState('');

  function invalidate() {
    ++request.current;
    setLoading(true);
    setAttendance([]);
    setErrorMessage('');
  }

  useEffect(() => {
    let active = true;
    const ticket = ++request.current;
    async function load() {
      setLoading(true);
      setAttendance([]);
      setErrorMessage('');
      try {
        if (fromDate && toDate && fromDate > toDate) {
          setErrorMessage('The end date must be on or after the start date.');
          return;
        }
        const { data, error } = await getSupabaseClient().functions.invoke('owner-attendance', {
          method: 'POST', body: { search: search.trim(), fromDate, toDate, status, limit: pageSize, offset: page * pageSize },
        });
        if (!active || ticket !== request.current) return;
        if (error || data?.success !== true || !Array.isArray(data.attendance)) throw new Error('Invalid attendance response');
        setAttendance(data.attendance as Attendance[]);
      } catch {
        if (active && ticket === request.current) setErrorMessage('Could not load attendance history. Please try again.');
      } finally {
        if (active && ticket === request.current) setLoading(false);
      }
    }
    const timer = window.setTimeout(() => void load(), 250);
    return () => { active = false; window.clearTimeout(timer); };
  }, [search, fromDate, toDate, status, page, refresh]);

  return (
    <section className="plans-module" aria-label="Attendance history">
      <div className="plans-toolbar">
        <div><strong>Attendance history</strong><p>Original check-ins remain in history when payment eligibility is invalidated.</p></div>
        <button type="button" className="secondary-button" disabled={loading || attendance.length === 0} onClick={() => downloadCsv(
          `gymforce-attendance-page-${page + 1}.csv`,
          ['Gym date', 'Check-in time (Asia/Manila)', 'Attendance reference', 'Member name', 'Member ID', 'Walk-in reference', 'Validity status', 'Latest resolution reason'],
          attendance.map((row) => [row.gymLocalDate, gymTime(row.checkedInAt), row.id, row.memberName, row.memberCode, row.walkinRequestId, statusLabels[row.attendanceStatus], row.resolutionReason]),
        )}>Export this page (CSV)</button>
        <button type="button" className="secondary-button" disabled={loading} onClick={() => { invalidate(); setRefresh((current) => current + 1); }}>Refresh attendance</button>
      </div>
      <div className="purchase-history-filters">
        <label>Search attendance<input type="search" value={search} maxLength={80} placeholder="Member name, ID, or reference" onChange={(event) => { invalidate(); setSearch(event.target.value); setPage(0); }} /></label>
        <label>From gym date<input type="date" value={fromDate} max={toDate || undefined} onChange={(event) => { invalidate(); setFromDate(event.target.value); setPage(0); }} /></label>
        <label>Through gym date<input type="date" value={toDate} min={fromDate || undefined} onChange={(event) => { invalidate(); setToDate(event.target.value); setPage(0); }} /></label>
        <label>Validity status<select value={status} onChange={(event) => { invalidate(); setStatus(event.target.value as 'all' | AttendanceStatus); setPage(0); }}>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      </div>
      {errorMessage && <p className="members-error" role="alert">{errorMessage}</p>}
      <div className="members-table-card">
        <div className="members-table-heading"><div><h2>Recorded check-ins</h2><p>{loading ? 'Loading attendance...' : `${attendance.length} check-in${attendance.length === 1 ? '' : 's'} on this page`}</p></div></div>
        <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Gym date</th><th>Time (Asia/Manila)</th><th>Attendance reference</th><th>Member / walk-in</th><th>Validity status</th><th>Latest resolution reason</th></tr></thead><tbody>
          {loading ? <tr><td colSpan={6} className="members-empty">Loading attendance history...</td></tr> : errorMessage ? <tr><td colSpan={6} className="members-empty">Attendance history unavailable. Refresh to retry.</td></tr> : attendance.length === 0 ? <tr><td colSpan={6} className="members-empty"><strong>No check-ins found</strong><span>Adjust the search, gym dates, or validity filter.</span></td></tr> : attendance.map((row) => <tr key={row.id}>
            <td>{row.gymLocalDate}</td><td>{gymTime(row.checkedInAt)}</td><td className="payment-reference">{row.id}</td>
            <td>{row.memberId ? <><strong>{row.memberName || 'Member'}</strong><small className="payment-subline">{row.memberCode || 'No member code recorded'}</small></> : <><strong>Walk-in</strong><small className="payment-subline">{row.walkinRequestId || 'No reference recorded'}</small></>}</td>
            <td><span className={`member-status ${row.attendanceStatus === 'valid' ? 'member-status-active' : 'member-status-suspended'}`}>{statusLabels[row.attendanceStatus]}</span></td><td>{row.resolutionReason || 'No resolution reason recorded'}</td>
          </tr>)}
        </tbody></table></div>
        <div className="purchase-history-pagination"><button type="button" className="secondary-button" disabled={loading || page === 0} onClick={() => { invalidate(); setPage((current) => current - 1); }}>Previous</button><span>Page {page + 1}</span><button type="button" className="secondary-button" disabled={loading || attendance.length < pageSize || (page + 1) * pageSize > 100000} onClick={() => { invalidate(); setPage((current) => current + 1); }}>Next</button></div>
      </div>
      <p className="members-footnote">Date filters use inclusive Asia/Manila gym dates. Invalidated and review entries remain visible in history and are excluded from valid-attendance totals.</p>
    </section>
  );
}
