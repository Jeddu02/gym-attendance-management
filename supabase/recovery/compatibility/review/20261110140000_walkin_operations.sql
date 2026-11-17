-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=supabase_admin; source SHA-256=48d8d2c9b8e6e2d890e4625b88455bca3084d67f0c2452b918336c7e21910303
-- Source only. The Owner approved a 15-minute provisional request lifetime.
-- No initial fee or production abuse threshold is assumed. Public Edge must
-- supply its explicitly configured rolling-minute limit to the server RPC.
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
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-walkin-operations-v1',0));
LOCK TABLE private.walkin_requests,private.walkin_fee_versions,private.payment_records,
    private.payment_allocations,private.attendance_checkins IN ACCESS EXCLUSIVE MODE;

DO $walkin_preconditions$
BEGIN
    IF (SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN
        ('gym_data_owner','gym_owner_executor','gym_public_executor')
        AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
        AND NOT rolinherit AND NOT rolbypassrls AND NOT rolreplication)<>3
       OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members a JOIN pg_catalog.pg_roles r
           ON r.oid=a.member OR r.oid=a.roleid WHERE r.rolname IN
           ('gym_data_owner','gym_owner_executor','gym_public_executor') AND NOT (a.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND a.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((a.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin')
 AND a.admin_option AND NOT a.inherit_option AND NOT a.set_option)
 OR (a.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND NOT a.admin_option AND a.inherit_option AND a.set_option)))) THEN
        RAISE EXCEPTION 'Restricted executor foundation required';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind='r' AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity
          OR c.relowner<>(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_data_owner'))) THEN
        RAISE EXCEPTION 'Protected application tables required';
    END IF;
END;
$walkin_preconditions$;

-- NULL is retained only for original legacy history. No historical row is
-- backfilled, re-priced, revived or assigned a guessed payment method.
ALTER TABLE private.walkin_requests ADD COLUMN requested_payment_method text
    CHECK(requested_payment_method IN ('cash','gcash','bank_transfer'));
-- Refuse inconsistent legacy allocation history rather than silently choose
-- one receipt or rewrite any ledger entry during a migration.
CREATE UNIQUE INDEX payment_allocations_one_walkin_receipt ON private.payment_allocations(walkin_request_id)
    WHERE walkin_request_id IS NOT NULL;

CREATE TABLE private.walkin_request_rate_events(
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requested_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
CREATE INDEX walkin_request_rate_events_time_idx ON private.walkin_request_rate_events(requested_at);
ALTER TABLE private.walkin_request_rate_events OWNER TO gym_data_owner;
ALTER TABLE private.walkin_request_rate_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.walkin_request_rate_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.walkin_request_rate_events FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
REVOKE ALL ON SEQUENCE private.walkin_request_rate_events_id_seq FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT SELECT(requested_at),INSERT(requested_at) ON private.walkin_request_rate_events TO gym_public_executor;
GRANT DELETE ON private.walkin_request_rate_events TO gym_public_executor;
CREATE POLICY gf_public_select ON private.walkin_request_rate_events FOR SELECT TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name);
CREATE POLICY gf_public_insert ON private.walkin_request_rate_events FOR INSERT TO gym_public_executor WITH CHECK(CURRENT_USER='gym_public_executor'::name);
CREATE POLICY gf_public_delete ON private.walkin_request_rate_events FOR DELETE TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name);

