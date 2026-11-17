-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=gf_provider_admin; source SHA-256=5f66c08fc3df9ba85760dc90ff69e1007e76409af2e77517b619b90407fe2b1e
-- SOURCE ONLY. Owner-approved reason/evidence review; independent review is
-- deferred until practical. Actual money, confirmed income and paid membership
-- remain separate. No refund, automatic allocation or historical rewriting.
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
 WHERE c.relkind IN ('r','p') AND c.relforcerowsecurity AND n.nspname='private' AND c.relname IN ('membership_purchases') LOOP
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND p.polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected maintenance policy'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND NOT p.polpermissive)
 THEN RAISE EXCEPTION 'Unreviewed restrictive policy prevents full-visibility proof'; END IF;
 EXECUTE pg_catalog.format('CREATE POLICY gf_compatibility_read ON %I.%I FOR SELECT TO postgres USING (CURRENT_USER = ''postgres''::name AND SESSION_USER = ''postgres''::name)',r.nspname,r.relname);
 END LOOP;
 END $compatibility_prepare$;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-receipt-corrections-v1',0));
LOCK TABLE private.payment_records,private.payment_allocations,private.membership_purchases,
 private.attendance_checkins IN ACCESS EXCLUSIVE MODE;

CREATE TABLE private.receipt_verifications(
 payment_id uuid PRIMARY KEY REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 verified_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 verified_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 reason text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(reason)) BETWEEN 5 AND 500),
 evidence_reference text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(evidence_reference)) BETWEEN 1 AND 300)
);
CREATE TABLE private.payment_confirmation_voids(
 id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
 payment_id uuid NOT NULL UNIQUE REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 voided_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 voided_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 reason text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(reason)) BETWEEN 5 AND 500),
 evidence_reference text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(evidence_reference)) BETWEEN 1 AND 300),
 receipt_still_received boolean NOT NULL
);
CREATE TABLE private.receipt_verification_voids(
 payment_id uuid PRIMARY KEY REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 confirmation_void_id uuid NOT NULL UNIQUE REFERENCES private.payment_confirmation_voids(id) ON DELETE RESTRICT,
 voided_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 voided_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 reason text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(reason)) BETWEEN 5 AND 500),
 evidence_reference text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(evidence_reference)) BETWEEN 1 AND 300)
);
CREATE TABLE private.receipt_replacement_links(
 original_payment_id uuid PRIMARY KEY REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 replacement_payment_id uuid NOT NULL UNIQUE REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 linked_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 linked_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 reason text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(reason)) BETWEEN 5 AND 500),
 evidence_reference text NOT NULL CHECK(pg_catalog.char_length(pg_catalog.btrim(evidence_reference)) BETWEEN 1 AND 300),
 CHECK(original_payment_id<>replacement_payment_id)
);

