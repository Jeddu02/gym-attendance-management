
-- Audit integrity foundation.
-- Draft only: validate hash-chain behavior and transaction handling
-- in a disposable PostgreSQL/Supabase environment before deployment.

begin;

-- Each stream has its own chain head so unrelated audit streams
-- can be serialized independently.
create table private.audit_chain_heads (
    stream_key text primary key,
    last_event_id bigint,
    last_event_hash text,
    updated_at timestamptz not null default now(),

    constraint audit_chain_stream_not_blank
        check (length(trim(stream_key)) > 0),

    constraint audit_chain_head_consistent
        check (
            (last_event_id is null and last_event_hash is null)
            or
            (last_event_id is not null and last_event_hash is not null)
        )
);

-- Add hash-chain fields to the foundation audit table.
alter table private.audit_events
    add column stream_key text,
    add column previous_event_hash text,
    add column event_hash text;

-- Existing rows, if any, must be backfilled through a controlled
-- migration before these fields can be made NOT NULL.
-- Fresh installations can require the fields immediately.
create index audit_events_stream_created_idx
    on private.audit_events (stream_key, created_at, id);

alter table private.audit_chain_heads enable row level security;
alter table private.audit_events enable row level security;

revoke all on private.audit_chain_heads
    from public, anon, authenticated;

revoke all on private.audit_events
    from public, anon, authenticated;

commit;
