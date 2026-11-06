BEGIN;

DO $migration$
DECLARE
    v_duplicates text;
BEGIN
    SELECT pg_catalog.string_agg(d.normalized_name, ', ' ORDER BY d.normalized_name)
    INTO v_duplicates
    FROM (
        SELECT pg_catalog.lower(
pg_catalog.btrim(
    pg_catalog.regexp_replace(name, '\s+', ' ', 'g')
)
        ) AS normalized_name
        FROM private.membership_plans
        GROUP BY 1
        HAVING pg_catalog.count(*) > 1
    ) d;

    IF v_duplicates IS NOT NULL THEN
        RAISE EXCEPTION
            'DUPLICATE_MEMBERSHIP_PLAN_NAMES: resolve normalized duplicates before migration: %',
            v_duplicates;
    END IF;
END;
$migration$;


CREATE UNIQUE INDEX IF NOT EXISTS membership_plans_normalized_name_uidx
ON private.membership_plans (
    pg_catalog.lower(
        pg_catalog.btrim(
            pg_catalog.regexp_replace(name, '\s+', ' ', 'g')
        )
    )
);
CREATE OR REPLACE FUNCTION api.owner_list_membership_plans(
    p_actor_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_plans jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', p.id,
                'name', p.name,
                'pricePhp', p.price_php,
                'isActive', p.is_active,
                'createdAt', p.created_at
            )
            ORDER BY p.is_active DESC, pg_catalog.lower(p.name), p.created_at, p.id
        ),
        '[]'::jsonb
    )
    INTO v_plans
    FROM private.membership_plans p;

    RETURN v_plans;
END;
$function$;

CREATE OR REPLACE FUNCTION api.owner_save_membership_plan(
    p_actor_user_id uuid,
    p_plan_id uuid,
    p_name text,
    p_price_php numeric,
    p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_name text;
    v_plan private.membership_plans%ROWTYPE;
    v_old_plan private.membership_plans%ROWTYPE;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;

    v_name := pg_catalog.btrim(
        pg_catalog.regexp_replace(COALESCE(p_name, ''), '\s+', ' ', 'g')
    );

    IF v_name = ''
       OR pg_catalog.char_length(v_name) > 80
       OR p_price_php IS NULL
       OR p_price_php <= 0
       OR p_price_php > 9999999999.99
       OR p_price_php <> pg_catalog.round(p_price_php, 2)
       OR p_is_active IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBERSHIP_PLAN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM private.membership_plans p
        WHERE pg_catalog.lower(
            pg_catalog.btrim(
                pg_catalog.regexp_replace(p.name, '\s+', ' ', 'g')
            )
        ) = pg_catalog.lower(v_name)
          AND (p_plan_id IS NULL OR p.id <> p_plan_id)
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'MEMBERSHIP_PLAN_NAME_EXISTS';
    END IF;
    IF p_plan_id IS NULL THEN
        BEGIN
            INSERT INTO private.membership_plans(name, price_php, is_active)
            VALUES (v_name, p_price_php, p_is_active)
            RETURNING * INTO v_plan;
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'MEMBERSHIP_PLAN_NAME_EXISTS';
        END;

        PERFORM api.append_audit_event(
            'membership_plans', p_actor_user_id, 'membership_plan.created',
            'membership_plan', v_plan.id::text,
            pg_catalog.jsonb_build_object(
                'name', v_plan.name, 'price_php', v_plan.price_php,
                'is_active', v_plan.is_active
            )
        );
    ELSE
        SELECT * INTO v_old_plan
        FROM private.membership_plans
        WHERE id = p_plan_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'MEMBERSHIP_PLAN_NOT_FOUND';
        END IF;

        BEGIN
            UPDATE private.membership_plans
            SET name = v_name, price_php = p_price_php, is_active = p_is_active
            WHERE id = p_plan_id
            RETURNING * INTO v_plan;
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'MEMBERSHIP_PLAN_NAME_EXISTS';
        END;

        PERFORM api.append_audit_event(
            'membership_plans', p_actor_user_id, 'membership_plan.updated',
            'membership_plan', v_plan.id::text,
            pg_catalog.jsonb_build_object(
                'before', pg_catalog.jsonb_build_object(
                    'name', v_old_plan.name,
                    'price_php', v_old_plan.price_php,
                    'is_active', v_old_plan.is_active
                ),
                'after', pg_catalog.jsonb_build_object(
                    'name', v_plan.name,
                    'price_php', v_plan.price_php,
                    'is_active', v_plan.is_active
                )
            )
        );
    END IF;

    RETURN pg_catalog.jsonb_build_object(
        'id', v_plan.id, 'name', v_plan.name,
        'pricePhp', v_plan.price_php, 'isActive', v_plan.is_active,
        'createdAt', v_plan.created_at
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_list_membership_plans(uuid)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)
FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_plans(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)
TO service_role;

COMMIT;
