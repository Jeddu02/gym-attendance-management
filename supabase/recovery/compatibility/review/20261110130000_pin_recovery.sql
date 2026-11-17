-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.
-- Original source preserved; provider=supabase_admin; source SHA-256=317c77c50cca204cdcbe4b7a24eae45103c16878f921573e225e926dbe8c56c4
-- SOURCE ONLY. Owner-supervised in-person PIN setup/recovery preparation.
-- The existing 15-minute lifetime, six-digit PIN and Argon2id values are
-- DEVELOPMENT settings; production remains disabled pending Owner approval,
-- synthetic abuse/load testing and release configuration review.
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
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-pin-recovery-v1',0));
LOCK TABLE private.member_pin_credentials,private.member_pin_setup_tokens IN ACCESS EXCLUSIVE MODE;

GRANT SELECT(member_id) ON private.member_pin_credentials TO gym_owner_executor;
CREATE POLICY gf_owner_pin_exists ON private.member_pin_credentials
 FOR SELECT TO gym_owner_executor USING (CURRENT_USER='gym_owner_executor'::name);
GRANT SELECT(credential_version) ON private.member_pin_credentials TO gym_public_executor;
GRANT UPDATE(password_hash,credential_version,updated_at) ON private.member_pin_credentials TO gym_public_executor;
CREATE POLICY gf_public_reset_update ON private.member_pin_credentials
 FOR UPDATE TO gym_public_executor
 USING (CURRENT_USER='gym_public_executor'::name)
 WITH CHECK (CURRENT_USER='gym_public_executor'::name);

