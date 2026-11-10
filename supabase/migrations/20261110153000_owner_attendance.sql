-- Scoped read-only Owner attendance history; no check-in correction or restore.
BEGIN;
SET LOCAL search_path=pg_catalog;
GRANT SELECT(member_id,membership_purchase_id) ON private.attendance_checkins TO gym_owner_executor;
GRANT SELECT(id,attendance_id,reason,resolved_at) ON private.attendance_validity_resolutions TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.attendance_validity_resolutions FOR SELECT TO gym_owner_executor
USING(CURRENT_USER='gym_owner_executor'::name);

CREATE FUNCTION api.owner_list_attendance(p_actor_user_id uuid,p_search text DEFAULT NULL,
    p_from_date date DEFAULT NULL,p_to_date date DEFAULT NULL,p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_search text:=NULLIF(pg_catalog.btrim(COALESCE(p_search,'')),''); v_result jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF pg_catalog.char_length(COALESCE(p_search,''))>80 OR p_status IS NULL
       OR p_status NOT IN('all','valid','invalidated_payment','invalidated_correction','review')
       OR p_limit IS NULL OR p_limit<1 OR p_limit>100 OR p_offset IS NULL OR p_offset<0 OR p_offset>100000
       OR (p_from_date IS NOT NULL AND (NOT pg_catalog.isfinite(p_from_date) OR p_from_date<date '0001-01-01' OR p_from_date>date '9999-12-31'))
       OR (p_to_date IS NOT NULL AND (NOT pg_catalog.isfinite(p_to_date) OR p_to_date<date '0001-01-01' OR p_to_date>date '9999-12-31'))
       OR (p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date>p_to_date) THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_ATTENDANCE_FILTERS';
    END IF;
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',c.id,'memberId',c.member_id,'memberCode',c.member_code,'memberName',c.full_name,
        'walkinRequestId',c.walkin_request_id,'gymLocalDate',c.gym_local_date,'checkedInAt',c.checked_in_at,
        'attendanceStatus',c.attendance_status,'resolutionReason',c.resolution_reason)
        ORDER BY c.checked_in_at DESC,c.id DESC),'[]'::jsonb)
    INTO v_result FROM(
        SELECT a.id,a.member_id,m.member_code,m.full_name,a.walkin_request_id,a.gym_local_date,a.checked_in_at,a.attendance_status,
            (SELECT r.reason FROM private.attendance_validity_resolutions r WHERE r.attendance_id=a.id
             ORDER BY r.resolved_at DESC,r.id DESC LIMIT 1) AS resolution_reason
        FROM private.attendance_checkins a LEFT JOIN private.members m ON m.id=a.member_id
        WHERE (p_from_date IS NULL OR a.gym_local_date>=p_from_date)
          AND (p_to_date IS NULL OR a.gym_local_date<=p_to_date)
          AND (p_status='all' OR a.attendance_status=p_status)
          AND (v_search IS NULL OR pg_catalog.strpos(pg_catalog.lower(
              COALESCE(m.member_code,'')||' '||COALESCE(m.full_name,'')||' '||a.id::text||' '||COALESCE(a.walkin_request_id::text,'')),
              pg_catalog.lower(v_search))>0)
        ORDER BY a.checked_in_at DESC,a.id DESC LIMIT p_limit OFFSET p_offset
    ) c;
    RETURN v_result;
END;
$function$;
ALTER FUNCTION api.owner_list_attendance(uuid,text,date,date,text,integer,integer) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_list_attendance(uuid,text,date,date,text,integer,integer)
    FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_attendance(uuid,text,date,date,text,integer,integer) TO service_role;
COMMIT;
