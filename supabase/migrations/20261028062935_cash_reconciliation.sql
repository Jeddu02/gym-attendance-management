
-- Cash reconciliation foundation.
-- Draft only: validate transactions and permissions before deployment.

begin;

-- One drawer session represents one physical cash drawer.
create table private.cash_drawer_sessions (
    id uuid primary key default gen_random_uuid(),

    opened_at timestamptz not null default now(),
    opened_by uuid not null
        references auth.users(id) on delete restrict,

    opening_float_php numeric(12,2) not null default 0,

    session_status text not null default 'open',

    closed_at timestamptz,
    closed_by uuid references auth.users(id) on delete restrict,

    constraint cash_opening_float_nonnegative
        check (opening_float_php >= 0),

    constraint cash_drawer_status_valid
        check (session_status in ('open', 'closed')),

    constraint cash_drawer_close_consistent
        check (
            (session_status = 'open'
                and closed_at is null
                and closed_by is null)
            or
            (session_status = 'closed'
                and closed_at is not null
                and closed_by is not null)
        )
);

-- At most one open drawer session.
create unique index cash_drawer_only_one_open_session
    on private.cash_drawer_sessions ((session_status))
    where session_status = 'open';

-- A reconciliation is a snapshot, not a mutable running total.
create table private.cash_reconciliations (
    id uuid primary key default gen_random_uuid(),

    drawer_session_id uuid not null unique
        references private.cash_drawer_sessions(id) on delete restrict,

    expected_cash_php numeric(12,2) not null,
    counted_cash_php numeric(12,2) not null,
    variance_php numeric(12,2)
        generated always as (counted_cash_php - expected_cash_php) stored,

    reconciled_by uuid not null
        references auth.users(id) on delete restrict,

    reconciled_at timestamptz not null default now(),
    notes text,

    constraint reconciliation_expected_cash_nonnegative
        check (expected_cash_php >= 0),

    constraint reconciliation_counted_cash_nonnegative
        check (counted_cash_php >= 0)
);

-- Adjustments must be explained and separately recorded.
-- This table does not itself change a historical snapshot.
create table private.cash_reconciliation_adjustments (
    id uuid primary key default gen_random_uuid(),

    reconciliation_id uuid not null
        references private.cash_reconciliations(id) on delete restrict,

    amount_delta_php numeric(12,2) not null,
    reason text not null,
    evidence_reference text,

    recorded_by uuid not null
        references auth.users(id) on delete restrict,

    created_at timestamptz not null default now(),

    constraint cash_adjustment_nonzero
        check (amount_delta_php <> 0),

    constraint cash_adjustment_reason_not_blank
        check (length(trim(reason)) > 0)
);

create index cash_reconciliations_date_idx
    on private.cash_reconciliations (reconciled_at desc);

create index cash_adjustments_reconciliation_idx
    on private.cash_reconciliation_adjustments
       (reconciliation_id, created_at);

alter table private.cash_drawer_sessions enable row level security;
alter table private.cash_reconciliations enable row level security;
alter table private.cash_reconciliation_adjustments enable row level security;

revoke all on private.cash_drawer_sessions
    from public, anon, authenticated;

revoke all on private.cash_reconciliations
    from public, anon, authenticated;

revoke all on private.cash_reconciliation_adjustments
    from public, anon, authenticated;

commit;
