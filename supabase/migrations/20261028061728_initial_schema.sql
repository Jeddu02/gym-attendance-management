
-- Gym Attendance and Membership Management System
-- Initial foundation migration
-- Timezone: Asia/Manila | Currency: PHP
--
-- IMPORTANT:
-- This migration is a foundation, not a complete production schema.
-- Do not deploy until reviewed and tested against PostgreSQL/Supabase.

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

-- Prevent public/anonymous access to internal application tables.
revoke all on schema private from public;
revoke all on schema private from anon, authenticated;

-- ============================================================
-- 1. Gym configuration
-- ============================================================

create table public.gym_settings (
    setting_key text primary key,
    setting_value jsonb not null,
    updated_at timestamptz not null default now(),
    constraint gym_settings_key_not_blank
        check (length(trim(setting_key)) > 0)
);

insert into public.gym_settings (
    setting_key,
    setting_value
)
values
    ('timezone', '"Asia/Manila"'::jsonb),
    ('currency', '"PHP"'::jsonb)
on conflict (setting_key) do nothing;

-- ============================================================
-- 2. Owner access registry
-- ============================================================
-- Owner access is granted only to a verified Supabase Auth user.
-- This table does not create an Owner or enable public registration.
-- Owner bootstrap will be implemented separately.

create table private.owner_access (
    user_id uuid primary key references auth.users(id) on delete restrict,
    is_active boolean not null default false,
    created_at timestamptz not null default now(),
    deactivated_at timestamptz,
    constraint owner_access_deactivation_consistent
        check (
            (is_active and deactivated_at is null)
            or
            (not is_active)
        )
);

-- ============================================================
-- 3. Member records
-- ============================================================
-- Do not store member PINs or plaintext PIN credentials here.
-- PIN enrollment and secure identifier lookup are future migrations.


create table private.members (
    id uuid primary key default gen_random_uuid(),
    member_code text not null unique,
    full_name text not null,
    mobile_lookup_hash bytea not null unique,
    mobile_encrypted bytea not null,
    status text not null default 'pending',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    approved_at timestamptz,

    constraint members_code_not_blank
        check (length(trim(member_code)) > 0),

    constraint members_name_not_blank
        check (length(trim(full_name)) > 0),

    constraint members_mobile_lookup_hash_not_empty
        check (octet_length(mobile_lookup_hash) > 0),

    constraint members_mobile_encrypted_not_empty
        check (octet_length(mobile_encrypted) > 0),

    constraint members_status_valid
        check (status in ('pending', 'active', 'suspended'))
);


create index members_status_idx
    on private.members (status);

-- ============================================================
-- 4. Audit event foundation
-- ============================================================
-- Never place PINs, passwords, full payment credentials, or other
-- secrets in event details. Append-only enforcement and hash-chain
-- verification will be added before production use.

create table private.audit_events (
    id bigint generated always as identity primary key,
    actor_user_id uuid references auth.users(id) on delete restrict,
    event_type text not null,
    subject_type text not null,
    subject_id text,
    details jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint audit_event_type_not_blank
        check (length(trim(event_type)) > 0),
    constraint audit_subject_type_not_blank
        check (length(trim(subject_type)) > 0)
);

create index audit_events_created_at_idx
    on private.audit_events (created_at desc);

create index audit_events_actor_created_idx
    on private.audit_events (actor_user_id, created_at desc);

-- ============================================================
-- 5. Default access protections
-- ============================================================

alter table public.gym_settings enable row level security;
alter table private.owner_access enable row level security;
alter table private.members enable row level security;
alter table private.audit_events enable row level security;

-- No direct client table access. Later migrations will expose only
-- narrowly authorized functions and views after their policies
-- and execution permissions have been designed and tested.

revoke all on public.gym_settings from public, anon, authenticated;
revoke all on private.owner_access from public, anon, authenticated;
revoke all on private.members from public, anon, authenticated;
revoke all on private.audit_events from public, anon, authenticated;

commit;
