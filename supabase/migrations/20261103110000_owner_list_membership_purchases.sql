BEGIN;

CREATE OR REPLACE FUNCTION api.owner_list_membership_purchases(
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
    v_purchases jsonb;
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
            MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE_SEARCH';
    END IF;

    IF v_status NOT IN (
        'all', 'pending_payment', 'pending_activation', 'active', 'expired', 'payment_review'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE_STATUS';
    END IF;

    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE_PAGE';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'pricePhp', page.price_php,
                'purchaseStatus', page.purchase_status,
                'activationDate', page.activation_date,
                'expiryDate', page.expiry_date,
                'createdAt', page.created_at
            ) ORDER BY page.created_at DESC, page.id
        ),
        '[]'::jsonb
    )
    INTO v_purchases
    FROM (
        SELECT
            mp.id,
            m.full_name AS member_name,
            m.member_code,
            plan.name AS plan_name,
            mp.price_php,
            mp.purchase_status,
            mp.activation_date,
            mp.expiry_date,
            mp.created_at
        FROM private.membership_purchases mp
        JOIN private.members m ON m.id = mp.member_id
        JOIN private.membership_plans plan ON plan.id = mp.plan_id
        WHERE (v_status = 'all' OR mp.purchase_status = v_status)
          AND (
              v_search IS NULL
              OR pg_catalog.strpos(pg_catalog.lower(mp.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(m.full_name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(m.member_code), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(plan.name), pg_catalog.lower(v_search)) > 0
          )
        ORDER BY mp.created_at DESC, mp.id
        LIMIT p_limit
        OFFSET p_offset
    ) AS page;

    RETURN v_purchases;
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_list_membership_purchases(
    uuid, text, text, integer, integer
) FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_purchases(
    uuid, text, text, integer, integer
) TO service_role;

COMMIT;