DO $tables$
DECLARE relation text; columns text;
BEGIN
 FOREACH relation IN ARRAY ARRAY['receipt_verifications','payment_confirmation_voids','receipt_verification_voids','receipt_replacement_links'] LOOP
  EXECUTE pg_catalog.format('ALTER TABLE private.%I OWNER TO gym_data_owner',relation);
  EXECUTE pg_catalog.format('ALTER TABLE private.%I ENABLE ROW LEVEL SECURITY',relation);
  EXECUTE pg_catalog.format('ALTER TABLE private.%I FORCE ROW LEVEL SECURITY',relation);
  EXECUTE pg_catalog.format('REVOKE ALL ON private.%I FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor',relation);
  SELECT pg_catalog.string_agg(pg_catalog.quote_ident(attname),',' ORDER BY attnum) INTO columns
   FROM pg_catalog.pg_attribute WHERE attrelid=pg_catalog.to_regclass('private.'||relation) AND attnum>0 AND NOT attisdropped;
  EXECUTE pg_catalog.format('GRANT SELECT(%s),INSERT(%s) ON private.%I TO gym_owner_executor',columns,columns,relation);
  EXECUTE pg_catalog.format('CREATE POLICY gf_owner_select ON private.%I FOR SELECT TO gym_owner_executor USING(CURRENT_USER=''gym_owner_executor''::name)',relation);
  EXECUTE pg_catalog.format('CREATE POLICY gf_owner_insert ON private.%I FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER=''gym_owner_executor''::name)',relation);
  EXECUTE pg_catalog.format('CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON private.%I FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
  EXECUTE pg_catalog.format('CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.%I FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
 END LOOP;
END $tables$;

CREATE FUNCTION private.assert_receipt_review_owner(p_actor_user_id uuid,p_reason text,p_evidence_reference text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_reason IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_reason)) NOT BETWEEN 5 AND 500
 OR p_evidence_reference IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_evidence_reference)) NOT BETWEEN 1 AND 300
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='RECEIPT_REASON_EVIDENCE_REQUIRED'; END IF;
END $function$;
ALTER FUNCTION private.assert_receipt_review_owner(uuid,text,text) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.assert_receipt_review_owner(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.assert_receipt_review_owner(uuid,text,text) TO gym_owner_executor;

-- Preserved legacy confirmations and walk-in receipt-review facts are proof
-- of actual money. An explicit proof-void overrides all of these sources.
CREATE FUNCTION private.is_receipt_verified(p_payment_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $function$
 SELECT NOT EXISTS(SELECT 1 FROM private.receipt_verification_voids WHERE payment_id=p_payment_id)
 AND (EXISTS(SELECT 1 FROM private.receipt_verifications WHERE payment_id=p_payment_id)
 OR EXISTS(SELECT 1 FROM private.receipt_review WHERE payment_id=p_payment_id)
 OR EXISTS(SELECT 1 FROM private.payment_events WHERE payment_id=p_payment_id AND event_type='payment.confirmed'));
$function$;
ALTER FUNCTION private.is_receipt_verified(uuid) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.is_receipt_verified(uuid) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.is_receipt_verified(uuid) TO gym_owner_executor;

CREATE FUNCTION api.owner_verify_actual_receipt(p_actor_user_id uuid,p_payment_id uuid,p_reason text,p_evidence_reference text,p_evidence_reviewed boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE receipt private.payment_records%ROWTYPE; proof private.receipt_verifications%ROWTYPE;
BEGIN
 PERFORM private.assert_receipt_review_owner(p_actor_user_id,p_reason,p_evidence_reference);
 IF p_payment_id IS NULL OR p_evidence_reviewed IS DISTINCT FROM true
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='ACTUAL_RECEIPT_ATTESTATION_REQUIRED'; END IF;
 SELECT * INTO receipt FROM private.payment_records WHERE id=p_payment_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='PAYMENT_NOT_FOUND'; END IF;
 IF EXISTS(SELECT 1 FROM private.receipt_verification_voids WHERE payment_id=receipt.id)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='RECEIPT_PROOF_REQUIRES_CORRECTION_REVIEW'; END IF;
 SELECT * INTO proof FROM private.receipt_verifications WHERE payment_id=receipt.id;
 IF FOUND THEN
  IF proof.verified_by<>p_actor_user_id OR proof.reason<>pg_catalog.btrim(p_reason) OR proof.evidence_reference<>pg_catalog.btrim(p_evidence_reference)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='RECEIPT_VERIFICATION_ALREADY_RECORDED'; END IF;
  RETURN pg_catalog.jsonb_build_object('paymentId',receipt.id,'verified',true,'allocationStatus',
   CASE WHEN EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=receipt.id) THEN 'allocated' ELSE 'unallocated' END,'replayed',true);
 END IF;
 INSERT INTO private.receipt_verifications(payment_id,verified_by,reason,evidence_reference)
 VALUES(receipt.id,p_actor_user_id,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_evidence_reference));
 INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id)
 VALUES(receipt.id,'receipt.verified',pg_catalog.btrim(p_reason),p_actor_user_id);
 PERFORM api.append_audit_event('payments',p_actor_user_id,'receipt.verified','payment',receipt.id::text,
  pg_catalog.jsonb_build_object('reason',pg_catalog.btrim(p_reason),'evidence_reference',pg_catalog.btrim(p_evidence_reference),'affects_membership',false));
 RETURN pg_catalog.jsonb_build_object('paymentId',receipt.id,'verified',true,'allocationStatus',
  CASE WHEN EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=receipt.id) THEN 'allocated' ELSE 'unallocated' END,'replayed',false);
