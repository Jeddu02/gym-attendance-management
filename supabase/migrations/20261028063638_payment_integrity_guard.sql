
-- Payment integrity safeguards.
-- Draft only: validate against PostgreSQL before deployment.

begin;

-- Direct browser access to payment records and event history
-- remains blocked. Authorized server-side operations are
-- still required before these tables can be used.
revoke all on private.payment_records
    from public, anon, authenticated;

revoke all on private.payment_allocations
    from public, anon, authenticated;

revoke all on private.payment_events
    from public, anon, authenticated;

revoke all on private.payment_corrections
    from public, anon, authenticated;

commit;
