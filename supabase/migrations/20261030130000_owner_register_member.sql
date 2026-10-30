BEGIN;

CREATE OR REPLACE FUNCTION api.owner_register_member(
    p_actor_user_id uuid,
    p_full_name text,
    p_mobile_lookup_hash bytea,
    p_mobile_encrypted bytea
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_member_id uuid;
    v_member_code text;
BEGIN
    -- The actor must still be an active owner.
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id
          AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;

    -- Validate all data again inside the database.
    IF p_full_name IS NULL
       OR pg_catalog.btrim(p_full_name) = ''
       OR pg_catalog.char_length(pg_catalog.btrim(p_full_name)) > 120
       OR p_mobile_lookup_hash IS NULL
       OR pg_catalog.octet_length(p_mobile_lookup_hash) <> 32
       OR p_mobile_encrypted IS NULL
       OR pg_catalog.octet_length(p_mobile_encrypted) < 29 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBER_REGISTRATION';
    END IF;

    -- Generate the member code on the server.
    LOOP
        v_member_code :=
            'MBR-' ||
            pg_catalog.upper(
                pg_catalog.substr(
                    pg_catalog.replace(
                        pg_catalog.gen_random_uuid()::text,
                        '-',
                        ''
                    ),
                    1,
                    12
                )
            );

        INSERT INTO private.members (
            member_code,
            full_name,
            mobile_lookup_hash,
            mobile_encrypted,
            status
        )
        VALUES (
            v_member_code,
            pg_catalog.btrim(p_full_name),
            p_mobile_lookup_hash,
            p_mobile_encrypted,
            'pending'
        )
        ON CONFLICT DO NOTHING
        RETURNING id INTO v_member_id;

        IF v_member_id IS NOT NULL THEN
            EXIT;
        END IF;

        -- A matching hash means this mobile number is already registered.
        IF EXISTS (
            SELECT 1
            FROM private.members m
            WHERE m.mobile_lookup_hash = p_mobile_lookup_hash
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE = 'P0001',
                MESSAGE = 'MEMBER_MOBILE_EXISTS';
        END IF;

        -- Otherwise retry the extremely unlikely member-code collision.
    END LOOP;

    -- This runs in the same transaction as the member insertion.
    PERFORM api.append_audit_event(
        'members',
        p_actor_user_id,
        'member.registered',
        'member',
        v_member_id::text,
        pg_catalog.jsonb_build_object(
            'member_code',
            v_member_code
        )
    );

    RETURN pg_catalog.jsonb_build_object(
        'id',
        v_member_id,
        'member_code',
        v_member_code,
        'status',
        'pending'
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_register_member(
    uuid, text, bytea, bytea
) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION api.owner_register_member(
    uuid, text, bytea, bytea
) TO service_role;

COMMIT;

