-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=gf_provider_admin; source SHA-256=7a4c471bfb37afcc1346cd5ad87fc7cbb6db2c0a58142974b8411b0175c24ab9
-- Owner-only confirmed-income report and on-screen expiry reminders.
-- No email/SMS, payment demands, external messages or automatic renewal.
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $compatibility_graph$
 BEGIN
 IF current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper AND NOT rolbypassrls)
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
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
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper AND NOT rolbypassrls)
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option)
 OR (m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND NOT m.admin_option AND m.inherit_option AND m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
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
CREATE FUNCTION api.owner_income_report(p_actor_user_id uuid,p_from_date date DEFAULT NULL,p_to_date date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE today date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
 from_date date:=COALESCE(p_from_date,date_trunc('month',today::timestamp)::date);
 through_date date:=COALESCE(p_to_date,today); result jsonb;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF NOT isfinite(from_date) OR NOT isfinite(through_date) OR from_date<date '0001-01-01' OR through_date>date '9999-12-31'
 OR through_date<from_date OR through_date-from_date>365
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_INCOME_PERIOD'; END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s."gymLocalDate" DESC,s.source,s."paymentMethod"),'[]'::jsonb) INTO result FROM(
 SELECT (confirmed.at_time AT TIME ZONE 'Asia/Manila')::date AS "gymLocalDate",
 CASE WHEN a.membership_purchase_id IS NOT NULL THEN 'membership' ELSE 'walkin' END AS source,
 r.payment_method AS "paymentMethod",sum(r.amount_php)::text AS "amountPhp",count(*) AS "transactionCount"
 FROM private.payment_records r JOIN private.payment_allocations a ON a.payment_id=r.id
 LEFT JOIN private.membership_purchases p ON p.id=a.membership_purchase_id
 CROSS JOIN LATERAL(SELECT max(e.created_at) AS at_time FROM private.payment_events e WHERE e.payment_id=r.id AND e.event_type='payment.confirmed') confirmed
 WHERE r.verification_status='confirmed' AND confirmed.at_time>=(from_date::timestamp AT TIME ZONE 'Asia/Manila')
 AND confirmed.at_time<((through_date+1)::timestamp AT TIME ZONE 'Asia/Manila')
 AND ((a.membership_purchase_id IS NOT NULL AND private.receipt_membership_target_matches(r.id,p.id) AND r.amount_php=p.price_php)
  OR (a.walkin_request_id IS NOT NULL AND r.target_membership_purchase_id IS NULL))
 GROUP BY 1,2,3) s;
 RETURN result;
END $function$;

CREATE FUNCTION api.owner_expiry_reminders(p_actor_user_id uuid,p_window_days integer,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE at_time timestamptz:=clock_timestamp(); today date; result jsonb;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_window_days IS NULL OR p_window_days NOT BETWEEN 0 AND 31 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_EXPIRY_FILTER'; END IF;
 today:=(at_time AT TIME ZONE 'Asia/Manila')::date;
 SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s."expiryDate",s."purchaseId"),'[]'::jsonb) INTO result FROM(
 SELECT p.id AS "purchaseId",m.member_code AS "memberCode",m.full_name AS "memberName",
  p.activation_date AS "activationDate",p.expiry_date AS "expiryDate",p.expiry_date-today AS "daysToExpiry"
 FROM private.membership_purchases p JOIN private.members m ON m.id=p.member_id
 WHERE p.expiry_date BETWEEN today AND today+p_window_days AND private.member_checkin_eligible_purchase(m.id,at_time)=p.id
 AND NOT EXISTS(SELECT 1 FROM private.membership_purchases next_term WHERE next_term.member_id=m.id
  AND next_term.purchase_status='active' AND next_term.activation_date=p.expiry_date+1
  AND private.membership_payment_confirmed_at(next_term.id) IS NOT NULL)
 ORDER BY p.expiry_date,p.id LIMIT p_limit OFFSET p_offset) s;
 RETURN result;
END $function$;
DO $entrypoints$ DECLARE signature text; BEGIN
 FOREACH signature IN ARRAY ARRAY['api.owner_income_report(uuid,date,date)','api.owner_expiry_reminders(uuid,integer,integer,integer)'] LOOP
 EXECUTE 'ALTER FUNCTION '||signature||' OWNER TO gym_owner_executor';
 EXECUTE 'REVOKE ALL ON FUNCTION '||signature||' FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor';
 EXECUTE 'GRANT EXECUTE ON FUNCTION '||signature||' TO service_role';
 END LOOP;
END $entrypoints$;
CREATE FUNCTION api.owner_list_payable_purchases(p_actor_user_id uuid,p_search text DEFAULT NULL,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE result jsonb; search text:=NULLIF(btrim(COALESCE(p_search,'')),'');
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF length(COALESCE(p_search,''))>80 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_PURCHASE_FILTER'; END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.created_at DESC,s.id),'[]'::jsonb) INTO result FROM(
 SELECT p.id,m.full_name AS "memberName",m.member_code AS "memberCode",plan.name AS "planName",p.price_php::text AS "pricePhp",p.created_at
 FROM private.membership_purchases p JOIN private.members m ON m.id=p.member_id JOIN private.membership_plans plan ON plan.id=p.plan_id
 WHERE p.purchase_status='pending_payment' AND NOT EXISTS(SELECT 1 FROM private.payment_records r WHERE r.target_membership_purchase_id=p.id AND r.verification_status='recorded')
 AND NOT EXISTS(SELECT 1 FROM private.payment_allocations a WHERE a.membership_purchase_id=p.id)
 AND (search IS NULL OR strpos(lower(p.id::text||' '||m.member_code||' '||m.full_name||' '||plan.name),lower(search))>0)
 ORDER BY p.created_at DESC,p.id LIMIT p_limit OFFSET p_offset) s;
 RETURN result;
END $function$;
ALTER FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) TO service_role;
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
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper AND NOT rolbypassrls)
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option))))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
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
