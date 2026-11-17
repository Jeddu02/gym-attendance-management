-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=supabase_admin; source SHA-256=7e6af68a594c5cb26ab77eac4620849a3ecf5b8888aede71808eda5f569a5f46
-- Scoped read-only Owner attendance history; no check-in correction or restore.
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $compatibility_graph$
 BEGIN
 IF current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper )
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
 THEN RAISE EXCEPTION 'Required provider ADMIN edge absent or changed'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND n.nspname IN ('private','api','public','extensions') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE'))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected at-rest migration capability'; END IF;
 END $compatibility_graph$;
DO $compatibility_graph$
 BEGIN
 IF current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper )
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option)
 OR (m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND NOT m.admin_option AND m.inherit_option AND m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
 THEN RAISE EXCEPTION 'Required provider ADMIN edge absent or changed'; END IF;

 END $compatibility_graph$;
 DO $compatibility_prepare$ DECLARE r record; BEGIN
 FOR r IN SELECT rolname FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') ORDER BY rolname LOOP
 EXECUTE pg_catalog.format('GRANT %I TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres',r.rolname);
 IF r.rolname='gym_data_owner' THEN
 EXECUTE 'GRANT CREATE ON SCHEMA private TO gym_data_owner';

 ELSE EXECUTE pg_catalog.format('GRANT CREATE ON SCHEMA api TO %I',r.rolname); END IF;
 END LOOP;

 END $compatibility_prepare$;
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
DO $compatibility_cleanup$ DECLARE r record; BEGIN
 FOR r IN SELECT n.nspname,c.relname FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE p.polname='gf_compatibility_read' AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')) LOOP
 EXECUTE pg_catalog.format('DROP POLICY gf_compatibility_read ON %I.%I',r.nspname,r.relname);
 END LOOP;
 FOR r IN SELECT rolname FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') ORDER BY rolname LOOP
 EXECUTE pg_catalog.format('REVOKE CREATE ON SCHEMA private,api,public FROM %I',r.rolname);
 EXECUTE pg_catalog.format('REVOKE %I FROM postgres GRANTED BY postgres',r.rolname);
 END LOOP;
 END $compatibility_cleanup$;
 DO $compatibility_graph$
 BEGIN
 IF current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper )
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
 THEN RAISE EXCEPTION 'Required provider ADMIN edge absent or changed'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND n.nspname IN ('private','api','public','extensions') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE'))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected at-rest migration capability'; END IF;
 END $compatibility_graph$;
 DO $compatibility_closed$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 AND n.nspname IN ('private','api','public') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE'))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (pg_catalog.pg_has_role('postgres',r.oid,'SET') OR pg_catalog.pg_has_role('postgres',r.oid,'USAGE')))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Temporary migration authority leaked'; END IF;
 END $compatibility_closed$;
COMMIT;
