BEGIN;

CREATE OR REPLACE FUNCTION api.owner_create_membership_purchase(
    p_actor_user_id uuid,
    p_member_id uuid,
    p_plan_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_member private.members%ROWTYPE;
    v_plan private.membership_plans%ROWTYPE;
    v_purchase private.membership_purchases%ROWTYPE;
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

    IF p_member_id IS NULL OR p_plan_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE';
    END IF;

    SELECT *
    INTO v_member
    FROM private.members
    WHERE id = p_member_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'MEMBER_NOT_FOUND';
    END IF;

    IF v_member.status <> 'active' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'MEMBER_NOT_ACTIVE';
    END IF;

    SELECT *
    INTO v_plan
    FROM private.membership_plans
    WHERE id = p_plan_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'MEMBERSHIP_PLAN_NOT_FOUND';
    END IF;

    IF v_plan.is_active IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'MEMBERSHIP_PLAN_NOT_ACTIVE';
    END IF;

    INSERT INTO private.membership_purchases (
        member_id,
        plan_id,
        price_php,
        purchase_status
    )
    VALUES (
        v_member.id,
        v_plan.id,
        v_plan.price_php,
        'pending_payment'
    )
    RETURNING * INTO v_purchase;

    PERFORM api.append_audit_event(
        'membership_purchases',
        p_actor_user_id,
        'membership_purchase.created',
        'membership_purchase',
        v_purchase.id::text,
        pg_catalog.jsonb_build_object(
            'member_id', v_member.id,
            'member_code', v_member.member_code,
            'plan_id', v_plan.id,
            'plan_name', v_plan.name,
            'price_php', v_purchase.price_php,
            'purchase_status', v_purchase.purchase_status
        )
    );

    RETURN pg_catalog.jsonb_build_object(
        'id', v_purchase.id,
        'memberId', v_purchase.member_id,
        'planId', v_purchase.plan_id,
        'planName', v_plan.name,
        'pricePhp', v_purchase.price_php,
        'purchaseStatus', v_purchase.purchase_status,
        'activationDate', v_purchase.activation_date,
        'expiryDate', v_purchase.expiry_date,
        'createdAt', v_purchase.created_at
    );
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;

GRANT EXECUTE ON FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid)
TO service_role;

COMMIT;
