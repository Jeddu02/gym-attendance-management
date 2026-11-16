-- Synthetic Owner/payment checks. No committed fixtures or role memberships.
\set ON_ERROR_STOP on
SELECT CASE WHEN current_database() = 'gymforce_pg18_test'
 AND inet_server_addr() = '127.0.0.1'::inet
 AND current_setting('port') = '55432'
 AND current_user = 'postgres' AND session_user = 'postgres'
 AND (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user)
 AND current_setting('gymforce.test_cluster_marker', true) = :'expected_cluster_marker'
 AND (pg_catalog.pg_control_system()).system_identifier::text = :'expected_system_identifier'
 AND lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) =
     lower(rtrim(replace(:'expected_data_directory', E'\\', '/'), '/'))
 THEN 'true' ELSE 'false' END AS target_verified
\gset
\if :target_verified
\else
    \echo 'Refusing Owner boundary probes: target identity mismatch.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

BEGIN;
DO $fresh_fixture_guard$
BEGIN
    IF EXISTS (SELECT 1 FROM private.owner_access)
       OR EXISTS (SELECT 1 FROM private.members)
       OR EXISTS (SELECT 1 FROM private.membership_plans)
       OR EXISTS (SELECT 1 FROM private.membership_purchases)
       OR EXISTS (SELECT 1 FROM private.payment_records)
       OR EXISTS (SELECT 1 FROM private.audit_events) THEN
        RAISE EXCEPTION 'Owner probes require empty application fixture tables';
    END IF;
END;
$fresh_fixture_guard$;
CREATE FUNCTION pg_temp.expect_error(p_statement text, p_state text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $helper$
BEGIN
    BEGIN
        EXECUTE p_statement;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = p_state THEN RETURN; END IF;
        RAISE;
    END;
    RAISE EXCEPTION 'Expected SQLSTATE %, but statement succeeded', p_state;
END;
$helper$;

INSERT INTO private.owner_access(user_id, is_active)
VALUES ('00000000-0000-4000-8000-000000000001', true);
INSERT INTO private.members(id, member_code, full_name, mobile_lookup_hash,
                            mobile_encrypted, status, approved_at)
VALUES
 ('10000000-0000-4000-8000-000000000001', 'LOCAL-VALIDATION-ACTIVE',
  'Synthetic Active Member', decode(repeat('01',32),'hex'),
  decode(repeat('01',29),'hex'), 'active', now()),
 ('10000000-0000-4000-8000-000000000002', 'LOCAL-VALIDATION-PENDING',
  'Synthetic Pending Member', decode(repeat('02',32),'hex'),
  decode(repeat('02',29),'hex'), 'pending', NULL);

SET LOCAL ROLE service_role;
DO $tests$
DECLARE
    v_owner uuid := '00000000-0000-4000-8000-000000000001';
    v_other uuid := '00000000-0000-4000-8000-000000000002';
    v_plan uuid;
    v_purchase uuid;
    v_payment uuid;
    v_operation uuid := '20000000-0000-4000-8000-000000000001';
    v_result jsonb;
BEGIN
    PERFORM pg_temp.expect_error(
        'SELECT api.owner_list_members(NULL)', '42501');
    RAISE NOTICE 'PASS owner-01: missing actor denied';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_list_members(%L::uuid)', v_other), '42501');
    RAISE NOTICE 'PASS owner-02: non-Owner actor denied';
    IF NOT api.is_active_owner_for_user(v_owner)
       OR api.is_active_owner_for_user(v_other) THEN
        RAISE EXCEPTION 'Owner authorization result incorrect';
    END IF;
    RAISE NOTICE 'PASS owner-03: active Owner versus ordinary identity';
    v_result := api.owner_save_membership_plan(v_owner, NULL, 'Synthetic Validation', 1000, true);
    v_plan := (v_result->>'id')::uuid;
    IF v_plan IS NULL THEN RAISE EXCEPTION 'Plan creation failed'; END IF;
    RAISE NOTICE 'PASS owner-04: Owner plan creation through service role';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_save_membership_plan(%L::uuid,NULL,%L,0,true)',
        v_owner, 'Invalid Synthetic Price'), '22023');
    RAISE NOTICE 'PASS owner-05: nonpositive plan price denied';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_create_membership_purchase(%L::uuid,%L::uuid,%L::uuid)',
        v_owner, '10000000-0000-4000-8000-000000000002', v_plan), '22023');
    RAISE NOTICE 'PASS owner-06: pending member cannot purchase';
    v_result := api.owner_create_membership_purchase(v_owner,
        '10000000-0000-4000-8000-000000000001', v_plan);
    v_purchase := (v_result->>'id')::uuid;
    IF v_purchase IS NULL OR v_result->>'purchaseStatus' <> 'pending_payment'
       OR v_result->>'activationDate' IS NOT NULL OR v_result->>'expiryDate' IS NOT NULL THEN
        RAISE EXCEPTION 'Unpaid purchase unexpectedly granted dated access';
    END IF;
    RAISE NOTICE 'PASS owner-07: purchase begins unpaid without dates';
    v_result := api.owner_record_membership_payment(v_owner, v_operation,
        v_purchase, 1000, 'gcash', 'SYNTHETIC-VALIDATION-ONLY');
    v_payment := (v_result->>'id')::uuid;
    IF v_payment IS NULL OR v_result->>'verificationStatus' <> 'recorded' THEN
        RAISE EXCEPTION 'Recording receipt unexpectedly confirmed payment';
    END IF;
    RAISE NOTICE 'PASS owner-08: receipt recording is provisional';
    v_result := api.owner_record_membership_payment(v_owner, v_operation,
        v_purchase, 1000, 'gcash', 'SYNTHETIC-VALIDATION-ONLY');
    IF (v_result->>'id')::uuid <> v_payment OR v_result->>'replayed' <> 'true' THEN
        RAISE EXCEPTION 'Idempotent replay failed';
    END IF;
    RAISE NOTICE 'PASS owner-09: exact receipt replay is idempotent';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_record_membership_payment(%L::uuid,%L::uuid,%L::uuid,999,%L,%L)',
        v_owner,v_operation,v_purchase,'gcash','SYNTHETIC-VALIDATION-ONLY'), '22023');
    RAISE NOTICE 'PASS owner-10: operation ID cannot change receipt facts';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_confirm_membership_payment(%L::uuid,%L::uuid,true)',
        v_other,v_payment), '42501');
    RAISE NOTICE 'PASS owner-11: non-Owner cannot confirm payment';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_confirm_membership_payment(%L::uuid,%L::uuid,false)',
        v_owner,v_payment), '22023');
    RAISE NOTICE 'PASS owner-12: electronic payment requires evidence review';
    v_result := api.owner_confirm_membership_payment(v_owner,v_payment,true);
    IF v_result->>'verificationStatus' <> 'confirmed'
       OR v_result->>'purchaseStatus' <> 'pending_activation' THEN
        RAISE EXCEPTION 'Confirmation result incorrect';
    END IF;
    RAISE NOTICE 'PASS owner-13: Owner confirmation reaches pending activation';
    PERFORM pg_temp.expect_error(format(
        'SELECT api.owner_confirm_membership_payment(%L::uuid,%L::uuid,true)',
        v_owner,v_payment), 'P0001');
    RAISE NOTICE 'PASS owner-14: duplicate confirmation denied';
