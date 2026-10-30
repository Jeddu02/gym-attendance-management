
-- Payment ledger foundation.
-- Draft only: not production-ready until constraints,
-- permissions, and transactional operations are tested.

begin;

-- Actual money received. This record is separate from what
-- purchase or walk-in request the receipt is allocated to.
create table private.payment_records (
    id uuid primary key default gen_random_uuid(),

    amount_php numeric(12,2) not null,
    payment_method text not null,
    received_at timestamptz not null default now(),

    verification_status text not null default 'recorded',

    external_reference text,
    evidence_reference text,

    recorded_by uuid references auth.users(id) on delete restrict,
    created_at timestamptz not null default now(),

    constraint payment_amount_positive
        check (amount_php > 0),

    constraint payment_method_valid
        check (
            payment_method in (
                'cash',
                'gcash',
                'bank_transfer'
            )
        ),

    constraint payment_verification_status_valid
        check (
            verification_status in (
                'recorded',
                'confirmed',
                'rejected',
                'confirmation_voided_in_error'
            )
        )
);

-- Whole-receipt allocation. A receipt may target one membership
-- purchase or one walk-in request, never both.
create table private.payment_allocations (
    id uuid primary key default gen_random_uuid(),

    payment_id uuid not null unique
        references private.payment_records(id) on delete restrict,

    membership_purchase_id uuid
        references private.membership_purchases(id) on delete restrict,

    walkin_request_id uuid,

    allocated_by uuid references auth.users(id) on delete restrict,
    allocated_at timestamptz not null default now(),

    constraint payment_allocation_exactly_one_target
        check (
            (membership_purchase_id is not null)
            <>
            (walkin_request_id is not null)
        )
);

create index payment_allocations_membership_idx
    on private.payment_allocations (membership_purchase_id)
    where membership_purchase_id is not null;

create index payment_allocations_walkin_idx
    on private.payment_allocations (walkin_request_id)
    where walkin_request_id is not null;

-- Append-only event history. Enforcement of append-only behavior
-- and authorization will be added in the security/operations phase.
create table private.payment_events (
    id bigint generated always as identity primary key,

    payment_id uuid not null
        references private.payment_records(id) on delete restrict,

    event_type text not null,
    reason text,
    actor_user_id uuid references auth.users(id) on delete restrict,
    created_at timestamptz not null default now(),

    constraint payment_event_type_not_blank
        check (length(trim(event_type)) > 0)
);

create index payment_events_payment_created_idx
    on private.payment_events (payment_id, created_at);

-- Correction proposals preserve the original receipt. They do not
-- themselves modify the payment or authorize access.
create table private.payment_corrections (
    id uuid primary key default gen_random_uuid(),

    payment_id uuid not null
        references private.payment_records(id) on delete restrict,

    proposed_amount_php numeric(12,2),
    proposed_payment_method text,
    reason text not null,
    evidence_reference text,

    correction_status text not null default 'proposed',

    proposed_by uuid references auth.users(id) on delete restrict,
    proposed_at timestamptz not null default now(),

    decided_by uuid references auth.users(id) on delete restrict,
    decided_at timestamptz,
    decision_reason text,

    constraint payment_correction_reason_not_blank
        check (length(trim(reason)) > 0),

    constraint payment_correction_amount_valid
        check (
            proposed_amount_php is null
            or proposed_amount_php > 0
        ),

    constraint payment_correction_method_valid
        check (
            proposed_payment_method is null
            or proposed_payment_method in (
                'cash',
                'gcash',
                'bank_transfer'
            )
        ),

    constraint payment_correction_status_valid
        check (
            correction_status in (
                'proposed',
                'approved',
                'rejected',
                'withdrawn'
            )
        )
);

create index payment_corrections_payment_idx
    on private.payment_corrections (payment_id, proposed_at desc);

-- Protect the tables from direct browser access.
alter table private.payment_records enable row level security;
alter table private.payment_allocations enable row level security;
alter table private.payment_events enable row level security;
alter table private.payment_corrections enable row level security;

revoke all on private.payment_records
    from public, anon, authenticated;

revoke all on private.payment_allocations
    from public, anon, authenticated;

revoke all on private.payment_events
    from public, anon, authenticated;

revoke all on private.payment_corrections
    from public, anon, authenticated;

commit;
