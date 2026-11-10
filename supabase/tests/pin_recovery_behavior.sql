-- Synthetic native SQL only. Run in the guarded fresh runner after recovery
-- migration. This tests SQL/ACL behavior, not KDF, JWT or production readiness.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic'
 OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES('00000000-0000-4000-8000-000000000001',true)
ON CONFLICT(user_id) DO UPDATE SET is_active=true,deactivated_at=NULL;
INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted,status)
VALUES('51000000-0000-4000-8000-000000000001','SYNTHETIC-PIN-RECOVERY','Synthetic recovery fixture',decode(repeat('51',32),'hex'),decode(repeat('52',32),'hex'),'pending'),
('51000000-0000-4000-8000-000000000002','SYNTHETIC-PIN-SETUP','Synthetic enrollment fixture',decode(repeat('53',32),'hex'),decode(repeat('54',32),'hex'),'pending');
INSERT INTO private.member_pin_credentials(member_id,password_hash)
VALUES('51000000-0000-4000-8000-000000000001','$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$T1JJR0lOQUw');

SET LOCAL ROLE service_role;
DO $authorization$
DECLARE owner_id uuid:='00000000-0000-4000-8000-000000000001'; member uuid:='51000000-0000-4000-8000-000000000001';
BEGIN
 BEGIN
  PERFORM api.owner_create_pin_enrollment_token(owner_id,member,repeat('1',64),clock_timestamp()+interval '15 minutes');
  RAISE EXCEPTION 'Unverified issuance exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM api.owner_create_pin_recovery_token('00000000-0000-4000-8000-000000000002',member,repeat('2',64),'Synthetic identity verification');
  RAISE EXCEPTION 'Outsider recovery allowed';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM api.owner_create_verified_pin_enrollment_token(owner_id,member,repeat('3',64),'bad');
  RAISE EXCEPTION 'Missing attestation allowed';
 EXCEPTION WHEN invalid_parameter_value THEN
  IF SQLERRM<>'INVALID_IDENTITY_ATTESTATION' THEN RAISE; END IF;
 END;
 PERFORM api.owner_create_verified_pin_enrollment_token(owner_id,member,repeat('4',64),'Synthetic in-person identity checked');
 -- An enrollment-purpose token can never authorize replacement.
 BEGIN
  PERFORM api.member_reset_pin(repeat('4',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ');
  RAISE EXCEPTION 'Enrollment token used for recovery';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
 PERFORM api.owner_create_pin_recovery_token(owner_id,member,repeat('5',64),'Synthetic in-person identity checked');
END $authorization$;
RESET ROLE;

-- An expired token remains preserved/unconsumed after refusal. Only synthetic
-- fixture timestamps change; this is not a supported application mutation.
UPDATE private.member_pin_setup_tokens SET created_at=clock_timestamp()-interval '2 days',expires_at=clock_timestamp()-interval '1 day'
WHERE token_hash=repeat('5',64);
SET LOCAL ROLE service_role;
DO $expired$
BEGIN
 BEGIN
  PERFORM api.member_reset_pin(repeat('5',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ');
  RAISE EXCEPTION 'Expired reset token accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
END $expired$;
RESET ROLE;
DO $unchanged$ BEGIN
 IF (SELECT credential_version FROM private.member_pin_credentials WHERE member_id='51000000-0000-4000-8000-000000000001')<>1
 OR EXISTS(SELECT 1 FROM private.member_pin_setup_tokens WHERE token_hash=repeat('5',64) AND consumed_at IS NOT NULL)
 THEN RAISE EXCEPTION 'Refusal changed credentials/token'; END IF;
END $unchanged$;
SET LOCAL ROLE service_role;
SELECT api.owner_create_pin_recovery_token('00000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001',repeat('6',64),'Synthetic in-person identity checked');
RESET ROLE;

DO $atomic$
BEGIN
 BEGIN
  REVOKE EXECUTE ON FUNCTION api.append_audit_event(text,uuid,text,text,text,jsonb) FROM gym_public_executor;
  SET LOCAL ROLE service_role;
  PERFORM api.member_reset_pin(repeat('6',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ');
  RAISE EXCEPTION 'Audit failure ignored';
 EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  IF SQLERRM NOT LIKE '%append_audit_event%' THEN RAISE; END IF;
 END;
 IF (SELECT credential_version FROM private.member_pin_credentials WHERE member_id='51000000-0000-4000-8000-000000000001')<>1
 OR EXISTS(SELECT 1 FROM private.member_pin_setup_tokens WHERE token_hash=repeat('6',64) AND consumed_at IS NOT NULL)
 THEN RAISE EXCEPTION 'Failed reset retained partial writes'; END IF;
END $atomic$;

SET LOCAL ROLE service_role;
DO $reset$
DECLARE result jsonb;
BEGIN
 result:=api.member_reset_pin(repeat('6',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ');
 IF result->>'success' IS DISTINCT FROM 'true' OR result->>'credentialVersion' IS DISTINCT FROM '2'
 THEN RAISE EXCEPTION 'Reset output wrong'; END IF;
 BEGIN
  PERFORM api.member_reset_pin(repeat('6',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ');
  RAISE EXCEPTION 'Token reuse accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
END $reset$;
RESET ROLE;
DO $state$
DECLARE actor text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.member_pin_credentials WHERE member_id='51000000-0000-4000-8000-000000000001'
  AND credential_version=2 AND password_hash='$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$UkVQTEFDRU1FTlQ')
 OR EXISTS(SELECT 1 FROM private.member_pin_setup_tokens WHERE member_id='51000000-0000-4000-8000-000000000001' AND consumed_at IS NULL)
 OR (SELECT count(*) FROM private.audit_events WHERE event_type='member.pin_reset' AND subject_id='51000000-0000-4000-8000-000000000001')<>1
 OR NOT EXISTS(SELECT 1 FROM private.audit_events WHERE event_type='member.pin_recovery_authorized' AND subject_id='51000000-0000-4000-8000-000000000001'
  AND actor_user_id='00000000-0000-4000-8000-000000000001' AND details->>'method'='in_person' AND details->>'reason'='Synthetic in-person identity checked')
 THEN RAISE EXCEPTION 'Recovery state or attestation missing'; END IF;
 FOREACH actor IN ARRAY ARRAY['gym_owner_executor','gym_public_executor','service_role','anon','authenticated'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',actor);
  BEGIN
   PERFORM password_hash FROM private.member_pin_credentials;
   RAISE EXCEPTION 'Verifier read exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
 END LOOP;
END $state$;

-- Existing enrollment remains single-use and expiry-checked with the new
-- common lock ordering. The Owner verifies identity through the new wrapper.
SET LOCAL ROLE service_role;
SELECT api.owner_create_verified_pin_enrollment_token('00000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002',repeat('7',64),'Synthetic in-person identity checked');
RESET ROLE;
UPDATE private.member_pin_setup_tokens SET created_at=clock_timestamp()-interval '2 days',expires_at=clock_timestamp()-interval '1 day'
WHERE token_hash=repeat('7',64);
SET LOCAL ROLE service_role;
DO $legacy_enrollment$
DECLARE result jsonb;
BEGIN
 BEGIN
  PERFORM api.member_enroll_pin(repeat('7',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$RU5ST0xMRUQ');
  RAISE EXCEPTION 'Expired enrollment accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
 PERFORM api.owner_create_verified_pin_enrollment_token('00000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002',repeat('8',64),'Synthetic in-person identity checked');
 result:=api.member_enroll_pin(repeat('8',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$RU5ST0xMRUQ');
 IF result->>'success' IS DISTINCT FROM 'true' OR result->>'credentialVersion' IS DISTINCT FROM '1'
 THEN RAISE EXCEPTION 'Enrollment output changed'; END IF;
 BEGIN
  PERFORM api.member_enroll_pin(repeat('8',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGlj$RU5ST0xMRUQ');
  RAISE EXCEPTION 'Consumed enrollment token accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
END $legacy_enrollment$;
RESET ROLE;
DO $enrollment_state$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.member_pin_credentials WHERE member_id='51000000-0000-4000-8000-000000000002' AND credential_version=1)
 OR NOT EXISTS(SELECT 1 FROM private.audit_events WHERE event_type='member.pin_identity_verified' AND subject_id='51000000-0000-4000-8000-000000000002' AND details->>'method'='in_person')
 THEN RAISE EXCEPTION 'Verified enrollment state/audit missing'; END IF;
END $enrollment_state$;
ROLLBACK;
\echo 'PASS: synthetic verified setup/recovery authorization, expiry, one-use token, versioning, audit and rollback assertions.'