-- Verified receipt facts awaiting separate Owner allocation/review. The money
-- exists independently of purchase-paid status; these rows grant no access and
-- do not count as confirmed income. No resolution/refund/correction is invented.
CREATE TABLE private.receipt_review(
    payment_id uuid PRIMARY KEY REFERENCES private.payment_records(id) ON DELETE RESTRICT,
    walkin_request_id uuid NOT NULL REFERENCES private.walkin_requests(id) ON DELETE RESTRICT,
    verified_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    verified_at timestamptz NOT NULL,
    reason text NOT NULL CHECK(pg_catalog.length(pg_catalog.btrim(reason))>0),
    evidence_reviewed boolean NOT NULL
);
CREATE INDEX receipt_review_walkin_idx ON private.receipt_review(walkin_request_id,verified_at);
ALTER TABLE private.receipt_review OWNER TO gym_data_owner;
ALTER TABLE private.receipt_review ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.receipt_review FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.receipt_review FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT SELECT(payment_id,walkin_request_id,verified_by,verified_at,reason,evidence_reviewed),
    INSERT(payment_id,walkin_request_id,verified_by,verified_at,reason,evidence_reviewed)
    ON private.receipt_review TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.receipt_review FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.receipt_review FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);

GRANT SELECT(id,fee_php,currency,effective_from,created_by,created_at),
    INSERT(fee_php,currency,effective_from,created_by,created_at)
    ON private.walkin_fee_versions TO gym_owner_executor;
GRANT SELECT(id,fee_php,currency,effective_from,created_at) ON private.walkin_fee_versions TO gym_public_executor;
CREATE POLICY gf_owner_select ON private.walkin_fee_versions FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.walkin_fee_versions FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_public_select ON private.walkin_fee_versions FOR SELECT TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name);

GRANT SELECT(id,fee_version_id,fee_php,currency,request_status,created_at,expires_at,confirmed_by,confirmed_at,requested_payment_method),
    UPDATE(request_status,confirmed_by,confirmed_at) ON private.walkin_requests TO gym_owner_executor;
GRANT SELECT(id),INSERT(fee_version_id,fee_php,currency,request_status,created_at,expires_at,requested_payment_method)
    ON private.walkin_requests TO gym_public_executor;
CREATE POLICY gf_owner_select ON private.walkin_requests FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_update ON private.walkin_requests FOR UPDATE TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name) WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_public_select ON private.walkin_requests FOR SELECT TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name);
CREATE POLICY gf_public_insert ON private.walkin_requests FOR INSERT TO gym_public_executor WITH CHECK(CURRENT_USER='gym_public_executor'::name);

-- Existing Owner payment/event policies are already command-scoped. Extend
-- only the columns needed for actual server receipt timestamps and walk-ins.
GRANT INSERT(received_at) ON private.payment_records TO gym_owner_executor;
GRANT INSERT(created_at) ON private.payment_events TO gym_owner_executor;
GRANT INSERT(walkin_request_id) ON private.payment_allocations TO gym_owner_executor;
GRANT SELECT(id,walkin_request_id,checked_in_at),INSERT(walkin_request_id,gym_local_date,checked_in_at,attendance_status)
    ON private.attendance_checkins TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.attendance_checkins FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);

CREATE FUNCTION private.prevent_walkin_history_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
    RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='WALKIN_HISTORY_APPEND_ONLY';
END;
$function$;
ALTER FUNCTION private.prevent_walkin_history_mutation() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.prevent_walkin_history_mutation() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.prevent_walkin_history_mutation() TO gym_owner_executor;
CREATE TRIGGER walkin_fee_versions_immutable BEFORE UPDATE OR DELETE ON private.walkin_fee_versions
FOR EACH ROW EXECUTE FUNCTION private.prevent_walkin_history_mutation();
CREATE TRIGGER walkin_fee_versions_no_truncate BEFORE TRUNCATE ON private.walkin_fee_versions
FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_walkin_history_mutation();
CREATE TRIGGER receipt_review_immutable BEFORE UPDATE OR DELETE ON private.receipt_review
FOR EACH ROW EXECUTE FUNCTION private.prevent_walkin_history_mutation();
CREATE TRIGGER receipt_review_no_truncate BEFORE TRUNCATE ON private.receipt_review
FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_walkin_history_mutation();

