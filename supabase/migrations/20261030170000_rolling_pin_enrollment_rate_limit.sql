BEGIN;

DROP FUNCTION IF EXISTS api.reserve_pin_enrollment_request();

DROP TABLE IF EXISTS private.pin_enrollment_global_rate_limits;

CREATE TABLE private.pin_enrollment_global_rate_limit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX pin_enrollment_global_rate_limit_events_requested_at_idx
    ON private.pin_enrollment_global_rate_limit_events (requested_at);

ALTER TABLE private.pin_enrollment_global_rate_limit_events
    ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.pin_enrollment_global_rate_limit_events
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION api.reserve_pin_enrollment_request()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_now timestamptz;
    v_cutoff timestamptz;
    v_count integer;
    v_oldest_request timestamptz;
    v_retry_after integer;
    v_limit constant integer := 30;
BEGIN
    -- Serialize all enrollment reservations across the gym.
    PERFORM pg_advisory_xact_lock(7142026, 301);

    v_now := clock_timestamp();
    v_cutoff := v_now - interval '60 seconds';

    -- Remove records outside the retained history.
    DELETE FROM private.pin_enrollment_global_rate_limit_events
    WHERE requested_at <= v_now - interval '24 hours';

    -- Count accepted requests in the rolling 60-second window.
    SELECT
        COUNT(*)::integer,
        MIN(requested_at)
    INTO
        v_count,
        v_oldest_request
    FROM private.pin_enrollment_global_rate_limit_events
    WHERE requested_at > v_cutoff;

    IF v_count >= v_limit THEN
        v_retry_after := GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (
                v_oldest_request + interval '60 seconds' - v_now
            )))::integer
        );

        RETURN jsonb_build_object(
            'allowed', false,
            'retryAfterSeconds', v_retry_after
        );
    END IF;

    INSERT INTO private.pin_enrollment_global_rate_limit_events (
        requested_at
    )
    VALUES (v_now);

    RETURN jsonb_build_object(
        'allowed', true,
        'remaining', v_limit - v_count - 1
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.reserve_pin_enrollment_request()
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION api.reserve_pin_enrollment_request()
    TO service_role;

COMMENT ON FUNCTION api.reserve_pin_enrollment_request() IS
    'Atomically limits accepted member PIN enrollment requests to 30 in any rolling 60-second window.';

COMMIT;