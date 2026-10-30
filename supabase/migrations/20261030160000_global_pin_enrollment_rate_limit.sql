BEGIN;

CREATE TABLE IF NOT EXISTS private.pin_enrollment_global_rate_limits (
    window_started_at timestamptz PRIMARY KEY,
    request_count integer NOT NULL DEFAULT 0
        CHECK (request_count >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.pin_enrollment_global_rate_limits
    ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.pin_enrollment_global_rate_limits
    FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION api.reserve_pin_enrollment_request()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_now timestamptz := clock_timestamp();
    v_window timestamptz;
    v_count integer;
    v_retry_after integer;
    v_limit constant integer := 30;
BEGIN
    v_window := date_trunc('minute', v_now);

    INSERT INTO private.pin_enrollment_global_rate_limits (
        window_started_at,
        request_count,
        updated_at
    )
    VALUES (
        v_window,
        1,
        v_now
    )
    ON CONFLICT (window_started_at)
    DO UPDATE SET
        request_count =
            private.pin_enrollment_global_rate_limits.request_count + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING request_count INTO v_count;

    DELETE FROM private.pin_enrollment_global_rate_limits
    WHERE window_started_at < v_window - interval '1 day';

    IF v_count > v_limit THEN
        v_retry_after := GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (
                v_window + interval '1 minute' - clock_timestamp()
            )))::integer
        );

        RETURN jsonb_build_object(
            'allowed', false,
            'retryAfterSeconds', v_retry_after
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'remaining', v_limit - v_count
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.reserve_pin_enrollment_request()
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION api.reserve_pin_enrollment_request()
    TO service_role;

COMMENT ON FUNCTION api.reserve_pin_enrollment_request() IS
    'Atomically reserves one of 30 global member PIN enrollment requests per minute.';

COMMIT;