END $function$;

CREATE FUNCTION api.owner_record_actual_receipt(p_actor_user_id uuid,p_operation_id uuid,p_amount_php numeric,p_payment_method text,
 p_reason text,p_evidence_reference text,p_evidence_reviewed boolean,p_replaces_payment_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE receipt private.payment_records%ROWTYPE; replay boolean:=false; result jsonb; prior_void uuid;
BEGIN
 PERFORM private.assert_receipt_review_owner(p_actor_user_id,p_reason,p_evidence_reference);
 IF p_operation_id IS NULL OR p_amount_php IS NULL OR p_amount_php<=0 OR p_amount_php>9999999999.99
 OR p_amount_php<>pg_catalog.round(p_amount_php,2) OR p_payment_method IS NULL OR p_payment_method NOT IN ('cash','gcash','bank_transfer')
 OR p_evidence_reviewed IS DISTINCT FROM true
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_ACTUAL_RECEIPT'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('actual-receipt:'||p_operation_id::text,0));
 SELECT * INTO receipt FROM private.payment_records WHERE operation_id=p_operation_id FOR UPDATE;
 IF FOUND THEN
  IF receipt.amount_php<>p_amount_php OR receipt.payment_method<>p_payment_method OR receipt.recorded_by<>p_actor_user_id
  OR receipt.target_membership_purchase_id IS NOT NULL OR receipt.evidence_reference IS DISTINCT FROM pg_catalog.btrim(p_evidence_reference)
  OR NOT EXISTS(SELECT 1 FROM private.payment_events WHERE payment_id=receipt.id AND event_type='receipt.actual_recorded')
  OR (SELECT original_payment_id FROM private.receipt_replacement_links WHERE replacement_payment_id=receipt.id) IS DISTINCT FROM p_replaces_payment_id
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='RECEIPT_OPERATION_CONFLICT'; END IF;
  replay:=true;
 ELSE
  IF p_replaces_payment_id IS NOT NULL THEN
   -- A replacement is a correction of erroneous receipt proof, never a second
   -- copy of money that is still verified as physically received.
   SELECT v.id INTO prior_void FROM private.payment_confirmation_voids v
   JOIN private.receipt_verification_voids proof ON proof.confirmation_void_id=v.id AND proof.payment_id=v.payment_id
   WHERE v.payment_id=p_replaces_payment_id AND NOT v.receipt_still_received;
   IF NOT FOUND OR EXISTS(SELECT 1 FROM private.receipt_replacement_links WHERE original_payment_id=p_replaces_payment_id)
   THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='DOCUMENTED_UNREPLACED_VOID_REQUIRED'; END IF;
  END IF;
  INSERT INTO private.payment_records(amount_php,payment_method,received_at,evidence_reference,recorded_by,operation_id)
  VALUES(p_amount_php,p_payment_method,pg_catalog.clock_timestamp(),pg_catalog.btrim(p_evidence_reference),p_actor_user_id,p_operation_id)
  RETURNING * INTO receipt;
  INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id)
  VALUES(receipt.id,'receipt.actual_recorded',pg_catalog.btrim(p_reason),p_actor_user_id);
  IF p_replaces_payment_id IS NOT NULL THEN
   INSERT INTO private.receipt_replacement_links(original_payment_id,replacement_payment_id,linked_by,reason,evidence_reference)
   VALUES(p_replaces_payment_id,receipt.id,p_actor_user_id,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_evidence_reference));
  END IF;
 END IF;
 result:=api.owner_verify_actual_receipt(p_actor_user_id,receipt.id,p_reason,p_evidence_reference,p_evidence_reviewed);
 RETURN result||pg_catalog.jsonb_build_object('replayed',replay,'replacesPaymentId',p_replaces_payment_id);
END $function$;

GRANT INSERT(evidence_reference) ON private.payment_records TO gym_owner_executor;

