-- Source preparation. Retention/triage and persistent device queue remain gated.
-- Immutable claims are not attendance. Client dates never establish presence.
BEGIN;
SET LOCAL search_path=pg_catalog;
CREATE TABLE private.owner_attendance_claims(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 operation_id uuid NOT NULL UNIQUE,
 member_code text NOT NULL CHECK(member_code ~ '^MBR-[0-9A-F]{12}$'),
 claimed_local_date date NOT NULL CHECK(claimed_local_date BETWEEN date '0001-01-01' AND date '9999-12-31'),
 submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 submitted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE private.owner_claim_resolutions(
 claim_id uuid PRIMARY KEY REFERENCES private.owner_attendance_claims(id) ON DELETE RESTRICT,
 outcome text NOT NULL CHECK(outcome IN('current_presence_confirmed','resolved_without_attendance')),
 attendance_id uuid REFERENCES private.attendance_checkins(id) ON DELETE RESTRICT,
 resolved_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 resolved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 500),
 CHECK((outcome='current_presence_confirmed')=(attendance_id IS NOT NULL))
);
DO $tables$ DECLARE relation text; columns text; BEGIN
 FOREACH relation IN ARRAY ARRAY['owner_attendance_claims','owner_claim_resolutions'] LOOP
 EXECUTE format('ALTER TABLE private.%I OWNER TO gym_data_owner',relation);
 EXECUTE format('ALTER TABLE private.%I ENABLE ROW LEVEL SECURITY',relation);
 EXECUTE format('ALTER TABLE private.%I FORCE ROW LEVEL SECURITY',relation);
 EXECUTE format('REVOKE ALL ON private.%I FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor',relation);
 SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO columns FROM pg_attribute WHERE attrelid=to_regclass('private.'||relation) AND attnum>0 AND NOT attisdropped;
 EXECUTE format('GRANT SELECT(%s),INSERT(%s) ON private.%I TO gym_owner_executor',columns,columns,relation);
 EXECUTE format('CREATE POLICY gf_owner_select ON private.%I FOR SELECT TO gym_owner_executor USING(CURRENT_USER=''gym_owner_executor''::name)',relation);
 EXECUTE format('CREATE POLICY gf_owner_insert ON private.%I FOR INSERT TO gym_owner_executor WITH CHECK(CURRENT_USER=''gym_owner_executor''::name)',relation);
 EXECUTE format('CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON private.%I FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
 EXECUTE format('CREATE TRIGGER no_truncate BEFORE TRUNCATE ON private.%I FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()',relation);
 END LOOP;
END $tables$;
GRANT INSERT(member_id,membership_purchase_id) ON private.attendance_checkins TO gym_owner_executor;
GRANT EXECUTE ON FUNCTION private.member_checkin_eligible_purchase(uuid,timestamptz),private.guard_member_attendance_basis() TO gym_owner_executor;

CREATE FUNCTION api.owner_submit_attendance_claim(p_actor_user_id uuid,p_operation_id uuid,p_member_code text,p_claimed_local_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE prior private.owner_attendance_claims%ROWTYPE; new_id uuid;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_operation_id IS NULL OR p_member_code IS NULL OR p_member_code !~ '^MBR-[0-9A-F]{12}$'
 OR p_claimed_local_date IS NULL OR NOT isfinite(p_claimed_local_date) OR p_claimed_local_date NOT BETWEEN date '0001-01-01' AND date '9999-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_PROVISIONAL_CLAIM'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('attendance-claim:'||p_operation_id::text,0));
 SELECT * INTO prior FROM private.owner_attendance_claims WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF prior.submitted_by<>p_actor_user_id OR prior.member_code<>p_member_code OR prior.claimed_local_date<>p_claimed_local_date
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CLAIM_OPERATION_CONFLICT'; END IF;
  RETURN jsonb_build_object('id',prior.id,'provisional',true,'replayed',true);
 END IF;
 INSERT INTO private.owner_attendance_claims(operation_id,member_code,claimed_local_date,submitted_by)
 VALUES(p_operation_id,p_member_code,p_claimed_local_date,p_actor_user_id) RETURNING id INTO new_id;
 PERFORM api.append_audit_event('attendance',p_actor_user_id,'attendance.claim_submitted','attendance_claim',new_id::text,
 jsonb_build_object('reason','Untrusted provisional claim received; no attendance granted.','claimed_local_date',p_claimed_local_date,'operation_id',p_operation_id));
 RETURN jsonb_build_object('id',new_id,'provisional',true,'replayed',false);
END $function$;

CREATE FUNCTION api.owner_resolve_attendance_claim(p_actor_user_id uuid,p_claim_id uuid,p_confirm_current_presence boolean,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE claim private.owner_attendance_claims%ROWTYPE; prior private.owner_claim_resolutions%ROWTYPE;
 member uuid; basis uuid; attendance uuid; at_time timestamptz; today date; outcome text;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_claim_id IS NULL OR p_confirm_current_presence IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 500
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CLAIM_RESOLUTION_REASON_REQUIRED'; END IF;
 -- Claim locking is via a bounded advisory key; no UPDATE grant on history.
 PERFORM pg_advisory_xact_lock(hashtextextended('claim-resolution:'||p_claim_id::text,0));
 SELECT * INTO claim FROM private.owner_attendance_claims WHERE id=p_claim_id;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='CLAIM_NOT_FOUND'; END IF;
 outcome:=CASE WHEN p_confirm_current_presence THEN 'current_presence_confirmed' ELSE 'resolved_without_attendance' END;
 SELECT * INTO prior FROM private.owner_claim_resolutions WHERE claim_id=claim.id;
 IF FOUND THEN
  IF prior.resolved_by<>p_actor_user_id OR prior.outcome<>outcome OR prior.reason<>btrim(p_reason)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CLAIM_ALREADY_RESOLVED'; END IF;
  RETURN jsonb_build_object('id',claim.id,'outcome',prior.outcome,'attendanceId',prior.attendance_id,'replayed',true);
 END IF;
 IF p_confirm_current_presence THEN
  SELECT id INTO member FROM private.members WHERE member_code=claim.member_code FOR UPDATE;
  at_time:=clock_timestamp(); today:=(at_time AT TIME ZONE 'Asia/Manila')::date;
  IF member IS NULL OR claim.claimed_local_date<>today THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CLAIM_REMAINS_IN_REVIEW'; END IF;
  basis:=private.member_checkin_eligible_purchase(member,at_time);
  IF basis IS NULL OR EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=member AND gym_local_date=today)
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CLAIM_REMAINS_IN_REVIEW'; END IF;
  INSERT INTO private.attendance_checkins(member_id,membership_purchase_id,gym_local_date,checked_in_at,attendance_status)
  VALUES(member,basis,today,at_time,'valid') RETURNING id INTO attendance;
  PERFORM api.append_audit_event('attendance',p_actor_user_id,'attendance.owner_presence_confirmed','attendance',attendance::text,
  jsonb_build_object('reason',btrim(p_reason),'claim_id',claim.id,'membership_purchase_id',basis,'gym_local_date',today));
 END IF;
 INSERT INTO private.owner_claim_resolutions(claim_id,outcome,attendance_id,resolved_by,reason)
 VALUES(claim.id,outcome,attendance,p_actor_user_id,btrim(p_reason));
 PERFORM api.append_audit_event('attendance',p_actor_user_id,'attendance.claim_resolved','attendance_claim',claim.id::text,
 jsonb_build_object('reason',btrim(p_reason),'outcome',outcome,'attendance_id',attendance));
 RETURN jsonb_build_object('id',claim.id,'outcome',outcome,'attendanceId',attendance,'replayed',false);
END $function$;

CREATE FUNCTION api.owner_list_attendance_claims(p_actor_user_id uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE result jsonb;
BEGIN
 IF p_actor_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM private.owner_access WHERE user_id=p_actor_user_id AND is_active)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='OWNER_ACCESS_REQUIRED'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_FILTERS'; END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(s)),'[]'::jsonb) INTO result FROM(
 SELECT c.id,c.operation_id AS "operationId",c.member_code AS "memberCode",c.claimed_local_date AS "claimedLocalDate",
 c.submitted_at AS "submittedAt",COALESCE(r.outcome,'provisional') AS status,r.reason,r.attendance_id AS "attendanceId"
 FROM private.owner_attendance_claims c LEFT JOIN private.owner_claim_resolutions r ON r.claim_id=c.id
 ORDER BY c.submitted_at DESC,c.id DESC LIMIT p_limit OFFSET p_offset) s;
 RETURN result;
END $function$;
DO $entrypoints$ DECLARE signature text; BEGIN
 FOREACH signature IN ARRAY ARRAY['api.owner_submit_attendance_claim(uuid,uuid,text,date)','api.owner_resolve_attendance_claim(uuid,uuid,boolean,text)','api.owner_list_attendance_claims(uuid,integer,integer)'] LOOP
 EXECUTE 'ALTER FUNCTION '||signature||' OWNER TO gym_owner_executor';
 EXECUTE 'REVOKE ALL ON FUNCTION '||signature||' FROM PUBLIC,anon,authenticated,service_role,gym_public_executor,gym_checkin_executor';
 EXECUTE 'GRANT EXECUTE ON FUNCTION '||signature||' TO service_role';
 END LOOP;
END $entrypoints$;
COMMIT;
