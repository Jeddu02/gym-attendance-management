-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=supabase_admin; source SHA-256=6a052a9127e3c5ed571ffefe585a4969fefe616e302472f9ebf6bdd0d403463b
-- Explicit whole-receipt allocation: original receipt targets/facts stay intact.
-- An append-only review binds verified unmatched money to one current purchase
-- or unexpired walk-in request. No combining receipts, change, refund or credit.
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
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
CREATE TABLE private.receipt_allocation_reviews(
 payment_id uuid PRIMARY KEY REFERENCES private.payment_records(id) ON DELETE RESTRICT,
 membership_purchase_id uuid REFERENCES private.membership_purchases(id) ON DELETE RESTRICT,
 walkin_request_id uuid REFERENCES private.walkin_requests(id) ON DELETE RESTRICT,
 reviewed_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 500),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 300),
 CHECK((membership_purchase_id IS NOT NULL)<>(walkin_request_id IS NOT NULL))
);
ALTER TABLE private.receipt_allocation_reviews OWNER TO gym_data_owner;
ALTER TABLE private.receipt_allocation_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.receipt_allocation_reviews FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.receipt_allocation_reviews FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
GRANT SELECT(payment_id,membership_purchase_id,walkin_request_id,reviewed_by,reviewed_at,reason,evidence_reference),
 INSERT(payment_id,membership_purchase_id,walkin_request_id,reviewed_by,reason,evidence_reference)
 ON private.receipt_allocation_reviews TO gym_owner_executor;