END;
$tests$;
RESET ROLE;

DO $integrity$
BEGIN
    PERFORM pg_temp.expect_error(
        'UPDATE private.payment_records SET amount_php = amount_php + 1', '55000');
    RAISE NOTICE 'PASS owner-15: confirmed receipt immutable even for direct writes';
    PERFORM pg_temp.expect_error(
        'UPDATE private.audit_events SET event_type = ''synthetic.tamper''', '55000');
    RAISE NOTICE 'PASS owner-16: audit history rejects direct mutation';
    IF EXISTS (SELECT 1 FROM private.membership_purchases
               WHERE activation_date IS NOT NULL OR expiry_date IS NOT NULL) THEN
        RAISE EXCEPTION 'Payment confirmation unexpectedly created dated access';
    END IF;
    RAISE NOTICE 'PASS owner-17: confirmation alone grants no membership dates';
    IF EXISTS (SELECT 1 FROM api.verify_audit_stream('payments') WHERE NOT is_valid)
       OR EXISTS (SELECT 1 FROM api.verify_audit_stream('membership_plans') WHERE NOT is_valid)
       OR EXISTS (SELECT 1 FROM api.verify_audit_stream('membership_purchases') WHERE NOT is_valid) THEN
        RAISE EXCEPTION 'Synthetic audit stream verification failed';
    END IF;
    RAISE NOTICE 'PASS owner-18: generated audit chains verify';
END;
$integrity$;
ROLLBACK;
\echo 'Owner boundary probes rolled back; sequence values may have advanced.'