CREATE FUNCTION private.guard_walkin_request_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
    IF TG_OP='INSERT' THEN
        IF NEW.request_status<>'pending' OR NEW.confirmed_by IS NOT NULL OR NEW.confirmed_at IS NOT NULL
           OR NEW.requested_payment_method IS NULL OR NEW.expires_at IS DISTINCT FROM NEW.created_at+interval '15 minutes'
           OR NEW.created_at>pg_catalog.clock_timestamp() OR NOT EXISTS(
             SELECT 1 FROM private.walkin_fee_versions f WHERE f.id=NEW.fee_version_id
               AND f.fee_php=NEW.fee_php AND f.currency=NEW.currency AND f.effective_from<=NEW.created_at) THEN
            RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='WALKIN_REQUEST_SNAPSHOT_INVALID';
        END IF;
        RETURN NEW;
    END IF;
    IF ROW(NEW.id,NEW.fee_version_id,NEW.fee_php,NEW.currency,NEW.created_at,NEW.expires_at,NEW.requested_payment_method)
       IS DISTINCT FROM ROW(OLD.id,OLD.fee_version_id,OLD.fee_php,OLD.currency,OLD.created_at,OLD.expires_at,OLD.requested_payment_method) THEN
        RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='WALKIN_REQUEST_SNAPSHOT_IMMUTABLE';
    END IF;
    IF ROW(NEW.request_status,NEW.confirmed_by,NEW.confirmed_at)
       IS NOT DISTINCT FROM ROW(OLD.request_status,OLD.confirmed_by,OLD.confirmed_at) THEN RETURN NEW; END IF;
    IF OLD.request_status<>'pending' THEN
        RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='WALKIN_REQUEST_CANNOT_BE_REVIVED';
    END IF;
    IF NEW.request_status='expired' AND NEW.expires_at<=pg_catalog.clock_timestamp()
       AND NEW.confirmed_by IS NULL AND NEW.confirmed_at IS NULL THEN RETURN NEW; END IF;
    IF NEW.request_status<>'confirmed' OR NEW.confirmed_by IS NULL OR NEW.confirmed_at IS NULL
       OR NEW.requested_payment_method IS NULL OR NEW.confirmed_at<NEW.created_at
       OR NEW.confirmed_at>=NEW.expires_at OR NEW.confirmed_at>pg_catalog.clock_timestamp()
       OR NOT EXISTS(SELECT 1 FROM private.owner_access o WHERE o.user_id=NEW.confirmed_by AND o.is_active)
       OR NOT EXISTS(SELECT 1 FROM private.payment_allocations a JOIN private.payment_records p ON p.id=a.payment_id
            WHERE a.walkin_request_id=NEW.id AND p.verification_status='confirmed' AND p.amount_php=NEW.fee_php
              AND p.payment_method=NEW.requested_payment_method AND p.target_membership_purchase_id IS NULL)
       OR NOT EXISTS(SELECT 1 FROM private.attendance_checkins c WHERE c.walkin_request_id=NEW.id
            AND c.attendance_status='valid' AND c.checked_in_at=NEW.confirmed_at
            AND c.gym_local_date=(NEW.confirmed_at AT TIME ZONE 'Asia/Manila')::date) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='WALKIN_CONFIRMATION_INVALID';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_walkin_request_snapshot() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_walkin_request_snapshot() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION private.guard_walkin_request_snapshot() TO gym_owner_executor,gym_public_executor;
CREATE TRIGGER walkin_request_guard_snapshot BEFORE INSERT OR UPDATE ON private.walkin_requests
FOR EACH ROW EXECUTE FUNCTION private.guard_walkin_request_snapshot();

