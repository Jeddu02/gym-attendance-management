
-- Member PIN security foundation.
-- Draft only. Do not enable public PIN operations until a trusted
-- server-side verifier and rate limits are implemented and tested.

begin;

create table private.member_pin_credentials (
    member_id uuid primary key
        references private.members(id) on delete restrict,

    -- Store only an encoded Argon2id verifier, never the PIN itself.
    -- The trusted backend must generate and validate this value.
    password_hash text not null,

    credential_version integer not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint member_pin_hash_not_blank
        check (length(trim(password_hash)) > 0),

    constraint member_pin_version_positive
        check (credential_version > 0)
);

-- Hashed, short-lived, single-use enrollment/reset capabilities.
-- Raw tokens must only be returned once to the intended recipient.
create table private.member_pin_setup_tokens (
    id uuid primary key default gen_random_uuid(),

    member_id uuid not null
        references private.members(id) on delete restrict,

    token_hash text not null unique,
    token_purpose text not null,
    expires_at timestamptz not null,

    consumed_at timestamptz,
    created_at timestamptz not null default now(),

    constraint pin_token_hash_not_blank
        check (length(trim(token_hash)) > 0),

    constraint pin_token_purpose_valid
        check (token_purpose in ('enrollment', 'reset')),

    constraint pin_token_expiry_after_creation
        check (expires_at > created_at)
);

create index member_pin_setup_tokens_member_idx
    on private.member_pin_setup_tokens (member_id, created_at desc);

create index member_pin_setup_tokens_expiry_idx
    on private.member_pin_setup_tokens (expires_at)
    where consumed_at is null;

-- Keyed identifiers only. The actual HMAC keys and rate-limit
-- policy must be handled by a trusted server-side component.
create table private.pin_attempt_buckets (
    id uuid primary key default gen_random_uuid(),

    bucket_type text not null,
    identifier_digest text not null,
    window_started_at timestamptz not null,
    failed_attempts integer not null default 0,
    blocked_until timestamptz,

    updated_at timestamptz not null default now(),

    constraint pin_bucket_type_valid
        check (
            bucket_type in ('member_identifier', 'trusted_network')
        ),

    constraint pin_identifier_digest_not_blank
        check (length(trim(identifier_digest)) > 0),

    constraint pin_failed_attempts_nonnegative
        check (failed_attempts >= 0),

    constraint pin_bucket_unique_window
        unique (bucket_type, identifier_digest, window_started_at)
);

create index pin_attempt_buckets_blocked_idx
    on private.pin_attempt_buckets (blocked_until)
    where blocked_until is not null;

-- No direct access from browser-facing roles.
alter table private.member_pin_credentials enable row level security;
alter table private.member_pin_setup_tokens enable row level security;
alter table private.pin_attempt_buckets enable row level security;

revoke all on private.member_pin_credentials
    from public, anon, authenticated;

revoke all on private.member_pin_setup_tokens
    from public, anon, authenticated;

revoke all on private.pin_attempt_buckets
    from public, anon, authenticated;

commit;