GRANT SELECT(payment_id,membership_purchase_id) ON private.receipt_allocation_reviews TO gym_checkin_executor;
CREATE POLICY gf_owner_select ON private.receipt_allocation_reviews FOR SELECT TO gym_owner_executor USING(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_owner_insert ON private.receipt_allocation_reviews FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER='gym_owner_executor'::name);
CREATE POLICY gf_checkin_select ON private.receipt_allocation_reviews FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON private.receipt_allocation_reviews FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.receipt_allocation_reviews FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE FUNCTION private.receipt_membership_target_matches(p_payment_id uuid,p_purchase_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $function$
 SELECT EXISTS(SELECT 1 FROM private.payment_records p WHERE p.id=p_payment_id AND
  (p.target_membership_purchase_id=p_purchase_id OR (p.target_membership_purchase_id IS NULL AND
   EXISTS(SELECT 1 FROM private.receipt_allocation_reviews r WHERE r.payment_id=p.id AND r.membership_purchase_id=p_purchase_id))));
$function$;
ALTER FUNCTION private.receipt_membership_target_matches(uuid,uuid) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.receipt_membership_target_matches(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.receipt_membership_target_matches(uuid,uuid) TO gym_owner_executor,gym_checkin_executor;

CREATE FUNCTION api.owner_allocate_verified_receipt(p_actor_user_id uuid,p_payment_id uuid,p_membership_purchase_id uuid,p_walkin_request_id uuid,
 p_reason text,p_evidence_reference text,p_confirm_current_presence boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE receipt private.payment_records%ROWTYPE; purchase private.membership_purchases%ROWTYPE;
 request private.walkin_requests%ROWTYPE; prior private.receipt_allocation_reviews%ROWTYPE;
 member uuid; at_time timestamptz; attendance uuid;
BEGIN
 PERFORM private.assert_receipt_review_owner(p_actor_user_id,p_reason,p_evidence_reference);
 IF p_payment_id IS NULL OR ((p_membership_purchase_id IS NULL)=(p_walkin_request_id IS NULL))
 OR p_confirm_current_presence IS NULL OR (p_walkin_request_id IS NOT NULL AND NOT p_confirm_current_presence)
 OR (p_membership_purchase_id IS NOT NULL AND p_confirm_current_presence)
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_ALLOCATION_REVIEW'; END IF;
 -- Serialize this decision by receipt, then use the same subject row locks as
 -- attendance/void operations. Immutable receipt facts are read only.
 PERFORM pg_advisory_xact_lock(hashtextextended('receipt-allocation-review:'||p_payment_id::text,0));
 SELECT * INTO prior FROM private.receipt_allocation_reviews WHERE payment_id=p_payment_id;
 IF FOUND THEN
  IF prior.membership_purchase_id IS DISTINCT FROM p_membership_purchase_id OR prior.walkin_request_id IS DISTINCT FROM p_walkin_request_id
   OR prior.reviewed_by<>p_actor_user_id OR prior.reason<>btrim(p_reason) OR prior.evidence_reference<>btrim(p_evidence_reference)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='RECEIPT_ALLOCATION_ALREADY_REVIEWED'; END IF;
  RETURN jsonb_build_object('paymentId',p_payment_id,'replayed',true,'confirmationVoided',EXISTS(SELECT 1 FROM private.payment_confirmation_voids WHERE payment_id=p_payment_id));
 END IF;
 IF p_membership_purchase_id IS NOT NULL THEN
  SELECT member_id INTO member FROM private.membership_purchases WHERE id=p_membership_purchase_id;
  PERFORM id FROM private.members WHERE id=member FOR UPDATE;
  SELECT * INTO purchase FROM private.membership_purchases WHERE id=p_membership_purchase_id FOR UPDATE;
  IF NOT FOUND OR purchase.purchase_status<>'pending_payment' OR purchase.activation_date IS NOT NULL
   OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE membership_purchase_id=purchase.id)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='PURCHASE_ALLOCATION_REVIEW_REQUIRED'; END IF;
 ELSE
  SELECT * INTO request FROM private.walkin_requests WHERE id=p_walkin_request_id FOR UPDATE;
  IF NOT FOUND OR request.request_status<>'pending' OR request.requested_payment_method IS NULL
   OR request.expires_at<=clock_timestamp() OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE walkin_request_id=request.id)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='WALKIN_ALLOCATION_REVIEW_REQUIRED'; END IF;
 END IF;
 SELECT * INTO receipt FROM private.payment_records WHERE id=p_payment_id FOR UPDATE;
 IF NOT FOUND OR receipt.verification_status<>'recorded' OR NOT private.is_receipt_verified(p_payment_id)
  OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=p_payment_id)
  OR EXISTS(SELECT 1 FROM private.payment_confirmation_voids WHERE payment_id=p_payment_id)
  OR (receipt.target_membership_purchase_id IS NOT NULL AND receipt.target_membership_purchase_id IS DISTINCT FROM p_membership_purchase_id)
  OR (p_membership_purchase_id IS NOT NULL AND receipt.amount_php<>purchase.price_php)
  OR (p_walkin_request_id IS NOT NULL AND (receipt.amount_php<>request.fee_php OR receipt.payment_method<>request.requested_payment_method))
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='VERIFIED_EXACT_UNALLOCATED_RECEIPT_REQUIRED'; END IF;
 INSERT INTO private.receipt_allocation_reviews(payment_id,membership_purchase_id,walkin_request_id,reviewed_by,reason,evidence_reference)
 VALUES(receipt.id,p_membership_purchase_id,p_walkin_request_id,p_actor_user_id,btrim(p_reason),btrim(p_evidence_reference));
 UPDATE private.payment_records SET verification_status='confirmed' WHERE id=receipt.id;
 INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id)
 VALUES(receipt.id,'payment.confirmed',btrim(p_reason),p_actor_user_id);
 INSERT INTO private.payment_allocations(payment_id,membership_purchase_id,walkin_request_id,allocated_by)
 VALUES(receipt.id,p_membership_purchase_id,p_walkin_request_id,p_actor_user_id);
 IF p_membership_purchase_id IS NOT NULL THEN
  UPDATE private.membership_purchases SET purchase_status='pending_activation' WHERE id=purchase.id;
 ELSE
  at_time:=clock_timestamp();
  IF request.expires_at<=at_time THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='WALKIN_ALLOCATION_REVIEW_REQUIRED'; END IF;
  INSERT INTO private.attendance_checkins(walkin_request_id,gym_local_date,checked_in_at,attendance_status)
  VALUES(request.id,(at_time AT TIME ZONE 'Asia/Manila')::date,at_time,'valid') RETURNING id INTO attendance;
  UPDATE private.walkin_requests SET request_status='confirmed',confirmed_by=p_actor_user_id,confirmed_at=at_time WHERE id=request.id;
 END IF;
 PERFORM api.append_audit_event('payments',p_actor_user_id,'receipt.allocation_reviewed','payment',receipt.id::text,
 jsonb_build_object('reason',btrim(p_reason),'evidence_reference',btrim(p_evidence_reference),'membership_purchase_id',p_membership_purchase_id,'walkin_request_id',p_walkin_request_id,'attendance_id',attendance));
 RETURN jsonb_build_object('paymentId',receipt.id,'purchaseId',p_membership_purchase_id,'walkinRequestId',p_walkin_request_id,'attendanceId',attendance,'replayed',false,'confirmationVoided',false);
