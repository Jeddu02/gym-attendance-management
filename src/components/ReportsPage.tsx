import { useEffect, useRef, useState } from 'react';
import { getSupabaseClient } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';
import { formatPhp } from '../lib/money';
type Income = { gymLocalDate: string; source: 'membership' | 'walkin'; paymentMethod: string; amountPhp: string; transactionCount: number };
type Expiry = { purchaseId: string; memberCode: string; memberName: string; activationDate: string; expiryDate: string; daysToExpiry: number };
export function ReportsPage() {
  const request = useRef(0);
  const [income, setIncome] = useState<Income[] | null>(null); const [expiries, setExpiries] = useState<Expiry[] | null>(null);
  const [fromDate, setFromDate] = useState(''); const [toDate, setToDate] = useState(''); const [windowDays, setWindow] = useState(7);
  const [page, setPage] = useState(0); const [refresh, setRefresh] = useState(0); const [loading, setLoading] = useState(true); const [message, setMessage] = useState('');
  useEffect(() => {
    let active = true;
    const ticket = ++request.current;
    const timer = window.setTimeout(() => void (async () => {
      setLoading(true); setIncome(null); setExpiries(null); setMessage('');
      try {
        if (fromDate && toDate && fromDate > toDate) throw Error();
        const client = getSupabaseClient();
        const results = await Promise.allSettled([
          client.functions.invoke('owner-reporting', { body: { action: 'income', fromDate, toDate } }),
          client.functions.invoke('owner-reporting', { body: { action: 'expiry', windowDays, limit: 50, offset: page * 50 } }),
        ]);
        if (!active || ticket !== request.current) return;
        const [incomeResult, expiryResult] = results;
        let failed = false;
        if (incomeResult.status === 'fulfilled' && !incomeResult.value.error && incomeResult.value.data?.success === true && Array.isArray(incomeResult.value.data.income)) {
          const rows = incomeResult.value.data.income as Income[];
          for (const row of rows) { formatPhp(row.amountPhp); if (!['membership','walkin'].includes(row.source) || !Number.isSafeInteger(row.transactionCount)) throw Error(); }
          setIncome(rows);
        } else failed = true;
        if (expiryResult.status === 'fulfilled' && !expiryResult.value.error && expiryResult.value.data?.success === true && Array.isArray(expiryResult.value.data.expiries)) setExpiries(expiryResult.value.data.expiries);
        else failed = true;
        if (failed) setMessage('A report could not be loaded. Review the dates and retry.');
      } catch { if (active && ticket === request.current) setMessage('Reports could not be loaded. Select a valid period of at most 366 days.'); }
      finally { if (active && ticket === request.current) setLoading(false); }
    })(), 250);
    return () => { active = false; window.clearTimeout(timer); };
  }, [fromDate, toDate, windowDays, page, refresh]);
  function invalidate() { ++request.current; setLoading(true); setIncome(null); setExpiries(null); }
  return <section className="plans-module" aria-label="Income and membership reports">
    <div className="plans-toolbar"><div><strong>Income and expiry reports</strong><p>Confirmed income is separate from actual receipts and physical cash reconciliation.</p></div><button disabled={loading} className="secondary-button" onClick={() => { invalidate(); setRefresh((value) => value + 1); }}>Refresh reports</button></div>
    {message && <p className="members-error" role="alert">{message}</p>}
    <div className="purchase-history-filters"><label>Confirmation date from<input type="date" value={fromDate} max={toDate || undefined} onChange={(event) => { invalidate(); setFromDate(event.target.value); }} /></label><label>Through Manila date<input type="date" value={toDate} min={fromDate || undefined} onChange={(event) => { invalidate(); setToDate(event.target.value); }} /></label></div>
    <p className="members-footnote">Blank dates select the current Manila month through today. Dates refer to payment confirmation, not receipt entry. Voided, pending and unallocated receipts are excluded.</p>
    <div className="members-table-card"><div className="members-table-heading"><h2>Confirmed income by day and method</h2><button disabled={loading || !income?.length} className="secondary-button" onClick={() => downloadCsv('gymforce-confirmed-income.csv',['Manila confirmation date','Source','Method','Amount PHP','Transactions'],(income ?? []).map((row) => [row.gymLocalDate,row.source,row.paymentMethod,row.amountPhp,row.transactionCount]))}>Export loaded income (CSV)</button></div>
      <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Manila date</th><th>Source</th><th>Method</th><th>Confirmed PHP</th><th>Transactions</th></tr></thead><tbody>{loading ? <tr><td colSpan={5}>Loading…</td></tr> : income === null ? <tr><td colSpan={5}>Report unavailable.</td></tr> : income.length === 0 ? <tr><td colSpan={5}>No confirmed income in this period.</td></tr> : income.map((row) => <tr key={`${row.gymLocalDate}-${row.source}-${row.paymentMethod}`}><td>{row.gymLocalDate}</td><td>{row.source === 'membership' ? 'Membership' : 'Walk-in'}</td><td>{row.paymentMethod}</td><td>{formatPhp(row.amountPhp)}</td><td>{row.transactionCount}</td></tr>)}</tbody></table></div>
    </div>
    <div className="purchase-history-filters"><label>Upcoming expiry window (days, 0–31)<input type="number" min={0} max={31} step={1} value={windowDays} onChange={(event) => { invalidate(); setWindow(Number(event.target.value)); setPage(0); }} /></label></div>
    <div className="members-table-card"><div className="members-table-heading"><h2>Expiring paid entitlements</h2><button disabled={loading || !expiries?.length} className="secondary-button" onClick={() => downloadCsv('gymforce-expiry-page.csv',['Purchase','Member ID','Member name','Activation','Inclusive expiry','Days to expiry'],(expiries ?? []).map((row) => [row.purchaseId,row.memberCode,row.memberName,row.activationDate,row.expiryDate,row.daysToExpiry]))}>Export this page (CSV)</button></div>
      <div className="members-table-wrap"><table className="members-table"><thead><tr><th>Member</th><th>Purchase reference</th><th>Inclusive expiry</th><th>Reminder</th></tr></thead><tbody>{loading ? <tr><td colSpan={4}>Loading…</td></tr> : expiries === null ? <tr><td colSpan={4}>Reminders unavailable.</td></tr> : expiries.length === 0 ? <tr><td colSpan={4}>No unrenewed current entitlements expire in this window.</td></tr> : expiries.map((row) => <tr key={row.purchaseId}><td>{row.memberName}<small className="payment-subline">{row.memberCode}</small></td><td>{row.purchaseId}</td><td>{row.expiryDate}</td><td>{row.daysToExpiry === 0 ? 'Expires after today' : `Expires in ${row.daysToExpiry} days`}</td></tr>)}</tbody></table></div>
      <div className="purchase-history-pagination"><button disabled={loading || page === 0} onClick={() => { invalidate(); setPage((value) => value - 1); }}>Previous</button><span>Page {page + 1}</span><button disabled={loading || !expiries || expiries.length < 50 || (page + 1) * 50 > 100000} onClick={() => { invalidate(); setPage((value) => value + 1); }}>Next</button></div>
    </div><p className="members-footnote">Reminders are visible only to the Owner. A consecutive fully paid renewal suppresses the reminder. No message is sent to a member and no access date is changed.</p>
  </section>;
}
