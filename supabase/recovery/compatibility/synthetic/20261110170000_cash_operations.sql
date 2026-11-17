-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=gf_provider_admin; source SHA-256=96bab1c3491f7129aaceffb9d032d5cebd622e2e69f0c5e9e44f3971c8b6969b
-- Approved daily cash procedure. Snapshots never change payment or income.
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
 FOR r IN SELECT n.nspname,c.relname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p') AND c.relforcerowsecurity AND n.nspname='private' AND c.relname IN ('cash_drawer_sessions') LOOP
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND p.polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected maintenance policy'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND NOT p.polpermissive)
 THEN RAISE EXCEPTION 'Unreviewed restrictive policy prevents full-visibility proof'; END IF;
 EXECUTE pg_catalog.format('CREATE POLICY gf_compatibility_read ON %I.%I FOR SELECT TO postgres USING (CURRENT_USER = ''postgres''::name AND SESSION_USER = ''postgres''::name)',r.nspname,r.relname);
 END LOOP;
 END $compatibility_prepare$;
SET LOCAL search_path=pg_catalog;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
LOCK TABLE private.cash_drawer_sessions,private.cash_reconciliations IN ACCESS EXCLUSIVE MODE;
-- Future receipt timestamps use the actual insert instant after lock waits.
-- Original receipt dates remain unchanged.
ALTER TABLE private.payment_records ALTER COLUMN received_at SET DEFAULT clock_timestamp();
DO $legacy$ BEGIN
 IF EXISTS(SELECT 1 FROM private.cash_drawer_sessions) THEN
  RAISE EXCEPTION 'Legacy cash sessions require Owner evidence review before daily procedure migration';
 END IF;
END $legacy$;
ALTER TABLE private.cash_drawer_sessions ADD COLUMN business_date date NOT NULL;
ALTER TABLE private.cash_drawer_sessions ADD COLUMN operation_id uuid NOT NULL UNIQUE;
ALTER TABLE private.cash_drawer_sessions ADD CONSTRAINT drawer_one_business_day UNIQUE(business_date);
ALTER TABLE private.cash_reconciliations ADD COLUMN reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 500);
ALTER TABLE private.cash_reconciliations ADD COLUMN evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 300);
CREATE TABLE private.cash_reconciliation_receipts(
 reconciliation_id uuid NOT NULL REFERENCES private.cash_reconciliations(id) ON DELETE RESTRICT,
 payment_id uuid NOT NULL REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 amount_php numeric(12,2) NOT NULL CHECK(amount_php>0),
 PRIMARY KEY(reconciliation_id,payment_id)
);
ALTER TABLE private.cash_reconciliation_receipts OWNER TO gym_data_owner;
ALTER TABLE private.cash_reconciliation_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cash_reconciliation_receipts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.cash_reconciliation_receipts FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor,gym_owner_executor;
GRANT SELECT(reconciliation_id,payment_id,amount_php),INSERT(reconciliation_id,payment_id,amount_php)
 ON private.cash_reconciliation_receipts TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.cash_reconciliation_receipts FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.cash_reconciliation_receipts FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
GRANT SELECT(id,opened_at,opened_by,opening_float_php,session_status,closed_at,closed_by,business_date,operation_id),
 INSERT(opened_at,opened_by,opening_float_php,business_date,operation_id),UPDATE(session_status,closed_at,closed_by)
 ON private.cash_drawer_sessions TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.cash_drawer_sessions FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.cash_drawer_sessions FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_update ON private.cash_drawer_sessions FOR UPDATE TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name) WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
GRANT SELECT(id,drawer_session_id,expected_cash_php,counted_cash_php,variance_php,reconciled_by,reconciled_at,notes,reason,evidence_reference),
 INSERT(drawer_session_id,expected_cash_php,counted_cash_php,reconciled_by,reconciled_at,reason,evidence_reference)
 ON private.cash_reconciliations TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.cash_reconciliations FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.cash_reconciliations FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);