END $function$;
ALTER FUNCTION api.owner_allocate_verified_receipt(uuid,uuid,uuid,uuid,text,text,boolean) OWNER TO gym_owner_executor;
REVOKE ALL ON FUNCTION api.owner_allocate_verified_receipt(uuid,uuid,uuid,uuid,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION api.owner_allocate_verified_receipt(uuid,uuid,uuid,uuid,text,text,boolean) TO service_role;

-- Explicit reviewed target recognition is extended below without changing any
-- original receipt facts, allocation, attendance or payment event.

CREATE OR REPLACE FUNCTION private.guard_membership_payment_allocation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
    v_payment private.payment_records%ROWTYPE;
    v_purchase private.membership_purchases%ROWTYPE;
BEGIN
    IF NEW.membership_purchase_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_payment
    FROM private.payment_records
    WHERE id = NEW.payment_id
    FOR KEY SHARE;

    SELECT * INTO v_purchase
    FROM private.membership_purchases
    WHERE id = NEW.membership_purchase_id
    FOR KEY SHARE;

    IF NOT FOUND
       OR NOT private.receipt_membership_target_matches(v_payment.id,v_purchase.id)
       OR v_payment.verification_status <> 'confirmed'
       OR v_payment.amount_php <> v_purchase.price_php THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'MEMBERSHIP_PAYMENT_ALLOCATION_INVALID';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.guard_purchase_pending_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
    v_entering_pending_activation boolean;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_entering_pending_activation := NEW.purchase_status = 'pending_activation';
    ELSE
        v_entering_pending_activation := NEW.purchase_status = 'pending_activation'
            AND OLD.purchase_status IS DISTINCT FROM NEW.purchase_status;
    END IF;

    IF v_entering_pending_activation AND NOT EXISTS (
           SELECT 1
           FROM private.payment_allocations allocation
           JOIN private.payment_records payment
             ON payment.id = allocation.payment_id
           WHERE allocation.membership_purchase_id = NEW.id
             AND private.receipt_membership_target_matches(payment.id,NEW.id)
             AND payment.verification_status = 'confirmed'
             AND payment.amount_php = NEW.price_php
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'PURCHASE_REQUIRES_CONFIRMED_FULL_PAYMENT';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.membership_payment_confirmed_at(p_purchase_id uuid)
RETURNS timestamptz LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$
    SELECT pg_catalog.max(e.created_at)
    FROM private.membership_purchases p
    JOIN private.payment_allocations a ON a.membership_purchase_id=p.id
    JOIN private.payment_records r ON r.id=a.payment_id
    JOIN private.payment_events e ON e.payment_id=r.id AND e.event_type='payment.confirmed'
    WHERE p.id=p_purchase_id AND private.receipt_membership_target_matches(r.id,p.id)
      AND r.verification_status='confirmed' AND r.amount_php=p.price_php;
$function$;

CREATE OR REPLACE FUNCTION private.member_checkin_eligible_purchase(p_member_id uuid,p_at timestamptz)
RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $function$
    SELECT p.id FROM private.members m JOIN private.membership_purchases p ON p.member_id=m.id
    WHERE m.id=p_member_id AND m.status='active' AND m.approved_at IS NOT NULL AND m.approved_at<=p_at
      AND p.purchase_status='active' AND p.activation_date<=(p_at AT TIME ZONE 'Asia/Manila')::date
      AND p.expiry_date>=(p_at AT TIME ZONE 'Asia/Manila')::date
      AND EXISTS(SELECT 1 FROM private.payment_allocations a JOIN private.payment_records r ON r.id=a.payment_id
          WHERE a.membership_purchase_id=p.id AND private.receipt_membership_target_matches(r.id,p.id)
            AND r.verification_status='confirmed' AND r.amount_php=p.price_php
            AND EXISTS(SELECT 1 FROM private.payment_events e WHERE e.payment_id=r.id
                AND e.event_type='payment.confirmed' AND e.created_at<=p_at))
    ORDER BY p.activation_date DESC,p.id LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION api.owner_dashboard_summary(p_actor_user_id uuid)
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
                WHERE a.membership_purchase_id=p.id AND private.receipt_membership_target_matches(r.id,p.id)
                  AND r.verification_status='confirmed' AND r.amount_php=p.price_php
                  AND EXISTS (SELECT 1 FROM private.payment_events e WHERE e.payment_id=r.id
                    AND e.event_type='payment.confirmed' AND e.created_at<=pg_catalog.clock_timestamp()))),
        'todayValidCheckins',(SELECT count(*) FROM private.attendance_checkins
            WHERE gym_local_date=v_today AND attendance_status='valid'),
        'confirmedMembershipIncomePhp',(
            SELECT COALESCE(sum(r.amount_php),0)::text FROM private.payment_records r
            JOIN private.payment_allocations a ON a.payment_id=r.id
            JOIN private.membership_purchases p ON p.id=a.membership_purchase_id
            WHERE r.verification_status='confirmed' AND private.receipt_membership_target_matches(r.id,p.id)
              AND r.amount_php=p.price_php AND a.walkin_request_id IS NULL),
        'confirmedWalkinIncomePhp',(
            SELECT COALESCE(sum(r.amount_php),0)::text FROM private.payment_records r
            JOIN private.payment_allocations a ON a.payment_id=r.id
            WHERE r.verification_status='confirmed' AND a.walkin_request_id IS NOT NULL
              AND a.membership_purchase_id IS NULL AND r.target_membership_purchase_id IS NULL)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION private.guard_walkin_allocation()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_request private.walkin_requests%ROWTYPE;
