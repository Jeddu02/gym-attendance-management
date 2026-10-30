
-- Walk-in and attendance foundation.
-- Draft only: do not deploy before database validation.

begin;

-- Versioned walk-in fees preserve the amount applicable when
-- a request is created. Configure actual fees before accepting visits.
create table private.walkin_fee_versions (
    id uuid primary key default gen_random_uuid(),
    fee_php numeric(12,2) not null,
    currency text not null default 'PHP',
    effective_from timestamptz not null default now(),
    created_by uuid references auth.users(id) on delete restrict,
    created_at timestamptz not null default now(),

    constraint walkin_fee_positive check (fee_php > 0),
    constraint walkin_fee_currency_php check (currency = 'PHP')
);

-- A public request is provisional; it is not proof of payment
-- or a valid visit. Only trusted server-side operations should
-- confirm payment and finalize attendance.
create table private.walkin_requests (
    id uuid primary key default gen_random_uuid(),
    fee_version_id uuid not null
        references private.walkin_fee_versions(id) on delete restrict,

    fee_php numeric(12,2) not null,
    currency text not null default 'PHP',

    request_status text not null default 'pending',
    created_at timestamptz not null default now(),
    expires_at timestamptz not null,

    confirmed_by uuid references auth.users(id) on delete restrict,
    confirmed_at timestamptz,

    constraint walkin_request_fee_positive check (fee_php > 0),
    constraint walkin_request_currency_php check (currency = 'PHP'),
    constraint walkin_request_expiry_after_creation
        check (expires_at > created_at),
    constraint walkin_request_status_valid
        check (
            request_status in (
                'pending',
                'confirmed',
                'expired',
                'payment_review',
                'rejected'
            )
        ),
    constraint walkin_confirmation_consistent
        check (
            (request_status = 'confirmed'
                and confirmed_by is not null
                and confirmed_at is not null)
            or
            (request_status <> 'confirmed')
        )
);

-- Attendance is check-in only. There is no checkout or duration field.
create table private.attendance_checkins (
    id uuid primary key default gen_random_uuid(),

    member_id uuid
        references private.members(id) on delete restrict,

    walkin_request_id uuid
        references private.walkin_requests(id) on delete restrict,

    gym_local_date date not null,
    checked_in_at timestamptz not null default now(),

    attendance_status text not null default 'valid',

    constraint attendance_exactly_one_subject
        check (
            (member_id is not null)
            <>
            (walkin_request_id is not null)
        ),

    constraint attendance_status_valid
        check (
            attendance_status in (
                'valid',
                'invalidated_payment',
                'invalidated_correction',
                'review'
            )
        )
);

-- Only one member check-in per gym-local calendar day.
create unique index attendance_one_member_valid_checkin_per_day
    on private.attendance_checkins (member_id, gym_local_date)
    where member_id is not null and attendance_status = 'valid';

-- Each walk-in request may have at most one attendance record.
create unique index attendance_one_checkin_per_walkin
    on private.attendance_checkins (walkin_request_id)
    where walkin_request_id is not null;

create index attendance_date_idx
    on private.attendance_checkins (gym_local_date desc);

create index attendance_member_date_idx
    on private.attendance_checkins (member_id, gym_local_date desc)
    where member_id is not null;

-- Record why a previous attendance record became invalid.
-- Original attendance history remains available for review.
create table private.attendance_validity_resolutions (
    id uuid primary key default gen_random_uuid(),

    attendance_id uuid not null
        references private.attendance_checkins(id) on delete restrict,

    prior_status text not null,
    new_status text not null,
    reason text not null,

    resolved_by uuid references auth.users(id) on delete restrict,
    resolved_at timestamptz not null default now(),

    constraint attendance_resolution_reason_not_blank
        check (length(trim(reason)) > 0),

    constraint attendance_resolution_status_valid
        check (
            prior_status in (
                'valid',
                'invalidated_payment',
                'invalidated_correction',
                'review'
            )
            and new_status in (
                'valid',
                'invalidated_payment',
                'invalidated_correction',
                'review'
            )
        )
);

-- Protect all new tables from direct browser access.
alter table private.walkin_fee_versions enable row level security;
alter table private.walkin_requests enable row level security;
alter table private.attendance_checkins enable row level security;
alter table private.attendance_validity_resolutions enable row level security;

revoke all on private.walkin_fee_versions
    from public, anon, authenticated;

revoke all on private.walkin_requests
    from public, anon, authenticated;

revoke all on private.attendance_checkins
    from public, anon, authenticated;

revoke all on private.attendance_validity_resolutions
    from public, anon, authenticated;

commit;