CREATE FUNCTION api.owner_list_receipt_review(p_actor_user_id uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE result jsonb;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_limit IS NULL OR p_limit<1 OR p_limit>100 OR p_offset IS NULL OR p_offset<0 OR p_offset>100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_RECEIPT_REVIEW_FILTERS'; END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('paymentId',p.id,'amountPhp',p.amount_php,
  'paymentMethod',p.payment_method,'receivedAt',p.received_at,'verificationStatus',p.verification_status,
  'actualReceiptVerified',private.is_receipt_verified(p.id),'targetPurchaseId',p.target_membership_purchase_id,
  'allocated',EXISTS(SELECT 1 FROM private.payment_allocations a WHERE a.payment_id=p.id),
  'confirmationVoided',EXISTS(SELECT 1 FROM private.payment_confirmation_voids v WHERE v.payment_id=p.id)) ORDER BY p.received_at DESC,p.id),'[]'::jsonb)
 INTO result FROM (SELECT * FROM private.payment_records ORDER BY received_at DESC,id LIMIT p_limit OFFSET p_offset) p;
 RETURN result;
END $function$;

-- Allocation of unmatched receipts is deliberately not exposed here. Existing
-- purchase snapshots/targets and whole-receipt constraints must be respected;
-- these verified facts remain in Owner review without access or confirmed income.

-- Remaining correction guards/entrypoint below are added in this migration so
-- originals and all dated terms remain preserved, never automatically restored.

CREATE OR REPLACE FUNCTION private.guard_membership_payment_record_update()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
 IF ROW(NEW.id,NEW.amount_php,NEW.payment_method,NEW.received_at,NEW.external_reference,NEW.evidence_reference,
  NEW.recorded_by,NEW.created_at,NEW.operation_id,NEW.target_membership_purchase_id)
 IS DISTINCT FROM ROW(OLD.id,OLD.amount_php,OLD.payment_method,OLD.received_at,OLD.external_reference,OLD.evidence_reference,
  OLD.recorded_by,OLD.created_at,OLD.operation_id,OLD.target_membership_purchase_id)
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='PAYMENT_RECEIPT_FACTS_IMMUTABLE'; END IF;
 IF OLD.verification_status='recorded' AND NEW.verification_status IN ('confirmed','rejected') THEN RETURN NEW; END IF;
 IF OLD.verification_status='confirmed' AND NEW.verification_status='confirmation_voided_in_error'
 AND EXISTS(SELECT 1 FROM private.payment_confirmation_voids WHERE payment_id=OLD.id)
 THEN RETURN NEW; END IF;
 RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='PAYMENT_RECORD_IMMUTABLE';
END $function$;

CREATE OR REPLACE FUNCTION private.guard_membership_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_dates record;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.purchase_status<>'pending_payment' OR NEW.activation_date IS NOT NULL OR NEW.expiry_date IS NOT NULL
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='MEMBERSHIP_PURCHASE_MUST_START_PENDING'; END IF;
  RETURN NEW;
 END IF;
 IF ROW(NEW.id,NEW.member_id,NEW.plan_id,NEW.price_php,NEW.created_at)
 IS DISTINCT FROM ROW(OLD.id,OLD.member_id,OLD.plan_id,OLD.price_php,OLD.created_at)
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='MEMBERSHIP_PURCHASE_FACTS_IMMUTABLE'; END IF;
 IF CURRENT_USER='gym_owner_executor' AND OLD.purchase_status IN ('pending_activation','active','expired')
 AND NEW.purchase_status='payment_review' AND NEW.activation_date IS NOT DISTINCT FROM OLD.activation_date
 AND NEW.expiry_date IS NOT DISTINCT FROM OLD.expiry_date
 AND EXISTS(SELECT 1 FROM private.payment_allocations a JOIN private.payment_confirmation_voids v ON v.payment_id=a.payment_id
  JOIN private.payment_records r ON r.id=a.payment_id WHERE a.membership_purchase_id=OLD.id AND r.verification_status='confirmation_voided_in_error')
 THEN RETURN NEW; END IF;
 IF OLD.activation_date IS NOT NULL OR OLD.expiry_date IS NOT NULL THEN
  IF ROW(NEW.purchase_status,NEW.activation_date,NEW.expiry_date) IS DISTINCT FROM ROW(OLD.purchase_status,OLD.activation_date,OLD.expiry_date)
  THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='MEMBERSHIP_TERM_IMMUTABLE'; END IF;
  RETURN NEW;
 END IF;
 IF OLD.purchase_status='pending_activation' AND NEW.purchase_status='active' THEN
  SELECT * INTO v_dates FROM private.membership_activation_dates(NEW.member_id,NEW.id);
  IF NEW.activation_date IS DISTINCT FROM v_dates.activation_date OR NEW.expiry_date IS DISTINCT FROM v_dates.expiry_date
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='MEMBERSHIP_DATES_MUST_MATCH_SERVER_BASIS'; END IF;
 ELSIF NEW.activation_date IS NOT NULL OR NEW.expiry_date IS NOT NULL
 OR (NEW.purchase_status IS DISTINCT FROM OLD.purchase_status AND NOT(OLD.purchase_status='pending_payment' AND NEW.purchase_status='pending_activation'))
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='MEMBERSHIP_LIFECYCLE_TRANSITION_INVALID'; END IF;
 RETURN NEW;