DO $append_only$
DECLARE relation text;
BEGIN
 FOREACH relation IN ARRAY ARRAY['cash_reconciliations','cash_reconciliation_receipts','cash_reconciliation_adjustments'] LOOP
  EXECUTE format('CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON private.%I FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
  EXECUTE format('CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.%I FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
 END LOOP;
END $append_only$;
CREATE FUNCTION private.guard_cash_session() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
 IF TG_OP='UPDATE' AND ROW(NEW.id,NEW.opened_at,NEW.opened_by,NEW.opening_float_php,NEW.business_date,NEW.operation_id)
  IS NOT DISTINCT FROM ROW(OLD.id,OLD.opened_at,OLD.opened_by,OLD.opening_float_php,OLD.business_date,OLD.operation_id)
  AND OLD.session_status='open' AND NEW.session_status='closed' AND NEW.closed_by IS NOT NULL
  AND NEW.closed_at IS NOT NULL AND EXISTS(SELECT 1 FROM private.cash_reconciliations WHERE drawer_session_id=OLD.id)
 THEN RETURN NEW; END IF;
 RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='CASH_SESSION_HISTORY_PRESERVED';
END $function$;
ALTER FUNCTION private.guard_cash_session() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_cash_session() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.guard_cash_session() TO gym_owner_executor;
CREATE TRIGGER guarded_close BEFORE UPDATE OR DELETE ON private.cash_drawer_sessions FOR EACH ROW EXECUTE FUNCTION private.guard_cash_session();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.cash_drawer_sessions FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE FUNCTION api.owner_open_cash_drawer(p_actor_user_id uuid,p_operation_id uuid,p_opening_float_php numeric,p_attested boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE prior private.cash_drawer_sessions%ROWTYPE; new_id uuid; today date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_operation_id IS NULL OR p_attested IS DISTINCT FROM true OR p_opening_float_php IS NULL
  OR p_opening_float_php<0 OR p_opening_float_php>9999999999.99 OR p_opening_float_php<>round(p_opening_float_php,2)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_OPENING_FLOAT'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('gymforce-cash-drawer',0));
 SELECT * INTO prior FROM private.cash_drawer_sessions WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF prior.opened_by<>p_actor_user_id OR prior.opening_float_php<>p_opening_float_php
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CASH_OPERATION_CONFLICT'; END IF;
  RETURN jsonb_build_object('id',prior.id,'businessDate',prior.business_date,'replayed',true);
 END IF;
 IF EXISTS(SELECT 1 FROM private.cash_drawer_sessions WHERE session_status='open' OR business_date=today)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='DRAWER_ALREADY_RECORDED_OR_REVIEW_REQUIRED'; END IF;
 INSERT INTO private.cash_drawer_sessions(opened_at,opened_by,opening_float_php,business_date,operation_id)
 VALUES(clock_timestamp(),p_actor_user_id,p_opening_float_php,today,p_operation_id) RETURNING id INTO new_id;
 PERFORM api.append_audit_event('cash',p_actor_user_id,'cash.drawer_opened','cash_drawer',new_id::text,
  jsonb_build_object('reason','Owner physically counted and attested opening float.','opening_float_php',p_opening_float_php,'business_date',today));
 RETURN jsonb_build_object('id',new_id,'businessDate',today,'replayed',false);
END $function$;

CREATE FUNCTION api.owner_close_cash_drawer(p_actor_user_id uuid,p_drawer_id uuid,p_counted_cash_php numeric,p_reason text,p_evidence_reference text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE drawer private.cash_drawer_sessions%ROWTYPE; prior private.cash_reconciliations%ROWTYPE;
 total numeric; new_id uuid; closed timestamptz; receipt_ids uuid[];
BEGIN
 PERFORM private.assert_receipt_review_owner(p_actor_user_id,p_reason,p_evidence_reference);
 IF p_drawer_id IS NULL OR p_counted_cash_php IS NULL OR p_counted_cash_php<0 OR p_counted_cash_php>9999999999.99 OR p_counted_cash_php<>round(p_counted_cash_php,2)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_CASH_COUNT'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('gymforce-cash-drawer',0));
 SELECT * INTO drawer FROM private.cash_drawer_sessions WHERE id=p_drawer_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='DRAWER_NOT_FOUND'; END IF;
 SELECT * INTO prior FROM private.cash_reconciliations WHERE drawer_session_id=drawer.id;
 IF FOUND THEN
  IF prior.counted_cash_php<>p_counted_cash_php OR prior.reconciled_by<>p_actor_user_id OR prior.reason<>btrim(p_reason) OR prior.evidence_reference<>btrim(p_evidence_reference)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CASH_CLOSE_ALREADY_RECORDED'; END IF;
  RETURN jsonb_build_object('id',prior.id,'expectedCashPhp',prior.expected_cash_php::text,'countedCashPhp',prior.counted_cash_php::text,'variancePhp',prior.variance_php::text,'replayed',true);
 END IF;
 closed:=clock_timestamp();
 IF drawer.business_date<>(closed AT TIME ZONE 'Asia/Manila')::date
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='STALE_DRAWER_OWNER_REVIEW_REQUIRED'; END IF;
 -- Acquire a consistent receipt snapshot. Later verifications/corrections do
 -- not rewrite the snapshot or its preserved receipt IDs.
 SELECT drawer.opening_float_php+COALESCE(sum(p.amount_php),0),COALESCE(array_agg(p.id),ARRAY[]::uuid[])
 INTO total,receipt_ids FROM private.payment_records p
 WHERE p.payment_method='cash' AND (p.received_at AT TIME ZONE 'Asia/Manila')::date=drawer.business_date AND private.is_receipt_verified(p.id);
 IF total>9999999999.99 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CASH_TOTAL_REVIEW_REQUIRED'; END IF;
 INSERT INTO private.cash_reconciliations(drawer_session_id,expected_cash_php,counted_cash_php,reconciled_by,reconciled_at,reason,evidence_reference)
 VALUES(drawer.id,total,p_counted_cash_php,p_actor_user_id,closed,btrim(p_reason),btrim(p_evidence_reference)) RETURNING id INTO new_id;
 INSERT INTO private.cash_reconciliation_receipts(reconciliation_id,payment_id,amount_php)
 SELECT new_id,p.id,p.amount_php FROM private.payment_records p WHERE p.id=ANY(receipt_ids);
 UPDATE private.cash_drawer_sessions SET session_status='closed',closed_at=closed,closed_by=p_actor_user_id WHERE id=drawer.id;
 PERFORM api.append_audit_event('cash',p_actor_user_id,'cash.drawer_closed','cash_drawer',drawer.id::text,
 jsonb_build_object('reason',btrim(p_reason),'evidence_reference',btrim(p_evidence_reference),'expected_cash_php',total,'counted_cash_php',p_counted_cash_php,'variance_php',p_counted_cash_php-total));
 RETURN jsonb_build_object('id',new_id,'expectedCashPhp',total::text,'countedCashPhp',p_counted_cash_php::text,'variancePhp',(p_counted_cash_php-total)::text,'replayed',false);
END $function$;

CREATE FUNCTION api.owner_list_cash_drawers(p_actor_user_id uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE result jsonb;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_FILTERS'; END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(s)),'[]'::jsonb) INTO result FROM(
 SELECT d.id,d.business_date AS "businessDate",d.session_status AS status,d.opening_float_php::text AS "openingFloatPhp",
  r.expected_cash_php::text AS "expectedCashPhp",r.counted_cash_php::text AS "countedCashPhp",r.variance_php::text AS "variancePhp",
  r.reason,r.evidence_reference AS "evidenceReference" FROM private.cash_drawer_sessions d
 LEFT JOIN private.cash_reconciliations r ON r.drawer_session_id=d.id ORDER BY d.business_date DESC,d.id DESC LIMIT p_limit OFFSET p_offset) s;
 RETURN result;
END $function$;
DO $entrypoints$ DECLARE signature text; BEGIN
 FOREACH signature IN ARRAY ARRAY['api.owner_open_cash_drawer(uuid,uuid,numeric,boolean)','api.owner_close_cash_drawer(uuid,uuid,numeric,text,text)','api.owner_list_cash_drawers(uuid,integer,integer)'] LOOP
 EXECUTE 'ALTER FUNCTION '||signature||' OWNER TO gym_owner_executor';
 EXECUTE 'REVOKE ALL ON FUNCTION '||signature||' FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor';
 EXECUTE 'GRANT EXECUTE ON FUNCTION '||signature||' TO service_role';
 END LOOP;
END $entrypoints$;
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
