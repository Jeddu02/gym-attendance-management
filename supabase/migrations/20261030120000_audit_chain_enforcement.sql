
-- Audit chain enforcement.
-- Adds atomic event hashing, append-only protection,
-- and server-side stream verification.

BEGIN;

-- ============================================================
-- 1. Canonical event hash
-- ============================================================

CREATE OR REPLACE FUNCTION private.compute_audit_event_hash(
    p_id bigint,
    p_stream_key text,
    p_previous_event_hash text,
    p_actor_user_id uuid,
    p_event_type text,
    p_subject_type text,
    p_subject_id text,
    p_details jsonb,
    p_created_at timestamptz
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $function$
    SELECT pg_catalog.encode(
        extensions.digest(
            pg_catalog.convert_to(
                pg_catalog.jsonb_build_object(
                    'version', 1,
                    'id', p_id,
                    'stream_key', p_stream_key,
                    'previous_event_hash', p_previous_event_hash,
                    'actor_user_id', p_actor_user_id,
                    'event_type', p_event_type,
                    'subject_type', p_subject_type,
                    'subject_id', p_subject_id,
                    'details', p_details,
                    'created_at', p_created_at
                )::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );
$function$;

-- ============================================================
-- 2. Backfill existing audit events
-- ============================================================

UPDATE private.audit_events
SET stream_key = 'legacy'
WHERE stream_key IS NULL
   OR pg_catalog.btrim(stream_key) = '';

DELETE FROM private.audit_chain_heads;

DO $block$
DECLARE
    v_stream record;
    v_event record;
    v_previous_hash text;
    v_event_hash text;
    v_last_event_id bigint;
BEGIN
    FOR v_stream IN
        SELECT DISTINCT stream_key
        FROM private.audit_events
        ORDER BY stream_key
    LOOP
        v_previous_hash := NULL;
        v_last_event_id := NULL;

        FOR v_event IN
            SELECT *
            FROM private.audit_events
            WHERE stream_key = v_stream.stream_key
            ORDER BY id
        LOOP
            v_event_hash :=
                private.compute_audit_event_hash(
                    v_event.id,
                    v_event.stream_key,
                    v_previous_hash,
                    v_event.actor_user_id,
                    v_event.event_type,
                    v_event.subject_type,
                    v_event.subject_id,
                    v_event.details,
                    v_event.created_at
                );

            UPDATE private.audit_events
            SET previous_event_hash = v_previous_hash,
                event_hash = v_event_hash
            WHERE id = v_event.id;

            v_previous_hash := v_event_hash;
            v_last_event_id := v_event.id;
        END LOOP;

        INSERT INTO private.audit_chain_heads (
            stream_key,
            last_event_id,
            last_event_hash,
            updated_at
        )
        VALUES (
            v_stream.stream_key,
            v_last_event_id,
            v_previous_hash,
            now()
        );
    END LOOP;
END;
$block$;

ALTER TABLE private.audit_events
    ALTER COLUMN stream_key SET NOT NULL,
    ALTER COLUMN event_hash SET NOT NULL;

-- ============================================================
-- 3. Automatically generate hashes and update chain heads
-- ============================================================

CREATE OR REPLACE FUNCTION private.audit_events_chain_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_previous_hash text;
BEGIN
    IF NEW.stream_key IS NULL
       OR pg_catalog.btrim(NEW.stream_key) = '' THEN
        RAISE EXCEPTION 'Audit stream key is required';
    END IF;

    INSERT INTO private.audit_chain_heads (
        stream_key,
        last_event_id,
        last_event_hash
    )
    VALUES (
        NEW.stream_key,
        NULL,
        NULL
    )
    ON CONFLICT (stream_key) DO NOTHING;

    SELECT last_event_hash
    INTO v_previous_hash
    FROM private.audit_chain_heads
    WHERE stream_key = NEW.stream_key
    FOR UPDATE;

    NEW.previous_event_hash := v_previous_hash;

    NEW.event_hash :=
        private.compute_audit_event_hash(
            NEW.id,
            NEW.stream_key,
            NEW.previous_event_hash,
            NEW.actor_user_id,
            NEW.event_type,
            NEW.subject_type,
            NEW.subject_id,
            NEW.details,
            NEW.created_at
        );

    UPDATE private.audit_chain_heads
    SET last_event_id = NEW.id,
        last_event_hash = NEW.event_hash,
        updated_at = now()
    WHERE stream_key = NEW.stream_key;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS audit_events_chain_insert_trigger
    ON private.audit_events;

CREATE TRIGGER audit_events_chain_insert_trigger
BEFORE INSERT ON private.audit_events
FOR EACH ROW
EXECUTE FUNCTION private.audit_events_chain_insert();

-- ============================================================
-- 4. Prevent event updates, deletions, and truncation
-- ============================================================

CREATE OR REPLACE FUNCTION private.prevent_audit_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'Audit events are append-only and cannot be modified or deleted';
END;
$function$;

DROP TRIGGER IF EXISTS audit_events_no_update_delete
    ON private.audit_events;

CREATE TRIGGER audit_events_no_update_delete
BEFORE UPDATE OR DELETE ON private.audit_events
FOR EACH ROW
EXECUTE FUNCTION private.prevent_audit_event_mutation();

DROP TRIGGER IF EXISTS audit_events_no_truncate
    ON private.audit_events;

CREATE TRIGGER audit_events_no_truncate
BEFORE TRUNCATE ON private.audit_events
FOR EACH STATEMENT
EXECUTE FUNCTION private.prevent_audit_event_mutation();

-- ============================================================
-- 5. Controlled append function
-- ============================================================

CREATE OR REPLACE FUNCTION api.append_audit_event(
    p_stream_key text,
    p_actor_user_id uuid,
    p_event_type text,
    p_subject_type text,
    p_subject_id text DEFAULT NULL,
    p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_id bigint;
BEGIN
    IF p_stream_key IS NULL
       OR pg_catalog.btrim(p_stream_key) = '' THEN
        RAISE EXCEPTION 'Audit stream key is required';
    END IF;

    IF p_event_type IS NULL
       OR pg_catalog.btrim(p_event_type) = '' THEN
        RAISE EXCEPTION 'Audit event type is required';
    END IF;

    IF p_subject_type IS NULL
       OR pg_catalog.btrim(p_subject_type) = '' THEN
        RAISE EXCEPTION 'Audit subject type is required';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_stream_key, 0)
    );

    INSERT INTO private.audit_events (
        stream_key,
        actor_user_id,
        event_type,
        subject_type,
        subject_id,
        details
    )
    VALUES (
        p_stream_key,
        p_actor_user_id,
        p_event_type,
        p_subject_type,
        p_subject_id,
        coalesce(p_details, '{}'::jsonb)
    )
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$function$;

-- ============================================================
-- 6. Audit stream verification
-- ============================================================

CREATE OR REPLACE FUNCTION api.verify_audit_stream(
    p_stream_key text
)
RETURNS TABLE (
    is_valid boolean,
    checked_events bigint,
    failure_event_id bigint,
    reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event record;
    v_previous_hash text;
    v_expected_hash text;
    v_last_event_id bigint;
    v_last_event_hash text;
    v_count bigint := 0;
BEGIN
    IF p_stream_key IS NULL
       OR pg_catalog.btrim(p_stream_key) = '' THEN
        RETURN QUERY
        SELECT false, 0::bigint, NULL::bigint, 'invalid_stream_key'::text;
        RETURN;
    END IF;

    FOR v_event IN
        SELECT *
        FROM private.audit_events
        WHERE stream_key = p_stream_key
        ORDER BY id
    LOOP
        IF v_event.previous_event_hash IS DISTINCT FROM v_previous_hash THEN
            RETURN QUERY
            SELECT false, v_count, v_event.id, 'previous_hash_mismatch'::text;
            RETURN;
        END IF;

        v_expected_hash :=
            private.compute_audit_event_hash(
                v_event.id,
                v_event.stream_key,
                v_event.previous_event_hash,
                v_event.actor_user_id,
                v_event.event_type,
                v_event.subject_type,
                v_event.subject_id,
                v_event.details,
                v_event.created_at
            );

        IF v_event.event_hash IS DISTINCT FROM v_expected_hash THEN
            RETURN QUERY
            SELECT false, v_count, v_event.id, 'event_hash_mismatch'::text;
            RETURN;
        END IF;

        v_previous_hash := v_event.event_hash;
        v_last_event_id := v_event.id;
        v_last_event_hash := v_event.event_hash;
        v_count := v_count + 1;
    END LOOP;

    IF v_count = 0 THEN
        IF EXISTS (
            SELECT 1
            FROM private.audit_chain_heads
            WHERE stream_key = p_stream_key
        ) THEN
            RETURN QUERY
            SELECT false, 0::bigint, NULL::bigint, 'unexpected_chain_head'::text;
            RETURN;
        END IF;
    ELSE
        IF NOT EXISTS (
            SELECT 1
            FROM private.audit_chain_heads h
            WHERE h.stream_key = p_stream_key
              AND h.last_event_id = v_last_event_id
              AND h.last_event_hash = v_last_event_hash
        ) THEN
            RETURN QUERY
            SELECT false, v_count, v_last_event_id, 'chain_head_mismatch'::text;
            RETURN;
        END IF;
    END IF;

    RETURN QUERY
    SELECT true, v_count, NULL::bigint, 'ok'::text;
END;
$function$;

-- ============================================================
-- 7. Restrict function execution
-- ============================================================

REVOKE ALL ON FUNCTION private.compute_audit_event_hash(
    bigint, text, text, uuid, text, text, text, jsonb, timestamptz
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.audit_events_chain_insert()
    FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.prevent_audit_event_mutation()
    FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION api.append_audit_event(
    text, uuid, text, text, text, jsonb
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION api.verify_audit_stream(text)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;

GRANT EXECUTE ON FUNCTION api.append_audit_event(
    text, uuid, text, text, text, jsonb
) TO service_role;

GRANT EXECUTE ON FUNCTION api.verify_audit_stream(text)
    TO service_role;

COMMIT;