CREATE FUNCTION private.guard_walkin_allocation()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_request private.walkin_requests%ROWTYPE;
BEGIN
    IF NEW.walkin_request_id IS NULL THEN RETURN NEW; END IF;
    SELECT * INTO v_request FROM private.walkin_requests WHERE id=NEW.walkin_request_id FOR UPDATE;
    IF NOT FOUND OR v_request.request_status<>'pending' OR v_request.expires_at<=pg_catalog.clock_timestamp()
       OR v_request.requested_payment_method IS NULL OR NEW.membership_purchase_id IS NOT NULL
       OR EXISTS(SELECT 1 FROM private.receipt_review q WHERE q.payment_id=NEW.payment_id)
       OR EXISTS(SELECT 1 FROM private.payment_allocations a WHERE a.walkin_request_id=NEW.walkin_request_id)
       OR NOT EXISTS(SELECT 1 FROM private.payment_records p WHERE p.id=NEW.payment_id
           AND p.verification_status='confirmed' AND p.amount_php=v_request.fee_php
           AND p.payment_method=v_request.requested_payment_method AND p.target_membership_purchase_id IS NULL
           AND EXISTS(SELECT 1 FROM private.payment_events e WHERE e.payment_id=p.id AND e.event_type='payment.confirmed')) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='WALKIN_PAYMENT_ALLOCATION_INVALID';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_walkin_allocation() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_walkin_allocation() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_walkin_allocation() TO gym_owner_executor;
CREATE TRIGGER payment_allocations_validate_walkin BEFORE INSERT ON private.payment_allocations
FOR EACH ROW EXECUTE FUNCTION private.guard_walkin_allocation();

CREATE FUNCTION private.guard_paid_walkin_attendance()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
    IF NEW.walkin_request_id IS NULL THEN RETURN NEW; END IF;
    IF NEW.attendance_status<>'valid' OR NEW.member_id IS NOT NULL
       OR NEW.gym_local_date IS DISTINCT FROM (NEW.checked_in_at AT TIME ZONE 'Asia/Manila')::date
       OR NEW.checked_in_at>pg_catalog.clock_timestamp() OR NOT EXISTS(
         SELECT 1 FROM private.walkin_requests r JOIN private.payment_allocations a ON a.walkin_request_id=r.id
         JOIN private.payment_records p ON p.id=a.payment_id
         WHERE r.id=NEW.walkin_request_id AND r.request_status='pending' AND r.requested_payment_method IS NOT NULL
           AND NEW.checked_in_at>=r.created_at AND NEW.checked_in_at<r.expires_at
           AND r.expires_at>pg_catalog.clock_timestamp() AND p.verification_status='confirmed'
           AND p.amount_php=r.fee_php AND p.payment_method=r.requested_payment_method
           AND p.target_membership_purchase_id IS NULL) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='WALKIN_ATTENDANCE_REQUIRES_CONFIRMED_RECEIPT';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_paid_walkin_attendance() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_paid_walkin_attendance() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_paid_walkin_attendance() TO gym_owner_executor;
CREATE TRIGGER attendance_guard_paid_walkin BEFORE INSERT ON private.attendance_checkins
FOR EACH ROW EXECUTE FUNCTION private.guard_paid_walkin_attendance();

CREATE FUNCTION private.guard_walkin_receipt_review()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
BEGIN
    IF NEW.verified_at>pg_catalog.clock_timestamp()
       OR NOT EXISTS(SELECT 1 FROM private.owner_access o WHERE o.user_id=NEW.verified_by AND o.is_active)
       OR NOT EXISTS(SELECT 1 FROM private.payment_records p WHERE p.id=NEW.payment_id
          AND p.verification_status='recorded' AND p.target_membership_purchase_id IS NULL
          AND (p.payment_method='cash' OR NEW.evidence_reviewed))
       OR EXISTS(SELECT 1 FROM private.payment_allocations a WHERE a.payment_id=NEW.payment_id) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='WALKIN_RECEIPT_REVIEW_INVALID';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_walkin_receipt_review() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_walkin_receipt_review() FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_walkin_receipt_review() TO gym_owner_executor;