END $function$;

-- A documented invalidated term stays in history with its original dates, but
-- does not block a newly purchased/paid replacement term from those dates.
DO $legacy_review$ BEGIN
 IF EXISTS(SELECT 1 FROM private.membership_purchases WHERE purchase_status='payment_review' AND activation_date IS NOT NULL)
 THEN RAISE EXCEPTION 'Historical review terms require explicit basis review before correction migration'; END IF;
END $legacy_review$;
ALTER TABLE private.membership_purchases DROP CONSTRAINT membership_purchases_no_overlapping_periods;
ALTER TABLE private.membership_purchases ADD CONSTRAINT membership_purchases_no_overlapping_periods
 EXCLUDE USING gist(member_id extensions.gist_uuid_ops WITH =,daterange(activation_date,expiry_date,'[]') WITH &&)
 WHERE(activation_date IS NOT NULL AND expiry_date IS NOT NULL AND purchase_status<>'payment_review');

GRANT SELECT(member_id,membership_purchase_id),UPDATE(attendance_status) ON private.attendance_checkins TO gym_owner_executor;
CREATE POLICY gf_owner_correction_update ON private.attendance_checkins FOR UPDATE TO gym_owner_executor
 USING(CURRENT_USER='gym_owner_executor'::name) WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
GRANT SELECT(id,attendance_id,prior_status,new_status,reason,resolved_by,resolved_at),
 INSERT(attendance_id,prior_status,new_status,reason,resolved_by,resolved_at)
 ON private.attendance_validity_resolutions TO gym_owner_executor;
-- The scoped attendance-history migration already supplies SELECT policy.
CREATE POLICY gf_owner_insert ON private.attendance_validity_resolutions FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON private.attendance_validity_resolutions FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.attendance_validity_resolutions FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE FUNCTION private.guard_attendance_payment_invalidation()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
 IF TG_OP<>'UPDATE' THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='ATTENDANCE_HISTORY_PRESERVED'; END IF;
 IF ROW(NEW.id,NEW.member_id,NEW.walkin_request_id,NEW.gym_local_date,NEW.checked_in_at,NEW.membership_purchase_id)
 IS DISTINCT FROM ROW(OLD.id,OLD.member_id,OLD.walkin_request_id,OLD.gym_local_date,OLD.checked_in_at,OLD.membership_purchase_id)
 OR CURRENT_USER<>'gym_owner_executor' OR OLD.attendance_status NOT IN ('valid','review') OR NEW.attendance_status<>'invalidated_payment'
 OR NOT EXISTS(SELECT 1 FROM private.payment_allocations a JOIN private.payment_confirmation_voids v ON v.payment_id=a.payment_id
  WHERE (OLD.membership_purchase_id IS NOT NULL AND a.membership_purchase_id=OLD.membership_purchase_id)
   OR (OLD.walkin_request_id IS NOT NULL AND a.walkin_request_id=OLD.walkin_request_id))
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='ATTENDANCE_CORRECTION_REQUIRES_DOCUMENTED_VOID'; END IF;
 RETURN NEW;
