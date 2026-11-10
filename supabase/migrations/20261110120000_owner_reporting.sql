-- Read-only Owner reporting. This does not implement attendance, walk-in
-- confirmation, receipt review, payment corrections or cash reconciliation.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;

DO $reporting_preconditions$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='gym_owner_executor'
        AND NOT rolcanlogin AND NOT rolsuper AND NOT rolinherit AND NOT rolbypassrls
        AND NOT rolcreaterole AND NOT rolcreatedb AND NOT rolreplication)
       OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members a JOIN pg_catalog.pg_roles r
           ON r.oid=a.member OR r.oid=a.roleid WHERE r.rolname='gym_owner_executor') THEN
        RAISE EXCEPTION 'Restricted Owner executor foundation required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid='private.attendance_checkins'::regclass
        AND c.relrowsecurity AND c.relforcerowsecurity AND c.relowner=
        (SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_data_owner')) THEN
        RAISE EXCEPTION 'Protected attendance foundation required';
    END IF;
    IF pg_catalog.to_regprocedure('api.owner_activate_membership_purchase(uuid,uuid)') IS NULL THEN
        RAISE EXCEPTION 'Membership lifecycle foundation required';
    END IF;
END;
$reporting_preconditions$;

-- Count only the authoritative valid status and gym date; this grants no
-- attendance identity, history export, INSERT, UPDATE or DELETE capability.
GRANT SELECT(gym_local_date,attendance_status) ON private.attendance_checkins TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.attendance_checkins FOR SELECT TO gym_owner_executor
USING (CURRENT_USER='gym_owner_executor'::name);

CREATE FUNCTION api.owner_dashboard_summary(p_actor_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_today date:=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM private.owner_access
        WHERE user_id=p_actor_user_id AND is_active=true) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
        'totalMembers',(SELECT count(*) FROM private.members),
        'approvedMembers',(SELECT count(*) FROM private.members WHERE status='active' AND approved_at IS NOT NULL),
        'currentEntitlements',(
            SELECT count(DISTINCT m.id) FROM private.members m
            JOIN private.membership_purchases p ON p.member_id=m.id
            WHERE m.status='active' AND m.approved_at IS NOT NULL
              AND (m.approved_at AT TIME ZONE 'Asia/Manila')::date<=v_today
              AND p.purchase_status='active' AND p.activation_date<=v_today AND p.expiry_date>=v_today
              AND EXISTS (SELECT 1 FROM private.payment_allocations a
                JOIN private.payment_records r ON r.id=a.payment_id
                WHERE a.membership_purchase_id=p.id AND r.target_membership_purchase_id=p.id
                  AND r.verification_status='confirmed' AND r.amount_php=p.price_php
                  AND EXISTS (SELECT 1 FROM private.payment_events e WHERE e.payment_id=r.id
                    AND e.event_type='payment.confirmed' AND e.created_at<=pg_catalog.clock_timestamp()))),
        'todayValidCheckins',(SELECT count(*) FROM private.attendance_checkins
            WHERE gym_local_date=v_today AND attendance_status='valid'),
        'confirmedMembershipIncomePhp',(
            SELECT COALESCE(sum(r.amount_php),0)::text FROM private.payment_records r
            JOIN private.payment_allocations a ON a.payment_id=r.id
            JOIN private.membership_purchases p ON p.id=a.membership_purchase_id
            WHERE r.verification_status='confirmed' AND r.target_membership_purchase_id=p.id
              AND r.amount_php=p.price_php AND a.walkin_request_id IS NULL),
        'confirmedWalkinIncomePhp',(
            SELECT COALESCE(sum(r.amount_php),0)::text FROM private.payment_records r
            JOIN private.payment_allocations a ON a.payment_id=r.id
            WHERE r.verification_status='confirmed' AND a.walkin_request_id IS NOT NULL
              AND a.membership_purchase_id IS NULL AND r.target_membership_purchase_id IS NULL)
    );
END;
$function$;
ALTER FUNCTION api.owner_dashboard_summary(uuid) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_dashboard_summary(uuid) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_dashboard_summary(uuid) TO service_role;

CREATE FUNCTION api.owner_list_audit_events(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_from_date date DEFAULT NULL,
    p_to_date date DEFAULT NULL,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_search text:=NULLIF(pg_catalog.btrim(COALESCE(p_search,'')),''); v_result jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM private.owner_access
        WHERE user_id=p_actor_user_id AND is_active=true) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF pg_catalog.char_length(COALESCE(p_search,''))>80
       OR p_limit IS NULL OR p_limit<1 OR p_limit>100
       OR p_offset IS NULL OR p_offset<0 OR p_offset>100000
       OR (p_from_date IS NOT NULL AND (NOT pg_catalog.isfinite(p_from_date)
           OR p_from_date<date '0001-01-01' OR p_from_date>date '9999-12-31'))
       OR (p_to_date IS NOT NULL AND (NOT pg_catalog.isfinite(p_to_date)
           OR p_to_date<date '0001-01-01' OR p_to_date>date '9999-12-31'))
       OR (p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date>p_to_date) THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AUDIT_FILTERS';
    END IF;
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',e.id::text,'actorUserId',e.actor_user_id,'eventType',e.event_type,
        'subjectType',e.subject_type,'subjectId',e.subject_id,'createdAt',e.created_at,
        'reason',e.details->>'reason') ORDER BY e.created_at DESC,e.id DESC),'[]'::jsonb)
    INTO v_result FROM (
        SELECT a.id,a.actor_user_id,a.event_type,a.subject_type,a.subject_id,a.created_at,a.details
        FROM private.audit_events a
        WHERE (p_from_date IS NULL OR a.created_at>=p_from_date::timestamp AT TIME ZONE 'Asia/Manila')
          AND (p_to_date IS NULL OR a.created_at<(p_to_date+1)::timestamp AT TIME ZONE 'Asia/Manila')
          AND (v_search IS NULL OR pg_catalog.strpos(pg_catalog.lower(
            a.event_type||' '||a.subject_type||' '||COALESCE(a.subject_id,'')),pg_catalog.lower(v_search))>0)
        ORDER BY a.created_at DESC,a.id DESC LIMIT p_limit OFFSET p_offset
    ) e;
    RETURN v_result;
END;
$function$;
ALTER FUNCTION api.owner_list_audit_events(uuid,text,date,date,integer,integer) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_list_audit_events(uuid,text,date,date,integer,integer)
    FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_audit_events(uuid,text,date,date,integer,integer) TO service_role;

COMMIT;