CREATE TRIGGER receipt_review_guard_insert BEFORE INSERT ON private.receipt_review
FOR EACH ROW EXECUTE FUNCTION private.guard_walkin_receipt_review();

CREATE FUNCTION api.owner_set_walkin_fee(p_actor_user_id uuid,p_fee_php numeric,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid; v_now timestamptz; v_reason text:=pg_catalog.btrim(COALESCE(p_reason,''));
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_fee_php IS NULL OR p_fee_php<=0 OR p_fee_php>9999999999.99 OR p_fee_php<>pg_catalog.round(p_fee_php,2)
       OR pg_catalog.char_length(v_reason)<5 OR pg_catalog.char_length(v_reason)>500 THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_WALKIN_FEE';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-walkin-fee-v1',0));
    v_now:=pg_catalog.clock_timestamp();
    INSERT INTO private.walkin_fee_versions(fee_php,currency,effective_from,created_by,created_at)
    VALUES(p_fee_php,'PHP',v_now,p_actor_user_id,v_now) RETURNING id INTO v_id;
    PERFORM api.append_audit_event('walkin-fees',p_actor_user_id,'walkin.fee_version_created','walkin_fee',v_id::text,
        pg_catalog.jsonb_build_object('reason',v_reason,'fee_php',p_fee_php,'currency','PHP'));
    RETURN pg_catalog.jsonb_build_object('id',v_id,'feePhp',p_fee_php,'currency','PHP','effectiveFrom',v_now);
END;
$function$;
ALTER FUNCTION api.owner_set_walkin_fee(uuid,numeric,text) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_set_walkin_fee(uuid,numeric,text) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_set_walkin_fee(uuid,numeric,text) TO service_role;

CREATE FUNCTION api.public_create_walkin_request(p_payment_method text,p_request_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid; v_now timestamptz; v_count bigint; v_fee_id uuid; v_fee numeric(12,2); v_currency text;
BEGIN
    IF p_payment_method IS NULL OR p_payment_method NOT IN('cash','gcash','bank_transfer')
       OR p_request_limit IS NULL OR p_request_limit<1 OR p_request_limit>100 THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_WALKIN_REQUEST';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-walkin-request-rate-v1',0));
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-walkin-fee-v1',0));
    v_now:=pg_catalog.clock_timestamp();
    DELETE FROM private.walkin_request_rate_events WHERE requested_at<=v_now-interval '60 seconds';
    SELECT count(*) INTO v_count FROM private.walkin_request_rate_events WHERE requested_at>v_now-interval '60 seconds';
    IF v_count>=p_request_limit THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='WALKIN_RATE_LIMITED'; END IF;
    SELECT f.id,f.fee_php,f.currency INTO v_fee_id,v_fee,v_currency FROM private.walkin_fee_versions f
    WHERE f.effective_from<=v_now ORDER BY f.effective_from DESC,f.created_at DESC,f.id DESC LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='WALKIN_FEE_UNAVAILABLE'; END IF;
    INSERT INTO private.walkin_request_rate_events(requested_at) VALUES(v_now);
    INSERT INTO private.walkin_requests(fee_version_id,fee_php,currency,request_status,created_at,expires_at,requested_payment_method)
    VALUES(v_fee_id,v_fee,v_currency,'pending',v_now,v_now+interval '15 minutes',p_payment_method) RETURNING id INTO v_id;
    RETURN pg_catalog.jsonb_build_object('id',v_id,'feePhp',v_fee,'currency',v_currency,'paymentMethod',p_payment_method,
        'createdAt',v_now,'expiresAt',v_now+interval '15 minutes');
END;
$function$;
ALTER FUNCTION api.public_create_walkin_request(text,integer) OWNER TO gym_public_executor;
REVOKE ALL ON FUNCTION api.public_create_walkin_request(text,integer) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor;
GRANT EXECUTE ON FUNCTION api.public_create_walkin_request(text,integer) TO service_role;