BEGIN
    IF NEW.walkin_request_id IS NULL THEN RETURN NEW; END IF;
    SELECT * INTO v_request FROM private.walkin_requests WHERE id=NEW.walkin_request_id FOR UPDATE;
    IF NOT FOUND OR v_request.request_status<>'pending' OR v_request.expires_at<=pg_catalog.clock_timestamp()
       OR v_request.requested_payment_method IS NULL OR NEW.membership_purchase_id IS NOT NULL
       OR (EXISTS(SELECT 1 FROM private.receipt_review q WHERE q.payment_id=NEW.payment_id) AND NOT EXISTS(SELECT 1 FROM private.receipt_allocation_reviews reviewed WHERE reviewed.payment_id=NEW.payment_id AND reviewed.walkin_request_id=NEW.walkin_request_id))
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

CREATE OR REPLACE FUNCTION api.owner_list_membership_payments(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_search text := NULLIF(pg_catalog.btrim(p_search), '');
    v_status text := COALESCE(NULLIF(pg_catalog.btrim(p_status), ''), 'all');
    v_payments jsonb;
    v_purchases jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF (v_search IS NOT NULL AND pg_catalog.char_length(v_search) > 80)
       OR v_status NOT IN ('all', 'recorded', 'confirmed', 'rejected', 'confirmation_voided_in_error')
       OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_PAYMENT_LIST_FILTER';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.payment_id,
                'purchaseId', page.purchase_id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'purchasePricePhp', page.purchase_price_php,
                'amountPhp', page.amount_php,
                'paymentMethod', page.payment_method,
                'verificationStatus', page.verification_status,
                'externalReference', page.external_reference,
                'createdAt', page.created_at,
                'receivedAt', page.received_at,
                'decisionReason', page.decision_reason
            ) ORDER BY page.created_at DESC, page.payment_id
        ),
        '[]'::jsonb
    ) INTO v_payments
    FROM (
        SELECT
            payment.id AS payment_id,
            purchase.id AS purchase_id,
            member.full_name AS member_name,
            member.member_code,
            plan.name AS plan_name,
            purchase.price_php AS purchase_price_php,
            payment.amount_php,
            payment.payment_method,
            payment.verification_status,
            payment.external_reference,
            payment.created_at,
            payment.received_at,
            latest_event.reason AS decision_reason
        FROM private.payment_records payment
        JOIN private.membership_purchases purchase
          ON private.receipt_membership_target_matches(payment.id,purchase.id)
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        LEFT JOIN LATERAL (
            SELECT event.reason
            FROM private.payment_events event
            WHERE event.payment_id = payment.id
              AND event.event_type IN ('payment.confirmed', 'payment.rejected', 'payment.confirmation_voided')
            ORDER BY event.created_at DESC, event.id DESC
            LIMIT 1
        ) latest_event ON true
        WHERE (v_status = 'all' OR payment.verification_status = v_status)
          AND (
              v_search IS NULL
              OR pg_catalog.strpos(pg_catalog.lower(payment.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(purchase.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.full_name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.member_code), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(plan.name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(COALESCE(payment.external_reference, '')), pg_catalog.lower(v_search)) > 0
          )
        ORDER BY payment.created_at DESC, payment.id
        LIMIT p_limit OFFSET p_offset
    ) page;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.purchase_id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'pricePhp', page.price_php
            ) ORDER BY page.created_at DESC, page.purchase_id
        ),
        '[]'::jsonb
    ) INTO v_purchases
    FROM (
        SELECT purchase.id AS purchase_id, member.full_name AS member_name,
               member.member_code, plan.name AS plan_name,
               purchase.price_php, purchase.created_at
        FROM private.membership_purchases purchase
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        WHERE purchase.purchase_status = 'pending_payment'
          AND NOT EXISTS (
              SELECT 1 FROM private.payment_records payment
              WHERE private.receipt_membership_target_matches(payment.id,purchase.id)
                AND payment.verification_status = 'recorded'
          )
          AND NOT EXISTS (
              SELECT 1 FROM private.payment_allocations allocation
              WHERE allocation.membership_purchase_id = purchase.id
          )
        ORDER BY purchase.created_at DESC, purchase.id
        LIMIT 100
    ) page;

    RETURN pg_catalog.jsonb_build_object(
        'payments', v_payments,
        'payablePurchases', v_purchases
    );
