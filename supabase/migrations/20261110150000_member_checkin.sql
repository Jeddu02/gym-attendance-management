-- Source preparation only. Production public PIN check-in remains disabled
-- pending Owner approval of abuse/KDF values and shared-network/DoS testing.
-- No plaintext PIN, client date, member Auth account, checkout or offline claim.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-member-checkin-v1',0));
LOCK TABLE private.attendance_checkins IN ACCESS EXCLUSIVE MODE;

DO $verifier_role$
DECLARE v_role oid;
BEGIN
    SELECT oid INTO v_role FROM pg_catalog.pg_roles WHERE rolname='gym_checkin_executor';
    IF v_role IS NULL THEN
        CREATE ROLE gym_checkin_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
    ELSE
        IF EXISTS(SELECT 1 FROM pg_catalog.pg_class WHERE relowner=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_proc WHERE proowner=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_namespace WHERE nspowner=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_class c,LATERAL pg_catalog.aclexplode(c.relacl) a WHERE a.grantee=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_attribute c,LATERAL pg_catalog.aclexplode(c.attacl) a WHERE a.grantee=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_proc p,LATERAL pg_catalog.aclexplode(p.proacl) a WHERE a.grantee=v_role)
           OR EXISTS(SELECT 1 FROM pg_catalog.pg_namespace n,LATERAL pg_catalog.aclexplode(n.nspacl) a WHERE a.grantee=v_role) THEN
            RAISE EXCEPTION 'Existing verifier role has unreviewed ownership or privileges';
        END IF;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='gym_checkin_executor'
        AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
        AND NOT rolinherit AND NOT rolreplication AND NOT rolbypassrls)
       OR EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members a JOIN pg_catalog.pg_roles r ON r.oid=a.member OR r.oid=a.roleid
         WHERE r.rolname='gym_checkin_executor') THEN
        RAISE EXCEPTION 'Unsafe verifier role or membership; refusing to alter it';
    END IF;
END;
$verifier_role$;
GRANT USAGE ON SCHEMA private,api TO gym_checkin_executor;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_checkin_executor REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

ALTER TABLE private.attendance_checkins ADD COLUMN membership_purchase_id uuid
    REFERENCES private.membership_purchases(id) ON DELETE RESTRICT;
ALTER TABLE private.attendance_checkins ADD CONSTRAINT walkin_has_no_membership_basis
    CHECK(member_id IS NOT NULL OR membership_purchase_id IS NULL);
CREATE INDEX attendance_membership_basis_idx ON private.attendance_checkins(membership_purchase_id)
    WHERE membership_purchase_id IS NOT NULL;

-- Operational abuse counters contain only keyed HMAC identifiers, never raw
-- member codes/mobile numbers, PINs or IP addresses. No production threshold
-- is stored or defaulted: trusted Edge must supply both explicit limits.
CREATE TABLE private.member_checkin_rate_events(
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identifier_digest text NOT NULL CHECK(identifier_digest ~ '^[0-9a-f]{64}$'),
    requested_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
CREATE INDEX member_checkin_rate_global_idx ON private.member_checkin_rate_events(requested_at);
CREATE INDEX member_checkin_rate_identifier_idx ON private.member_checkin_rate_events(identifier_digest,requested_at);
ALTER TABLE private.member_checkin_rate_events OWNER TO gym_data_owner;
ALTER TABLE private.member_checkin_rate_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.member_checkin_rate_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.member_checkin_rate_events FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
REVOKE ALL ON SEQUENCE private.member_checkin_rate_events_id_seq FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
GRANT SELECT(identifier_digest,requested_at),INSERT(identifier_digest,requested_at)
    ON private.member_checkin_rate_events TO gym_checkin_executor;
GRANT DELETE ON private.member_checkin_rate_events TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.member_checkin_rate_events FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
CREATE POLICY gf_checkin_insert ON private.member_checkin_rate_events FOR INSERT TO gym_checkin_executor WITH CHECK(CURRENT_USER='gym_checkin_executor'::name);
CREATE POLICY gf_checkin_delete ON private.member_checkin_rate_events FOR DELETE TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);