CREATE FUNCTION api.owner_list_walkin_requests(p_actor_user_id uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_result jsonb; v_now timestamptz:=pg_catalog.clock_timestamp();
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_limit IS NULL OR p_limit<1 OR p_limit>100 OR p_offset IS NULL OR p_offset<0 OR p_offset>100000 THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_WALKIN_PAGINATION';
    END IF;
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',r.id,'feePhp',r.fee_php,'currency',r.currency,
        'paymentMethod',r.requested_payment_method,'createdAt',r.created_at,'expiresAt',r.expires_at,
        'status',CASE WHEN r.request_status='pending' AND r.expires_at<=v_now THEN 'expired' ELSE r.request_status END,
        'confirmedAt',r.confirmed_at) ORDER BY r.created_at DESC,r.id DESC),'[]'::jsonb)
    INTO v_result FROM(SELECT id,fee_php,currency,requested_payment_method,created_at,expires_at,request_status,confirmed_at
        FROM private.walkin_requests ORDER BY created_at DESC,id DESC LIMIT p_limit OFFSET p_offset) r;
    RETURN v_result;
END;
$function$;
ALTER FUNCTION api.owner_list_walkin_requests(uuid,integer,integer) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_list_walkin_requests(uuid,integer,integer) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_walkin_requests(uuid,integer,integer) TO service_role;

