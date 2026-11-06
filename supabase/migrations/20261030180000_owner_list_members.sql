BEGIN;

CREATE OR REPLACE FUNCTION api.owner_list_members(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_search text := NULLIF(pg_catalog.btrim(p_search), '');
    v_status text := COALESCE(NULLIF(pg_catalog.btrim(p_status), ''), 'all');
    v_members jsonb;
BEGIN
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

    IF v_search IS NOT NULL AND pg_catalog.char_length(v_search) > 80 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBER_SEARCH';
    END IF;

    IF v_status NOT IN ('all', 'pending', 'active', 'suspended') THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBER_STATUS';
    END IF;

    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBER_PAGE';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.id,
                'memberCode', page.member_code,
                'fullName', page.full_name,
                'status', page.status,
                'createdAt', page.created_at
            )
            ORDER BY page.created_at DESC, page.id
        ),
        '[]'::jsonb
    )
    INTO v_members
    FROM (
        SELECT m.id, m.member_code, m.full_name, m.status, m.created_at
        FROM private.members m
        WHERE
            (v_status = 'all' OR m.status = v_status)
            AND (
                v_search IS NULL
                OR m.member_code ILIKE '%' || v_search || '%'
                OR m.full_name ILIKE '%' || v_search || '%'
            )
        ORDER BY m.created_at DESC, m.id
        LIMIT p_limit
        OFFSET p_offset
    ) AS page;

    RETURN v_members;
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_list_members(
    uuid, text, text, integer, integer
) FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_list_members(
    uuid, text, text, integer, integer
) TO service_role;

COMMIT;