END $function$;
ALTER FUNCTION private.guard_attendance_payment_invalidation() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_attendance_payment_invalidation() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.guard_attendance_payment_invalidation() TO gym_owner_executor;
CREATE TRIGGER attendance_guard_correction BEFORE UPDATE OR DELETE ON private.attendance_checkins
 FOR EACH ROW EXECUTE FUNCTION private.guard_attendance_payment_invalidation();
CREATE TRIGGER attendance_no_truncate BEFORE TRUNCATE ON private.attendance_checkins
 FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE FUNCTION api.owner_void_payment_confirmation(p_actor_user_id uuid,p_payment_id uuid,p_reason text,p_evidence_reference text,p_receipt_still_received boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE receipt private.payment_records%ROWTYPE; allocation private.payment_allocations%ROWTYPE;
 prior private.payment_confirmation_voids%ROWTYPE; member uuid; void_id uuid; attendance record; affected integer:=0;
BEGIN
 PERFORM private.assert_receipt_review_owner(p_actor_user_id,p_reason,p_evidence_reference);
 IF p_payment_id IS NULL OR p_receipt_still_received IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_CONFIRMATION_CORRECTION'; END IF;
 -- The member row is the same serialization point used by current check-in.
 -- Allocation identity is immutable, so this preliminary identity read is safe.
 SELECT * INTO allocation FROM private.payment_allocations WHERE payment_id=p_payment_id;
 IF allocation.membership_purchase_id IS NOT NULL THEN
  SELECT member_id INTO member FROM private.membership_purchases WHERE id=allocation.membership_purchase_id;
  PERFORM id FROM private.members WHERE id=member FOR UPDATE;
 ELSIF allocation.walkin_request_id IS NOT NULL THEN
  PERFORM id FROM private.walkin_requests WHERE id=allocation.walkin_request_id FOR UPDATE;
 END IF;
 SELECT * INTO receipt FROM private.payment_records WHERE id=p_payment_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='PAYMENT_NOT_FOUND'; END IF;
 SELECT * INTO prior FROM private.payment_confirmation_voids WHERE payment_id=receipt.id;
 IF FOUND THEN
  IF prior.voided_by<>p_actor_user_id OR prior.reason<>pg_catalog.btrim(p_reason)
  OR prior.evidence_reference<>pg_catalog.btrim(p_evidence_reference) OR prior.receipt_still_received<>p_receipt_still_received
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CONFIRMATION_VOID_ALREADY_RECORDED'; END IF;
  RETURN pg_catalog.jsonb_build_object('paymentId',receipt.id,'voidId',prior.id,'receiptStillReceived',prior.receipt_still_received,'replayed',true);
 END IF;
 IF receipt.verification_status<>'confirmed' OR allocation.id IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CONFIRMED_ALLOCATED_PAYMENT_REQUIRED'; END IF;
 IF allocation.membership_purchase_id IS NOT NULL AND EXISTS(SELECT 1 FROM private.attendance_checkins
  WHERE member_id=member AND membership_purchase_id IS NULL AND attendance_status IN ('valid','review'))
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LEGACY_ATTENDANCE_BASIS_REVIEW_REQUIRED'; END IF;
 INSERT INTO private.payment_confirmation_voids(payment_id,voided_by,reason,evidence_reference,receipt_still_received)
 VALUES(receipt.id,p_actor_user_id,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_evidence_reference),p_receipt_still_received) RETURNING id INTO void_id;
 IF p_receipt_still_received THEN
  INSERT INTO private.receipt_verifications(payment_id,verified_by,reason,evidence_reference)
  VALUES(receipt.id,p_actor_user_id,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_evidence_reference)) ON CONFLICT(payment_id) DO NOTHING;
 ELSE
  INSERT INTO private.receipt_verification_voids(payment_id,confirmation_void_id,voided_by,reason,evidence_reference)
  VALUES(receipt.id,void_id,p_actor_user_id,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_evidence_reference));
 END IF;
 UPDATE private.payment_records SET verification_status='confirmation_voided_in_error' WHERE id=receipt.id;
 IF allocation.membership_purchase_id IS NOT NULL THEN
  UPDATE private.membership_purchases SET purchase_status='payment_review' WHERE id=allocation.membership_purchase_id;
 END IF;
 FOR attendance IN SELECT id,attendance_status FROM private.attendance_checkins WHERE attendance_status IN ('valid','review')
  AND ((allocation.membership_purchase_id IS NOT NULL AND membership_purchase_id=allocation.membership_purchase_id)
    OR (allocation.walkin_request_id IS NOT NULL AND walkin_request_id=allocation.walkin_request_id)) FOR UPDATE
 LOOP
  UPDATE private.attendance_checkins SET attendance_status='invalidated_payment' WHERE id=attendance.id;
  INSERT INTO private.attendance_validity_resolutions(attendance_id,prior_status,new_status,reason,resolved_by,resolved_at)
  VALUES(attendance.id,attendance.attendance_status,'invalidated_payment',pg_catalog.btrim(p_reason),p_actor_user_id,pg_catalog.clock_timestamp());
  PERFORM api.append_audit_event('attendance',p_actor_user_id,'attendance.payment_invalidated','attendance',attendance.id::text,
   pg_catalog.jsonb_build_object('reason',pg_catalog.btrim(p_reason),'evidence_reference',pg_catalog.btrim(p_evidence_reference),'payment_id',receipt.id,'void_id',void_id));
  affected:=affected+1;
 END LOOP;
 INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id)
 VALUES(receipt.id,'payment.confirmation_voided',pg_catalog.btrim(p_reason),p_actor_user_id);
 PERFORM api.append_audit_event('payments',p_actor_user_id,'payment.confirmation_voided','payment',receipt.id::text,
  pg_catalog.jsonb_build_object('reason',pg_catalog.btrim(p_reason),'evidence_reference',pg_catalog.btrim(p_evidence_reference),
   'receipt_still_received',p_receipt_still_received,'void_id',void_id,'affected_attendance_count',affected));
 RETURN pg_catalog.jsonb_build_object('paymentId',receipt.id,'voidId',void_id,'affectedAttendanceCount',affected,'receiptStillReceived',p_receipt_still_received,'replayed',false);