CREATE FUNCTION api.owner_confirm_walkin(p_actor_user_id uuid,p_request_id uuid,p_operation_id uuid,
    p_amount_php numeric,p_payment_method text,p_evidence_reviewed boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
    v_request private.walkin_requests%ROWTYPE; v_existing private.payment_records%ROWTYPE;
    v_payment uuid; v_attendance uuid; v_existing_request uuid; v_existing_evidence boolean;
    v_now timestamptz; v_review_reason text; v_outcome text;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_request_id IS NULL OR p_operation_id IS NULL OR p_amount_php IS NULL OR p_amount_php<=0
       OR p_amount_php>9999999999.99 OR p_amount_php<>pg_catalog.round(p_amount_php,2)
       OR p_payment_method IS NULL OR p_payment_method NOT IN('cash','gcash','bank_transfer')
       OR p_evidence_reviewed IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_WALKIN_CONFIRMATION';
    END IF;
    IF p_payment_method<>'cash' AND NOT p_evidence_reviewed THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='PAYMENT_EVIDENCE_REQUIRED';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('walkin-confirm:'||p_operation_id::text,0));
    SELECT * INTO v_existing FROM private.payment_records WHERE operation_id=p_operation_id FOR UPDATE;
    IF FOUND THEN
        SELECT a.walkin_request_id INTO v_existing_request FROM private.payment_allocations a WHERE a.payment_id=v_existing.id;
        IF v_existing_request IS NOT NULL THEN
            v_outcome:='confirmed';
            SELECT id INTO v_attendance FROM private.attendance_checkins WHERE walkin_request_id=v_existing_request;
        ELSE
            SELECT q.walkin_request_id INTO v_existing_request FROM private.receipt_review q WHERE q.payment_id=v_existing.id;
            v_outcome:='receipt_review';
        END IF;
        SELECT (e.details->>'evidence_reviewed')::boolean INTO v_existing_evidence FROM private.audit_events e
        WHERE e.subject_type='payment' AND e.subject_id=v_existing.id::text AND e.event_type='walkin.receipt_verified'
        ORDER BY e.id DESC LIMIT 1;
        IF v_existing_request IS DISTINCT FROM p_request_id OR v_existing.target_membership_purchase_id IS NOT NULL
           OR v_existing.amount_php IS DISTINCT FROM p_amount_php OR v_existing.payment_method IS DISTINCT FROM p_payment_method
           OR v_existing.recorded_by IS DISTINCT FROM p_actor_user_id OR v_existing_evidence IS DISTINCT FROM p_evidence_reviewed
           OR (v_outcome='confirmed' AND v_attendance IS NULL) THEN
            RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='WALKIN_OPERATION_CONFLICT';
        END IF;
        RETURN pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object('requestId',p_request_id,'paymentId',v_existing.id,
            'outcome',v_outcome,'attendanceId',v_attendance,'replayed',true));
    END IF;
    SELECT * INTO v_request FROM private.walkin_requests WHERE id=p_request_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='WALKIN_REQUEST_NOT_FOUND'; END IF;
    v_now:=pg_catalog.clock_timestamp();
    IF v_request.request_status='pending' AND v_request.expires_at<=v_now THEN
        UPDATE private.walkin_requests SET request_status='expired' WHERE id=v_request.id RETURNING * INTO v_request;
    END IF;
    v_review_reason:=CASE
        WHEN v_request.request_status='expired' OR v_request.expires_at<=v_now THEN 'request_expired'
        WHEN v_request.request_status<>'pending' THEN 'request_not_pending'
        WHEN v_request.requested_payment_method IS NULL THEN 'legacy_request_missing_payment_method'
        WHEN p_amount_php<>v_request.fee_php THEN 'amount_mismatch'
        WHEN p_payment_method<>v_request.requested_payment_method THEN 'payment_method_mismatch'
        ELSE NULL END;
    INSERT INTO private.payment_records(amount_php,payment_method,received_at,verification_status,recorded_by,operation_id)
    VALUES(p_amount_php,p_payment_method,v_now,'recorded',p_actor_user_id,p_operation_id) RETURNING id INTO v_payment;
    IF v_review_reason IS NOT NULL THEN
        INSERT INTO private.receipt_review(payment_id,walkin_request_id,verified_by,verified_at,reason,evidence_reviewed)
        VALUES(v_payment,v_request.id,p_actor_user_id,v_now,v_review_reason,p_evidence_reviewed);
        INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id,created_at)
        VALUES(v_payment,'walkin.receipt_review_required',v_review_reason,p_actor_user_id,v_now);
        v_outcome:='receipt_review';
    ELSE
        UPDATE private.payment_records SET verification_status='confirmed' WHERE id=v_payment;
        INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id,created_at)
        VALUES(v_payment,'payment.confirmed','Owner confirmed actual walk-in receipt.',p_actor_user_id,v_now);
        INSERT INTO private.payment_allocations(payment_id,walkin_request_id,allocated_by)
        VALUES(v_payment,v_request.id,p_actor_user_id);
        INSERT INTO private.attendance_checkins(walkin_request_id,gym_local_date,checked_in_at,attendance_status)
        VALUES(v_request.id,(v_now AT TIME ZONE 'Asia/Manila')::date,v_now,'valid') RETURNING id INTO v_attendance;
        UPDATE private.walkin_requests SET request_status='confirmed',confirmed_by=p_actor_user_id,confirmed_at=v_now WHERE id=v_request.id;
        v_outcome:='confirmed';
    END IF;
    PERFORM api.append_audit_event('walkins',p_actor_user_id,'walkin.receipt_verified','payment',v_payment::text,
        pg_catalog.jsonb_build_object('reason',COALESCE(v_review_reason,'Owner confirmed full actual receipt and physical attendance.'),
            'request_id',v_request.id,'outcome',v_outcome,'attendance_id',v_attendance,'evidence_reviewed',p_evidence_reviewed));
    RETURN pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object('requestId',v_request.id,'paymentId',v_payment,
        'outcome',v_outcome,'attendanceId',v_attendance,'replayed',false));
END;
$function$;
ALTER FUNCTION api.owner_confirm_walkin(uuid,uuid,uuid,numeric,text,boolean) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_confirm_walkin(uuid,uuid,uuid,numeric,text,boolean) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_confirm_walkin(uuid,uuid,uuid,numeric,text,boolean) TO service_role;

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
