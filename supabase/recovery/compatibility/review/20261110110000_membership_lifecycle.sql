-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=supabase_admin; source SHA-256=f8204849462b8a173f0ccceea4383368ed7baa731e98335591b950f26543f966
-- Source implementation only; production execution requires Owner-controlled
-- release/recovery approval. Apply executor hardening first. No client dates,
-- expiry overrides, suspension, cancellation, freeze or automatic renewal.
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
 FOR r IN SELECT n.nspname,c.relname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p') AND c.relforcerowsecurity AND n.nspname='private' AND c.relname IN ('members','membership_purchases','payment_records','payment_allocations','payment_events') LOOP
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND p.polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected maintenance policy'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND NOT p.polpermissive)
 THEN RAISE EXCEPTION 'Unreviewed restrictive policy prevents full-visibility proof'; END IF;
 EXECUTE pg_catalog.format('CREATE POLICY gf_compatibility_read ON %I.%I FOR SELECT TO postgres USING (CURRENT_USER = ''postgres''::name AND SESSION_USER = ''postgres''::name)',r.nspname,r.relname);
 END LOOP;
 END $compatibility_prepare$;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
SET LOCAL search_path = pg_catalog;
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-membership-lifecycle-v1', 0));
LOCK TABLE private.members, private.membership_purchases, private.payment_records,
    private.payment_allocations, private.payment_events IN ACCESS EXCLUSIVE MODE;