END $function$;

-- Ignore only documented review terms when calculating a replacement. Every
-- other activation, payment and overlap rule keeps its original server basis.
CREATE OR REPLACE FUNCTION private.membership_activation_dates(p_member_id uuid,p_purchase_id uuid)
RETURNS TABLE(activation_date date,expiry_date date)
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_member private.members%ROWTYPE; v_paid_at timestamptz; v_now timestamptz;
 v_today date; v_eligible date; v_current_expiry date; v_activation date; v_expiry date;
BEGIN
 SELECT * INTO v_member FROM private.members WHERE id=p_member_id FOR UPDATE;
 IF NOT FOUND OR v_member.status<>'active' OR v_member.approved_at IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='MEMBER_APPROVAL_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.membership_purchases WHERE id=p_purchase_id AND member_id=p_member_id)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='MEMBERSHIP_PURCHASE_MEMBER_MISMATCH'; END IF;
 v_paid_at:=private.membership_payment_confirmed_at(p_purchase_id);
 v_now:=pg_catalog.clock_timestamp();
 IF v_paid_at IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='PURCHASE_REQUIRES_CONFIRMED_FULL_PAYMENT'; END IF;
 IF v_paid_at>v_now OR v_member.approved_at>v_now
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='MEMBERSHIP_SERVER_DATE_REVIEW_REQUIRED'; END IF;
 v_today:=(v_now AT TIME ZONE 'Asia/Manila')::date;
 v_eligible:=GREATEST((v_paid_at AT TIME ZONE 'Asia/Manila')::date,(v_member.approved_at AT TIME ZONE 'Asia/Manila')::date);
 IF EXISTS(SELECT 1 FROM private.membership_purchases p WHERE p.member_id=p_member_id AND p.id<>p_purchase_id
  AND p.purchase_status<>'payment_review' AND p.activation_date>v_today)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='FUTURE_MEMBERSHIP_TERM_ALREADY_EXISTS'; END IF;
 SELECT pg_catalog.max(p.expiry_date) INTO v_current_expiry FROM private.membership_purchases p
 WHERE p.member_id=p_member_id AND p.id<>p_purchase_id AND p.purchase_status<>'payment_review'
 AND p.activation_date<=v_eligible AND p.expiry_date>=v_eligible;
 v_activation:=CASE WHEN v_current_expiry IS NOT NULL THEN v_current_expiry+1 ELSE v_eligible END;
 v_expiry:=private.membership_inclusive_expiry(v_activation);
 IF EXISTS(SELECT 1 FROM private.membership_purchases p WHERE p.member_id=p_member_id AND p.id<>p_purchase_id
  AND p.purchase_status<>'payment_review' AND p.activation_date IS NOT NULL
  AND pg_catalog.daterange(p.activation_date,p.expiry_date,'[]')&&pg_catalog.daterange(v_activation,v_expiry,'[]'))
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='MEMBERSHIP_TERM_OVERLAP_REVIEW_REQUIRED'; END IF;
 activation_date:=v_activation; expiry_date:=v_expiry; RETURN NEXT;