CREATE FUNCTION api.owner_create_verified_pin_enrollment_token(
 p_actor_user_id uuid,p_member_id uuid,p_token_hash text,p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE result jsonb; reason text:=pg_catalog.btrim(COALESCE(p_reason,''));
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF pg_catalog.char_length(reason)<5 OR pg_catalog.char_length(reason)>500
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_IDENTITY_ATTESTATION'; END IF;
 -- Existing issuance validates the member and token, serializes issuance and
 -- retains its original audit history. Expiry comes from server time only.
 result:=api.owner_create_pin_enrollment_token(p_actor_user_id,p_member_id,p_token_hash,pg_catalog.clock_timestamp()+interval '15 minutes');
 PERFORM api.append_audit_event('member-pin:'||p_member_id::text,p_actor_user_id,
  'member.pin_identity_verified','member',p_member_id::text,
  pg_catalog.jsonb_build_object('method','in_person','reason',reason,'purpose','enrollment','token_id',result->>'token_id'));
 RETURN result;
END $function$;

CREATE FUNCTION api.owner_create_pin_recovery_token(
 p_actor_user_id uuid,p_member_id uuid,p_token_hash text,p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE token_id uuid; member_status text; expiry timestamptz;
 reason text:=pg_catalog.btrim(COALESCE(p_reason,''));
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_member_id IS NULL OR p_token_hash IS NULL OR p_token_hash !~ '^[0-9a-f]{64}$'
 OR pg_catalog.char_length(reason)<5 OR pg_catalog.char_length(reason)>500
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_IDENTITY_ATTESTATION'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('pin-enrollment:'||p_member_id::text,0));
 SELECT status INTO member_status FROM private.members WHERE id=p_member_id FOR UPDATE;
 IF NOT FOUND OR member_status NOT IN ('pending','active') OR NOT EXISTS(
  SELECT 1 FROM private.member_pin_credentials WHERE member_id=p_member_id)
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='MEMBER_NOT_ELIGIBLE'; END IF;
 UPDATE private.member_pin_setup_tokens SET consumed_at=pg_catalog.clock_timestamp()
 WHERE member_id=p_member_id AND consumed_at IS NULL;
 expiry:=pg_catalog.clock_timestamp()+interval '15 minutes';
 INSERT INTO private.member_pin_setup_tokens(member_id,token_hash,token_purpose,expires_at)
 VALUES(p_member_id,p_token_hash,'reset',expiry) RETURNING id INTO token_id;
 PERFORM api.append_audit_event('member-pin:'||p_member_id::text,p_actor_user_id,
  'member.pin_recovery_authorized','member',p_member_id::text,
  pg_catalog.jsonb_build_object('method','in_person','reason',reason,'purpose','reset','token_id',token_id,'expires_at',expiry));
 RETURN pg_catalog.jsonb_build_object('tokenId',token_id,'expiresAt',expiry,'purpose','reset');
END $function$;

CREATE FUNCTION api.member_reset_pin(p_token_hash text,p_password_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE member uuid; member_status text; token uuid; expiry timestamptz; version integer;
BEGIN
 IF p_token_hash IS NULL OR p_token_hash !~ '^[0-9a-f]{64}$'
 OR p_password_hash IS NULL OR p_password_hash !~ '^\$argon2id\$v=19\$m=65536,t=3,p=1\$[A-Za-z0-9+/]+=*\$[A-Za-z0-9+/]+=*$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_SETUP_REQUEST'; END IF;
 -- First lookup is nonlocking. After acquiring the shared member mutex and
 -- member row, revalidate/lock the token and recheck server expiry after waits.
 SELECT member_id INTO member FROM private.member_pin_setup_tokens
 WHERE token_hash=p_token_hash AND token_purpose='reset' AND consumed_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('pin-enrollment:'||member::text,0));
 SELECT status INTO member_status FROM private.members WHERE id=member FOR UPDATE;
 IF NOT FOUND OR member_status NOT IN ('pending','active')
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 SELECT id,expires_at INTO token,expiry FROM private.member_pin_setup_tokens
 WHERE token_hash=p_token_hash AND member_id=member AND token_purpose='reset' AND consumed_at IS NULL FOR UPDATE;
 IF NOT FOUND OR expiry<=pg_catalog.clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 SELECT credential_version INTO version FROM private.member_pin_credentials WHERE member_id=member FOR UPDATE;
 IF NOT FOUND OR version=2147483647
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 UPDATE private.member_pin_credentials
 SET password_hash=p_password_hash,credential_version=version+1,updated_at=pg_catalog.clock_timestamp()
 WHERE member_id=member;
 UPDATE private.member_pin_setup_tokens SET consumed_at=pg_catalog.clock_timestamp()
 WHERE member_id=member AND consumed_at IS NULL;
 PERFORM api.append_audit_event('member-pin:'||member::text,NULL,'member.pin_reset','member',member::text,
  pg_catalog.jsonb_build_object('credential_version',version+1,'method','owner_verified_one_time_reset'));
 RETURN pg_catalog.jsonb_build_object('success',true,'credentialVersion',version+1);
END $function$;

-- Preserve enrollment behavior while giving issuance, enrollment and recovery
-- a common lock order: advisory/member/token. Recheck expiry AFTER lock waits.
CREATE OR REPLACE FUNCTION api.member_enroll_pin(p_token_hash text,p_password_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE member uuid; member_status text; token uuid; expiry timestamptz;
BEGIN
 IF p_token_hash IS NULL OR p_token_hash !~ '^[0-9a-f]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_ENROLLMENT_REQUEST'; END IF;
 IF p_password_hash IS NULL OR p_password_hash !~ '^\$argon2id\$v=19\$m=65536,t=3,p=1\$[A-Za-z0-9+/]+=*\$[A-Za-z0-9+/]+=*$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_PIN_HASH'; END IF;
 SELECT member_id INTO member FROM private.member_pin_setup_tokens
 WHERE token_hash=p_token_hash AND token_purpose='enrollment' AND consumed_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('pin-enrollment:'||member::text,0));
 SELECT status INTO member_status FROM private.members WHERE id=member FOR UPDATE;
 IF NOT FOUND OR member_status NOT IN ('pending','active')
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 SELECT id,expires_at INTO token,expiry FROM private.member_pin_setup_tokens
 WHERE token_hash=p_token_hash AND member_id=member AND token_purpose='enrollment' AND consumed_at IS NULL FOR UPDATE;
 IF NOT FOUND OR expiry<=pg_catalog.clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 IF EXISTS(SELECT 1 FROM private.member_pin_credentials WHERE member_id=member)
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='PIN_ALREADY_ENROLLED'; END IF;
 INSERT INTO private.member_pin_credentials(member_id,password_hash,credential_version,created_at,updated_at)
 VALUES(member,p_password_hash,1,pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp());
 UPDATE private.member_pin_setup_tokens SET consumed_at=pg_catalog.clock_timestamp() WHERE id=token AND consumed_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INVALID_OR_EXPIRED_TOKEN'; END IF;
 PERFORM api.append_audit_event('member-pin:'||member::text,NULL,'member.pin_enrolled','member',member::text,
  pg_catalog.jsonb_build_object('credential_version',1,'method','one_time_enrollment_token'));
 RETURN pg_catalog.jsonb_build_object('success',true,'credentialVersion',1);
END $function$;

ALTER FUNCTION api.owner_create_verified_pin_enrollment_token(uuid,uuid,text,text) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_create_pin_recovery_token(uuid,uuid,text,text) OWNER TO gym_owner_executor;
ALTER FUNCTION api.member_reset_pin(text,text) OWNER TO gym_public_executor;
REVOKE ALL ON FUNCTION api.owner_create_verified_pin_enrollment_token(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
REVOKE ALL ON FUNCTION api.owner_create_pin_recovery_token(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated,service_role,gym_public_executor;
REVOKE ALL ON FUNCTION api.member_reset_pin(text,text) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor;
GRANT EXECUTE ON FUNCTION api.owner_create_verified_pin_enrollment_token(uuid,uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_create_pin_recovery_token(uuid,uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION api.member_reset_pin(text,text) TO service_role;
-- Remove the gateway bypass of the verified enrollment/attestation wrapper.
REVOKE EXECUTE ON FUNCTION api.owner_create_pin_enrollment_token(uuid,uuid,text,timestamptz) FROM service_role;

DO $acceptance$
DECLARE r text; item record;
BEGIN
 IF pg_catalog.has_function_privilege('service_role','api.owner_create_pin_enrollment_token(uuid,uuid,text,timestamptz)','EXECUTE')
 THEN RAISE EXCEPTION 'Unverified enrollment issuance still exposed'; END IF;
 FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
  IF pg_catalog.has_column_privilege(r,'private.member_pin_credentials','password_hash','SELECT')
  THEN RAISE EXCEPTION 'PIN verifier read exposed to %',r; END IF;
 END LOOP;
 IF NOT pg_catalog.has_column_privilege('gym_public_executor','private.member_pin_credentials','password_hash','UPDATE')
 OR pg_catalog.has_column_privilege('gym_owner_executor','private.member_pin_credentials','password_hash','UPDATE')
 OR pg_catalog.has_table_privilege('gym_public_executor','private.member_pin_credentials','DELETE')
 THEN RAISE EXCEPTION 'PIN recovery credential ACL drift'; END IF;
 FOR item IN SELECT * FROM (VALUES
  ('api.owner_create_verified_pin_enrollment_token(uuid,uuid,text,text)','gym_owner_executor'),
  ('api.owner_create_pin_recovery_token(uuid,uuid,text,text)','gym_owner_executor'),
  ('api.member_reset_pin(text,text)','gym_public_executor')) AS expected(signature,executor)
 LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p WHERE p.oid=pg_catalog.to_regprocedure(item.signature)
   AND pg_catalog.pg_get_userbyid(p.proowner)=item.executor AND p.prosecdef
   AND p.proconfig=ARRAY['search_path=""']::text[])
  THEN RAISE EXCEPTION 'PIN entrypoint boundary drift: %',item.signature; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF pg_catalog.has_function_privilege(r,item.signature,'EXECUTE') THEN RAISE EXCEPTION 'Browser PIN RPC exposed'; END IF;
  END LOOP;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid='private.member_pin_credentials'::regclass
  AND polname='gf_public_reset_update' AND polcmd='w'
  AND polroles=ARRAY[(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_public_executor')]
  AND pg_catalog.pg_get_expr(polqual,polrelid)='(CURRENT_USER = ''gym_public_executor''::name)'
  AND pg_catalog.pg_get_expr(polwithcheck,polrelid)='(CURRENT_USER = ''gym_public_executor''::name)')
 THEN RAISE EXCEPTION 'PIN recovery UPDATE policy missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid='private.member_pin_credentials'::regclass
  AND polname='gf_owner_pin_exists' AND polcmd='r'
  AND polroles=ARRAY[(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_owner_executor')]
  AND pg_catalog.pg_get_expr(polqual,polrelid)='(CURRENT_USER = ''gym_owner_executor''::name)')
 THEN RAISE EXCEPTION 'Owner PIN existence policy missing'; END IF;
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
