
-- Owner security foundation.
-- Draft only: must be tested against a real disposable Supabase database
-- before deployment.

begin;

-- Confirm that the caller is authenticated and is an active Owner.
-- This helper returns false for anonymous or unauthorized callers.
create or replace function private.is_active_owner()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
    select exists (
        select 1
        from private.owner_access oa
        where oa.user_id = (select auth.uid())
          and oa.is_active = true
    );
$$;

-- Do not expose the private schema to client roles.
revoke all on schema private from public, anon, authenticated;

-- No client role may call this helper directly.
revoke all on function private.is_active_owner()
    from public, anon, authenticated;

-- Keep direct table access blocked.
revoke all on private.owner_access
    from public, anon, authenticated;

revoke all on private.members
    from public, anon, authenticated;

revoke all on private.audit_events
    from public, anon, authenticated;

revoke all on private.membership_plans
    from public, anon, authenticated;

revoke all on private.membership_purchases
    from public, anon, authenticated;

revoke all on private.payment_records
    from public, anon, authenticated;

revoke all on private.payment_allocations
    from public, anon, authenticated;

revoke all on private.payment_events
    from public, anon, authenticated;

revoke all on private.payment_corrections
    from public, anon, authenticated;

revoke all on private.walkin_fee_versions
    from public, anon, authenticated;

revoke all on private.walkin_requests
    from public, anon, authenticated;

revoke all on private.attendance_checkins
    from public, anon, authenticated;

revoke all on private.attendance_validity_resolutions
    from public, anon, authenticated;

commit;
