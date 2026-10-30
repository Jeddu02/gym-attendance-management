
-- Membership core: plans and one-month purchases.
-- Draft only: do not deploy before PostgreSQL testing.

begin;

create table private.membership_plans (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    price_php numeric(12,2) not null,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),

    constraint membership_plan_name_not_blank
        check (length(trim(name)) > 0),

    constraint membership_plan_price_positive
        check (price_php > 0)
);

create table private.membership_purchases (
    id uuid primary key default gen_random_uuid(),
    member_id uuid not null
        references private.members(id) on delete restrict,
    plan_id uuid not null
        references private.membership_plans(id) on delete restrict,

    -- Snapshot the agreed price so future plan edits do not
    -- change the historical purchase price.
    price_php numeric(12,2) not null,

    purchase_status text not null default 'pending_payment',

    -- Dates use the gym's local calendar, not the server's timezone.
    activation_date date,
    expiry_date date,

    created_at timestamptz not null default now(),

    constraint membership_purchase_price_positive
        check (price_php > 0),

    constraint membership_purchase_status_valid
        check (
            purchase_status in (
                'pending_payment',
                'pending_activation',
                'active',
                'expired',
                'payment_review'
            )
        ),

    constraint membership_purchase_dates_consistent
        check (
            (activation_date is null and expiry_date is null)
            or
            (
                activation_date is not null
                and expiry_date is not null
                and expiry_date >= activation_date
            )
        )
);

create index membership_purchases_member_idx
    on private.membership_purchases (member_id, created_at desc);

create index membership_purchases_plan_idx
    on private.membership_purchases (plan_id);

alter table private.membership_plans enable row level security;
alter table private.membership_purchases enable row level security;

revoke all on private.membership_plans
    from public, anon, authenticated;

revoke all on private.membership_purchases
    from public, anon, authenticated;

commit;