DO $lifecycle_preconditions$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname IN
        ('gym_data_owner','gym_owner_executor','gym_public_executor')
        AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit
             OR rolreplication OR rolbypassrls))
       OR (SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN
        ('gym_data_owner','gym_owner_executor','gym_public_executor')) <> 3
       OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members a JOIN pg_catalog.pg_roles r
          ON r.oid=a.roleid OR r.oid=a.member WHERE r.rolname IN
          ('gym_data_owner','gym_owner_executor','gym_public_executor') AND NOT (a.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND a.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((a.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='supabase_admin')
 AND a.admin_option AND NOT a.inherit_option AND NOT a.set_option)
 OR (a.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND NOT a.admin_option AND a.inherit_option AND a.set_option)))) THEN
        RAISE EXCEPTION 'Restricted executor foundation is required';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind='r' AND
          (NOT c.relrowsecurity OR NOT c.relforcerowsecurity OR c.relowner <>
           (SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_data_owner'))) THEN
        RAISE EXCEPTION 'Hardened ownership and FORCE RLS are required';
    END IF;
    -- Do not infer approval or repair historical dates/payment facts during DDL.
    IF EXISTS (SELECT 1 FROM private.members WHERE
        (status='active' AND approved_at IS NULL) OR
        (status='pending' AND approved_at IS NOT NULL) OR
        approved_at > pg_catalog.clock_timestamp()) THEN
        RAISE EXCEPTION 'Legacy registration state requires documented Owner review';
    END IF;
    IF EXISTS (SELECT 1 FROM private.membership_purchases p
        LEFT JOIN private.members m ON m.id=p.member_id
        WHERE ((p.purchase_status IN ('active','expired')) IS DISTINCT FROM
               (p.activation_date IS NOT NULL AND p.expiry_date IS NOT NULL))
          OR (p.activation_date IS NOT NULL AND
              p.expiry_date <> (p.activation_date::timestamp + interval '1 month')::date - 1)
          OR (p.purchase_status IN ('pending_activation','active','expired') AND
              (m.approved_at IS NULL OR NOT EXISTS (
                SELECT 1 FROM private.payment_allocations a
                JOIN private.payment_records r ON r.id=a.payment_id
                JOIN private.payment_events e ON e.payment_id=r.id AND e.event_type='payment.confirmed'
                WHERE a.membership_purchase_id=p.id
                  AND r.target_membership_purchase_id=p.id
                  AND r.verification_status='confirmed' AND r.amount_php=p.price_php)))) THEN
        RAISE EXCEPTION 'Legacy membership/payment state requires documented Owner review';
    END IF;
END;
$lifecycle_preconditions$;

-- now() is the transaction start, which may precede a row-lock wait across
-- Manila midnight. New confirmation events use their actual server creation
-- instant. Existing receipt/event timestamps and function bodies are preserved.
ALTER TABLE private.payment_events ALTER COLUMN created_at SET DEFAULT pg_catalog.clock_timestamp();

-- PostgreSQL month addition clamps the day before inclusive expiry subtracts one.
CREATE FUNCTION private.membership_inclusive_expiry(p_activation_date date)
RETURNS date LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path = ''
AS $function$
    SELECT (p_activation_date::timestamp + interval '1 month')::date - 1;
$function$;
ALTER FUNCTION private.membership_inclusive_expiry(date) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.membership_inclusive_expiry(date) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.membership_inclusive_expiry(date) TO gym_owner_executor;

-- This read helper verifies a whole allocated receipt and the server's actual
-- confirmation event. received_at, allocation time and browser clocks cannot
-- substitute for confirmation. Original receipt/event records remain unchanged.
CREATE FUNCTION private.membership_payment_confirmed_at(p_purchase_id uuid)
RETURNS timestamptz LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$
    SELECT pg_catalog.max(e.created_at)
    FROM private.membership_purchases p
    JOIN private.payment_allocations a ON a.membership_purchase_id=p.id
    JOIN private.payment_records r ON r.id=a.payment_id
    JOIN private.payment_events e ON e.payment_id=r.id AND e.event_type='payment.confirmed'
    WHERE p.id=p_purchase_id AND r.target_membership_purchase_id=p.id
      AND r.verification_status='confirmed' AND r.amount_php=p.price_php;
$function$;
ALTER FUNCTION private.membership_payment_confirmed_at(uuid) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.membership_payment_confirmed_at(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.membership_payment_confirmed_at(uuid) TO gym_owner_executor;

-- Called only by the bounded Owner executor. Lock the member before any term
-- decision: two purchases for that member cannot both extend the same expiry.
CREATE FUNCTION private.membership_activation_dates(p_member_id uuid, p_purchase_id uuid)
RETURNS TABLE(activation_date date, expiry_date date)
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
    v_member private.members%ROWTYPE;
    v_paid_at timestamptz;
    v_now timestamptz;
    v_today date;
    v_eligible date;
    v_current_expiry date;
    v_activation date;
    v_expiry date;
BEGIN
    SELECT * INTO v_member FROM private.members WHERE id=p_member_id FOR UPDATE;
    IF NOT FOUND OR v_member.status<>'active' OR v_member.approved_at IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBER_APPROVAL_REQUIRED';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.membership_purchases
        WHERE id=p_purchase_id AND member_id=p_member_id) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBERSHIP_PURCHASE_MEMBER_MISMATCH';
    END IF;
    v_paid_at := private.membership_payment_confirmed_at(p_purchase_id);
    v_now := pg_catalog.clock_timestamp();
    IF v_paid_at IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='PURCHASE_REQUIRES_CONFIRMED_FULL_PAYMENT';
    END IF;
    IF v_paid_at>v_now OR v_member.approved_at>v_now THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBERSHIP_SERVER_DATE_REVIEW_REQUIRED';
    END IF;
    v_today := (v_now AT TIME ZONE 'Asia/Manila')::date;
    v_eligible := GREATEST((v_paid_at AT TIME ZONE 'Asia/Manila')::date,
                         (v_member.approved_at AT TIME ZONE 'Asia/Manila')::date);
    IF EXISTS (SELECT 1 FROM private.membership_purchases p WHERE p.member_id=p_member_id
        AND p.id<>p_purchase_id AND p.activation_date>v_today) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='FUTURE_MEMBERSHIP_TERM_ALREADY_EXISTS';
    END IF;
    SELECT pg_catalog.max(p.expiry_date) INTO v_current_expiry
    FROM private.membership_purchases p WHERE p.member_id=p_member_id AND p.id<>p_purchase_id
      AND p.activation_date<=v_eligible AND p.expiry_date>=v_eligible;
    v_activation := CASE WHEN v_current_expiry IS NOT NULL THEN v_current_expiry+1 ELSE v_eligible END;
    v_expiry := private.membership_inclusive_expiry(v_activation);
    IF EXISTS (SELECT 1 FROM private.membership_purchases p WHERE p.member_id=p_member_id
        AND p.id<>p_purchase_id AND p.activation_date IS NOT NULL
        AND pg_catalog.daterange(p.activation_date,p.expiry_date,'[]') &&
            pg_catalog.daterange(v_activation,v_expiry,'[]')) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBERSHIP_TERM_OVERLAP_REVIEW_REQUIRED';
    END IF;
    activation_date := v_activation;
    expiry_date := v_expiry;
    RETURN NEXT;
END;
$function$;
ALTER FUNCTION private.membership_activation_dates(uuid,uuid) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.membership_activation_dates(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.membership_activation_dates(uuid,uuid) TO gym_owner_executor;

CREATE FUNCTION private.guard_member_registration_approval()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $function$
BEGIN
    IF TG_OP='INSERT' THEN
        IF NEW.status<>'pending' OR NEW.approved_at IS NOT NULL THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='REGISTRATION_REQUIRES_OWNER_APPROVAL';
        END IF;
    ELSIF ROW(NEW.status,NEW.approved_at) IS DISTINCT FROM ROW(OLD.status,OLD.approved_at) THEN
        IF OLD.status<>'pending' OR OLD.approved_at IS NOT NULL OR NEW.status<>'active'
           OR NEW.approved_at IS NULL OR NEW.approved_at>pg_catalog.clock_timestamp()
           OR CURRENT_USER<>'gym_owner_executor' THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='REGISTRATION_APPROVAL_TRANSITION_INVALID';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_member_registration_approval() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_member_registration_approval() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.guard_member_registration_approval() TO gym_owner_executor, gym_public_executor;
CREATE TRIGGER members_guard_registration_approval BEFORE INSERT OR UPDATE ON private.members
FOR EACH ROW EXECUTE FUNCTION private.guard_member_registration_approval();

CREATE FUNCTION private.guard_membership_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE v_dates record;
BEGIN
    IF TG_OP='INSERT' THEN
        IF NEW.purchase_status<>'pending_payment' OR NEW.activation_date IS NOT NULL OR NEW.expiry_date IS NOT NULL THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='MEMBERSHIP_PURCHASE_MUST_START_PENDING';
        END IF;
        RETURN NEW;
    END IF;
    IF ROW(NEW.id,NEW.member_id,NEW.plan_id,NEW.price_php,NEW.created_at)
        IS DISTINCT FROM ROW(OLD.id,OLD.member_id,OLD.plan_id,OLD.price_php,OLD.created_at) THEN
        RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='MEMBERSHIP_PURCHASE_FACTS_IMMUTABLE';
    END IF;
    IF OLD.activation_date IS NOT NULL OR OLD.expiry_date IS NOT NULL THEN
        IF ROW(NEW.purchase_status,NEW.activation_date,NEW.expiry_date)
            IS DISTINCT FROM ROW(OLD.purchase_status,OLD.activation_date,OLD.expiry_date) THEN
            RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='MEMBERSHIP_TERM_IMMUTABLE';
        END IF;
        RETURN NEW;
    END IF;
    IF OLD.purchase_status='pending_activation' AND NEW.purchase_status='active' THEN
        SELECT * INTO v_dates FROM private.membership_activation_dates(NEW.member_id,NEW.id);
        IF NEW.activation_date IS DISTINCT FROM v_dates.activation_date
           OR NEW.expiry_date IS DISTINCT FROM v_dates.expiry_date THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='MEMBERSHIP_DATES_MUST_MATCH_SERVER_BASIS';
        END IF;
    ELSIF NEW.activation_date IS NOT NULL OR NEW.expiry_date IS NOT NULL
       OR (NEW.purchase_status IS DISTINCT FROM OLD.purchase_status AND NOT
           (OLD.purchase_status='pending_payment' AND NEW.purchase_status='pending_activation')) THEN
        RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='MEMBERSHIP_LIFECYCLE_TRANSITION_INVALID';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_membership_lifecycle() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_membership_lifecycle() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.guard_membership_lifecycle() TO gym_owner_executor;
CREATE TRIGGER membership_purchase_guard_lifecycle BEFORE INSERT OR UPDATE ON private.membership_purchases
FOR EACH ROW EXECUTE FUNCTION private.guard_membership_lifecycle();

-- Existing role/command-scoped UPDATE policies already cover these tables.
-- Add only columns needed by the two new guarded transitions, no table grants.
GRANT UPDATE(status,approved_at) ON private.members TO gym_owner_executor;
GRANT UPDATE(activation_date,expiry_date) ON private.membership_purchases TO gym_owner_executor;

CREATE FUNCTION api.owner_approve_member(p_actor_user_id uuid, p_member_id uuid, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_member private.members%ROWTYPE; v_reason text:=pg_catalog.btrim(COALESCE(p_reason,''));
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM private.owner_access
        WHERE user_id=p_actor_user_id AND is_active=true) THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_member_id IS NULL OR pg_catalog.char_length(v_reason)<5 OR pg_catalog.char_length(v_reason)>500 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='INVALID_REGISTRATION_APPROVAL';
    END IF;
    SELECT * INTO v_member FROM private.members WHERE id=p_member_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='MEMBER_NOT_FOUND'; END IF;
    IF v_member.status='active' AND v_member.approved_at IS NOT NULL THEN
        RETURN pg_catalog.jsonb_build_object('id',v_member.id,'memberCode',v_member.member_code,
            'status',v_member.status,'approvedAt',v_member.approved_at,'replayed',true);
    END IF;
    IF v_member.status<>'pending' OR v_member.approved_at IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBER_NOT_PENDING_APPROVAL';
    END IF;
    UPDATE private.members SET status='active',approved_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp()
    WHERE id=v_member.id RETURNING * INTO v_member;
    PERFORM api.append_audit_event('members',p_actor_user_id,'member.registration_approved','member',v_member.id::text,
        pg_catalog.jsonb_build_object('reason',v_reason,'approved_at',v_member.approved_at));
    RETURN pg_catalog.jsonb_build_object('id',v_member.id,'memberCode',v_member.member_code,
        'status',v_member.status,'approvedAt',v_member.approved_at,'replayed',false);
END;
$function$;
ALTER FUNCTION api.owner_approve_member(uuid,uuid,text) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_approve_member(uuid,uuid,text) FROM PUBLIC, anon, authenticated, service_role, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_approve_member(uuid,uuid,text) TO service_role;

CREATE FUNCTION api.owner_activate_membership_purchase(p_actor_user_id uuid, p_membership_purchase_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_purchase private.membership_purchases%ROWTYPE; v_member private.members%ROWTYPE; v_dates record;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM private.owner_access
        WHERE user_id=p_actor_user_id AND is_active=true) THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_membership_purchase_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='INVALID_MEMBERSHIP_ACTIVATION';
    END IF;
    -- Read identity, then acquire the shared member serialization lock BEFORE
    -- locking this purchase. Its member identity is immutable under the guard.
    SELECT * INTO v_purchase FROM private.membership_purchases WHERE id=p_membership_purchase_id;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='MEMBERSHIP_PURCHASE_NOT_FOUND'; END IF;
    SELECT * INTO v_member FROM private.members WHERE id=v_purchase.member_id FOR UPDATE;
    IF v_member.status<>'active' OR v_member.approved_at IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='MEMBER_APPROVAL_REQUIRED';
    END IF;
    SELECT * INTO v_purchase FROM private.membership_purchases WHERE id=p_membership_purchase_id FOR UPDATE;
    IF v_purchase.purchase_status IN ('active','expired') AND v_purchase.activation_date IS NOT NULL THEN
        IF private.membership_payment_confirmed_at(v_purchase.id) IS NULL THEN
            RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='PURCHASE_REQUIRES_CONFIRMED_FULL_PAYMENT';
        END IF;
        RETURN pg_catalog.jsonb_build_object('id',v_purchase.id,'memberId',v_purchase.member_id,
            'purchaseStatus',v_purchase.purchase_status,'activationDate',v_purchase.activation_date,
            'expiryDate',v_purchase.expiry_date,'replayed',true);
    END IF;
    IF v_purchase.purchase_status<>'pending_activation' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='PURCHASE_NOT_READY_FOR_ACTIVATION';
    END IF;
    SELECT * INTO v_dates FROM private.membership_activation_dates(v_purchase.member_id,v_purchase.id);
    UPDATE private.membership_purchases SET purchase_status='active',activation_date=v_dates.activation_date,expiry_date=v_dates.expiry_date
    WHERE id=v_purchase.id RETURNING * INTO v_purchase;
    PERFORM api.append_audit_event('membership_purchases',p_actor_user_id,'membership_purchase.activated',
        'membership_purchase',v_purchase.id::text,pg_catalog.jsonb_build_object(
            'reason','Owner finalized approved registration and full confirmed payment.',
            'member_id',v_purchase.member_id,'activation_date',v_purchase.activation_date,'expiry_date',v_purchase.expiry_date));
    RETURN pg_catalog.jsonb_build_object('id',v_purchase.id,'memberId',v_purchase.member_id,
        'purchaseStatus',v_purchase.purchase_status,'activationDate',v_purchase.activation_date,
        'expiryDate',v_purchase.expiry_date,'replayed',false);
END;
$function$;
ALTER FUNCTION api.owner_activate_membership_purchase(uuid,uuid) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_activate_membership_purchase(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_activate_membership_purchase(uuid,uuid) TO service_role;

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