GRANT SELECT(id,member_code,mobile_lookup_hash,status,approved_at),UPDATE(updated_at) ON private.members TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.members FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
-- UPDATE is for SELECT FOR UPDATE row locking, not a member-update API.
CREATE POLICY gf_checkin_update ON private.members FOR UPDATE TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name) WITH CHECK(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(member_id,password_hash,credential_version) ON private.member_pin_credentials TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.member_pin_credentials FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(id,member_id,price_php,purchase_status,activation_date,expiry_date) ON private.membership_purchases TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.membership_purchases FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(id,amount_php,verification_status,target_membership_purchase_id) ON private.payment_records TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.payment_records FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(payment_id,membership_purchase_id) ON private.payment_allocations TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.payment_allocations FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(payment_id,event_type,created_at) ON private.payment_events TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.payment_events FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
GRANT SELECT(id,member_id,gym_local_date,attendance_status,membership_purchase_id),
    INSERT(member_id,gym_local_date,checked_in_at,attendance_status,membership_purchase_id)
    ON private.attendance_checkins TO gym_checkin_executor;
CREATE POLICY gf_checkin_select ON private.attendance_checkins FOR SELECT TO gym_checkin_executor USING(CURRENT_USER='gym_checkin_executor'::name);
CREATE POLICY gf_checkin_insert ON private.attendance_checkins FOR INSERT TO gym_checkin_executor WITH CHECK(CURRENT_USER='gym_checkin_executor'::name);
GRANT EXECUTE ON FUNCTION api.append_audit_event(text,uuid,text,text,text,jsonb) TO gym_checkin_executor;

CREATE FUNCTION private.member_checkin_eligible_purchase(p_member_id uuid,p_at timestamptz)
RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $function$
    SELECT p.id FROM private.members m JOIN private.membership_purchases p ON p.member_id=m.id
    WHERE m.id=p_member_id AND m.status='active' AND m.approved_at IS NOT NULL AND m.approved_at<=p_at
      AND p.purchase_status='active' AND p.activation_date<=(p_at AT TIME ZONE 'Asia/Manila')::date
      AND p.expiry_date>=(p_at AT TIME ZONE 'Asia/Manila')::date
      AND EXISTS(SELECT 1 FROM private.payment_allocations a JOIN private.payment_records r ON r.id=a.payment_id
          WHERE a.membership_purchase_id=p.id AND r.target_membership_purchase_id=p.id
            AND r.verification_status='confirmed' AND r.amount_php=p.price_php
            AND EXISTS(SELECT 1 FROM private.payment_events e WHERE e.payment_id=r.id
                AND e.event_type='payment.confirmed' AND e.created_at<=p_at))
    ORDER BY p.activation_date DESC,p.id LIMIT 1;
$function$;
ALTER FUNCTION private.member_checkin_eligible_purchase(uuid,timestamptz) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.member_checkin_eligible_purchase(uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.member_checkin_eligible_purchase(uuid,timestamptz) TO gym_checkin_executor;

CREATE FUNCTION private.guard_member_attendance_basis()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_basis uuid;
BEGIN
    IF NEW.member_id IS NULL THEN RETURN NEW; END IF;
    v_basis:=private.member_checkin_eligible_purchase(NEW.member_id,NEW.checked_in_at);
    IF NEW.walkin_request_id IS NOT NULL OR NEW.attendance_status<>'valid'
       OR NEW.gym_local_date IS DISTINCT FROM (pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date
       OR NEW.gym_local_date IS DISTINCT FROM (NEW.checked_in_at AT TIME ZONE 'Asia/Manila')::date
       OR NEW.checked_in_at>pg_catalog.clock_timestamp() OR NEW.membership_purchase_id IS NULL
       OR v_basis IS NULL OR NEW.membership_purchase_id IS DISTINCT FROM v_basis
       OR EXISTS(SELECT 1 FROM private.attendance_checkins c WHERE c.member_id=NEW.member_id AND c.gym_local_date=NEW.gym_local_date) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='MEMBER_ATTENDANCE_REQUIRES_CURRENT_ELIGIBILITY';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION private.guard_member_attendance_basis() OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.guard_member_attendance_basis() FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_member_attendance_basis() TO gym_checkin_executor;
CREATE TRIGGER attendance_guard_member_basis BEFORE INSERT ON private.attendance_checkins
FOR EACH ROW EXECUTE FUNCTION private.guard_member_attendance_basis();

CREATE FUNCTION api.reserve_member_checkin_request(p_identifier_digest text,p_global_limit integer,p_identifier_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_now timestamptz; v_global bigint; v_identifier bigint; v_global_at timestamptz; v_identifier_at timestamptz; v_retry integer;
BEGIN
    IF p_identifier_digest IS NULL OR p_identifier_digest !~ '^[0-9a-f]{64}$'
       OR p_global_limit IS NULL OR p_global_limit<1 OR p_global_limit>100
       OR p_identifier_limit IS NULL OR p_identifier_limit<1 OR p_identifier_limit>100 THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_MEMBER_CHECKIN_RATE_REQUEST';
    END IF;
    -- Every path takes the global lock first, then the keyed identifier lock.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-member-checkin-global-v1',0));
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-member-checkin-identifier:'||p_identifier_digest,0));
    v_now:=pg_catalog.clock_timestamp();
    DELETE FROM private.member_checkin_rate_events WHERE requested_at<=v_now-interval '60 seconds';
    SELECT count(*),count(*) FILTER(WHERE identifier_digest=p_identifier_digest) INTO v_global,v_identifier
    FROM private.member_checkin_rate_events WHERE requested_at>v_now-interval '60 seconds';
    IF v_global>=p_global_limit OR v_identifier>=p_identifier_limit THEN
        IF v_global>=p_global_limit THEN
            SELECT requested_at INTO v_global_at FROM private.member_checkin_rate_events
            WHERE requested_at>v_now-interval '60 seconds' ORDER BY requested_at DESC OFFSET(p_global_limit-1) LIMIT 1;
        END IF;
        IF v_identifier>=p_identifier_limit THEN
            SELECT requested_at INTO v_identifier_at FROM private.member_checkin_rate_events
            WHERE identifier_digest=p_identifier_digest AND requested_at>v_now-interval '60 seconds'
            ORDER BY requested_at DESC OFFSET(p_identifier_limit-1) LIMIT 1;
        END IF;
        v_retry:=LEAST(60,GREATEST(1,pg_catalog.ceil(EXTRACT(EPOCH FROM(GREATEST(v_global_at,v_identifier_at)+interval '60 seconds'-v_now)))::integer));
        RETURN pg_catalog.jsonb_build_object('allowed',false,'retryAfterSeconds',v_retry);
    END IF;
    INSERT INTO private.member_checkin_rate_events(identifier_digest,requested_at) VALUES(p_identifier_digest,v_now);
    RETURN pg_catalog.jsonb_build_object('allowed',true);
END;
$function$;
ALTER FUNCTION api.reserve_member_checkin_request(text,integer,integer) OWNER TO gym_checkin_executor;
REVOKE ALL ON FUNCTION api.reserve_member_checkin_request(text,integer,integer) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.reserve_member_checkin_request(text,integer,integer) TO service_role;

-- Trusted server-only verifier boundary. Eligibility is deliberately not part
-- of lookup, so a real candidate and dummy-verifier path both perform Argon2id
-- before the server checks membership status. Never send this JSON to clients.
CREATE FUNCTION api.prepare_member_checkin(p_member_code text,p_mobile_lookup_hash bytea)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_result jsonb;
BEGIN
    IF (p_member_code IS NULL)=(p_mobile_lookup_hash IS NULL)
       OR (p_member_code IS NOT NULL AND p_member_code !~ '^MBR-[0-9A-F]{12}$')
       OR (p_mobile_lookup_hash IS NOT NULL AND pg_catalog.octet_length(p_mobile_lookup_hash)<>32) THEN RETURN NULL; END IF;
    SELECT pg_catalog.jsonb_build_object('memberId',m.id,'credentialVersion',c.credential_version,'passwordHash',c.password_hash)
    INTO v_result FROM private.members m JOIN private.member_pin_credentials c ON c.member_id=m.id
    WHERE (p_member_code IS NOT NULL AND m.member_code=p_member_code)
       OR (p_mobile_lookup_hash IS NOT NULL AND m.mobile_lookup_hash=p_mobile_lookup_hash);
    RETURN v_result;
END;
$function$;
ALTER FUNCTION api.prepare_member_checkin(text,bytea) OWNER TO gym_checkin_executor;
REVOKE ALL ON FUNCTION api.prepare_member_checkin(text,bytea) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.prepare_member_checkin(text,bytea) TO service_role;

CREATE FUNCTION api.commit_member_checkin(p_member_id uuid,p_credential_version integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_member uuid; v_version integer; v_now timestamptz; v_today date; v_basis uuid; v_attendance uuid;
BEGIN
    IF p_member_id IS NULL OR p_credential_version IS NULL OR p_credential_version<1 THEN
        RETURN pg_catalog.jsonb_build_object('accepted',false);
    END IF;
    SELECT id INTO v_member FROM private.members WHERE id=p_member_id FOR UPDATE;
    IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('accepted',false); END IF;
    SELECT credential_version INTO v_version FROM private.member_pin_credentials WHERE member_id=v_member;
    IF NOT FOUND OR v_version IS DISTINCT FROM p_credential_version THEN RETURN pg_catalog.jsonb_build_object('accepted',false); END IF;
    v_now:=pg_catalog.clock_timestamp();
    v_today:=(v_now AT TIME ZONE 'Asia/Manila')::date;
    v_basis:=private.member_checkin_eligible_purchase(v_member,v_now);
    IF v_basis IS NULL THEN RETURN pg_catalog.jsonb_build_object('accepted',false); END IF;
    -- Invalidated history cannot be replaced by an independent eligibility basis
    -- without a separate documented Owner resolution. Never restore old rows.
    IF EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=v_member AND gym_local_date=v_today AND attendance_status<>'valid') THEN
        RETURN pg_catalog.jsonb_build_object('accepted',false);
    END IF;
    IF EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=v_member AND gym_local_date=v_today AND attendance_status='valid') THEN
        RETURN pg_catalog.jsonb_build_object('accepted',true);
    END IF;
    INSERT INTO private.attendance_checkins(member_id,membership_purchase_id,gym_local_date,checked_in_at,attendance_status)
    VALUES(v_member,v_basis,v_today,v_now,'valid') RETURNING id INTO v_attendance;
    PERFORM api.append_audit_event('attendance',NULL,'member.checked_in','attendance',v_attendance::text,
        pg_catalog.jsonb_build_object('reason','Current approved paid membership and server-verified PIN credential version.',
            'member_id',v_member,'membership_purchase_id',v_basis,'gym_local_date',v_today,'credential_version',v_version));
    RETURN pg_catalog.jsonb_build_object('accepted',true);
END;
$function$;
ALTER FUNCTION api.commit_member_checkin(uuid,integer) OWNER TO gym_checkin_executor;
REVOKE ALL ON FUNCTION api.commit_member_checkin(uuid,integer) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor;
GRANT EXECUTE ON FUNCTION api.commit_member_checkin(uuid,integer) TO service_role;

DO $verifier_boundaries$
DECLARE v_role text;
BEGIN
    FOREACH v_role IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
        IF pg_catalog.has_column_privilege(v_role,'private.member_pin_credentials','password_hash','SELECT') THEN
            RAISE EXCEPTION 'Verifier read exposed to %',v_role;
        END IF;
    END LOOP;
    IF pg_catalog.has_schema_privilege('gym_checkin_executor','private','CREATE')
       OR pg_catalog.has_schema_privilege('gym_checkin_executor','api','CREATE')
       OR pg_catalog.has_schema_privilege('gym_checkin_executor','public','CREATE')
       OR pg_catalog.has_column_privilege('gym_checkin_executor','private.members','status','UPDATE')
       OR pg_catalog.has_any_column_privilege('gym_checkin_executor','private.member_pin_credentials','INSERT,UPDATE,REFERENCES')
       OR pg_catalog.has_table_privilege('gym_checkin_executor','private.attendance_checkins','UPDATE,DELETE,TRUNCATE') THEN
        RAISE EXCEPTION 'Verifier role exceeds bounded check-in privileges';
    END IF;
END;
$verifier_boundaries$;
COMMIT;
