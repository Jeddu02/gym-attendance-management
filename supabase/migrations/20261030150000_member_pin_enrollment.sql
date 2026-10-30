BEGIN;

CREATE OR REPLACE FUNCTION api.member_enroll_pin(
    p_token_hash text,
    p_password_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_token_id uuid;
    v_member_id uuid;
    v_member_status text;
BEGIN
    -- Validate the SHA-256 token digest.
    IF p_token_hash IS NULL
       OR p_token_hash !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_ENROLLMENT_REQUEST';
    END IF;

    -- Accept only the configured Argon2id PHC format.
    IF p_password_hash IS NULL
       OR p_password_hash !~ '^\$argon2id\$v=19\$m=65536,t=3,p=1\$[A-Za-z0-9+/]+=*\$[A-Za-z0-9+/]+=*$' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_PIN_HASH';
    END IF;

    -- Lock the token so concurrent redemption cannot succeed twice.
    SELECT
        t.id,
        t.member_id
    INTO
        v_token_id,
        v_member_id
    FROM private.member_pin_setup_tokens AS t
    WHERE t.token_hash = p_token_hash
      AND t.token_purpose = 'enrollment'
      AND t.consumed_at IS NULL
      AND t.expires_at > pg_catalog.clock_timestamp()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'INVALID_OR_EXPIRED_TOKEN';
    END IF;

    -- Lock and validate the member.
    SELECT m.status
    INTO v_member_status
    FROM private.members AS m
    WHERE m.id = v_member_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_member_status NOT IN ('pending', 'active') THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'INVALID_OR_EXPIRED_TOKEN';
    END IF;

    -- Enrollment cannot replace an existing PIN.
    IF EXISTS (
        SELECT 1
        FROM private.member_pin_credentials AS c
        WHERE c.member_id = v_member_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'PIN_ALREADY_ENROLLED';
    END IF;

    -- Save the server-generated Argon2id verifier.
    INSERT INTO private.member_pin_credentials (
        member_id,
        password_hash,
        credential_version,
        created_at,
        updated_at
    )
    VALUES (
        v_member_id,
        p_password_hash,
        1,
        pg_catalog.clock_timestamp(),
        pg_catalog.clock_timestamp()
    );

    -- Consume the enrollment token in the same transaction.
    UPDATE private.member_pin_setup_tokens
    SET consumed_at = pg_catalog.clock_timestamp()
    WHERE id = v_token_id
      AND consumed_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'INVALID_OR_EXPIRED_TOKEN';
    END IF;

    -- Record enrollment without exposing the PIN or token.
    PERFORM api.append_audit_event(
        'member-pin:' || v_member_id::text,
        NULL,
        'member.pin_enrolled',
        'member',
        v_member_id::text,
        pg_catalog.jsonb_build_object(
            'credential_version', 1,
            'method', 'one_time_enrollment_token'
        )
    );

    RETURN pg_catalog.jsonb_build_object(
        'success', true,
        'credentialVersion', 1
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.member_enroll_pin(text, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION api.member_enroll_pin(text, text)
TO service_role;

COMMIT;