END;
$function$;
CREATE OR REPLACE FUNCTION api.owner_list_membership_purchases(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_search text := NULLIF(pg_catalog.btrim(p_search), '');
    v_status text := COALESCE(NULLIF(pg_catalog.btrim(p_status), ''), 'all');
    v_purchases jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF (v_search IS NOT NULL AND pg_catalog.char_length(v_search) > 80)
       OR v_status NOT IN ('all', 'pending_payment', 'pending_activation', 'active', 'expired', 'payment_review')
       OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE_FILTER';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'pricePhp', page.price_php,
                'purchaseStatus', page.purchase_status,
                'activationDate', page.activation_date,
                'expiryDate', page.expiry_date,
                'createdAt', page.created_at,
                'paymentStatus', page.payment_status,
                'paymentMethod', page.payment_method
            ) ORDER BY page.created_at DESC, page.id
        ),
        '[]'::jsonb
    ) INTO v_purchases
    FROM (
        SELECT purchase.id, member.full_name AS member_name,
               member.member_code, plan.name AS plan_name,
               purchase.price_php, CASE WHEN purchase.purchase_status='active' AND purchase.expiry_date<(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date THEN 'expired' ELSE purchase.purchase_status END AS purchase_status,
               purchase.activation_date, purchase.expiry_date,
               purchase.created_at, latest_payment.verification_status AS payment_status,
               latest_payment.payment_method
        FROM private.membership_purchases purchase
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        LEFT JOIN LATERAL (
            SELECT payment.verification_status, payment.payment_method
            FROM private.payment_records payment
            WHERE private.receipt_membership_target_matches(payment.id,purchase.id)
            ORDER BY (EXISTS(SELECT 1 FROM private.payment_allocations a WHERE a.payment_id=payment.id AND a.membership_purchase_id=purchase.id)) DESC, payment.created_at DESC, payment.id DESC
            LIMIT 1
        ) latest_payment ON true
        WHERE (v_status = 'all' OR (CASE WHEN purchase.purchase_status='active' AND purchase.expiry_date<(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date THEN 'expired' ELSE purchase.purchase_status END) = v_status)
          AND (
              v_search IS NULL
              OR pg_catalog.strpos(pg_catalog.lower(purchase.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.full_name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.member_code), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(plan.name), pg_catalog.lower(v_search)) > 0
          )
        ORDER BY purchase.created_at DESC, purchase.id
        LIMIT p_limit OFFSET p_offset
    ) page;
    RETURN v_purchases;
END;
$function$;
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