END $function$;

DO $entrypoints$
DECLARE signature text;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
  'api.owner_verify_actual_receipt(uuid,uuid,text,text,boolean)',
  'api.owner_record_actual_receipt(uuid,uuid,numeric,text,text,text,boolean,uuid)',
  'api.owner_list_receipt_review(uuid,integer,integer)',
  'api.owner_void_payment_confirmation(uuid,uuid,text,text,boolean)'] LOOP
  EXECUTE 'ALTER FUNCTION '||signature||' OWNER TO gym_owner_executor';
  EXECUTE 'REVOKE ALL ON FUNCTION '||signature||' FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor';
  EXECUTE 'GRANT EXECUTE ON FUNCTION '||signature||' TO service_role';
 END LOOP;
END $entrypoints$;

DO $acceptance$
DECLARE relation text; actor text; signature text;
BEGIN
 FOREACH relation IN ARRAY ARRAY['receipt_verifications','payment_confirmation_voids','receipt_verification_voids','receipt_replacement_links'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class WHERE oid=pg_catalog.to_regclass('private.'||relation)
   AND relrowsecurity AND relforcerowsecurity AND relowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_data_owner'))
  THEN RAISE EXCEPTION 'Receipt history ownership/RLS missing'; END IF;
  FOREACH actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_public_executor','gym_checkin_executor','gym_owner_executor'] LOOP
   IF pg_catalog.has_table_privilege(actor,'private.'||relation,'UPDATE,DELETE,TRUNCATE')
   THEN RAISE EXCEPTION 'Receipt history mutation privilege exposed'; END IF;
   IF actor<>'gym_owner_executor' AND pg_catalog.has_any_column_privilege(actor,'private.'||relation,'SELECT,INSERT')
   THEN RAISE EXCEPTION 'Receipt history data privilege exposed'; END IF;
  END LOOP;
 END LOOP;
 FOREACH signature IN ARRAY ARRAY[
  'api.owner_verify_actual_receipt(uuid,uuid,text,text,boolean)',
  'api.owner_record_actual_receipt(uuid,uuid,numeric,text,text,text,boolean,uuid)',
  'api.owner_list_receipt_review(uuid,integer,integer)',
  'api.owner_void_payment_confirmation(uuid,uuid,text,text,boolean)'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc WHERE oid=pg_catalog.to_regprocedure(signature)
   AND proowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_owner_executor') AND prosecdef
   AND proconfig=ARRAY['search_path=""']::text[])
  THEN RAISE EXCEPTION 'Receipt entrypoint boundary drift'; END IF;
  FOREACH actor IN ARRAY ARRAY['anon','authenticated','gym_public_executor','gym_checkin_executor'] LOOP
   IF pg_catalog.has_function_privilege(actor,signature,'EXECUTE') THEN RAISE EXCEPTION 'Receipt RPC exposed'; END IF;
  END LOOP;
 END LOOP;
END $acceptance$;

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
