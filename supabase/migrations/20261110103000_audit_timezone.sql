-- Preserve every original event/hash. Refuse legacy history that does not
-- already verify under UTC; it needs a separately reviewed legacy resolution.
-- No audit backfill, rehash, trigger disabling or deletion is permitted here.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
SET LOCAL search_path = pg_catalog;
SET LOCAL TIME ZONE 'UTC';
LOCK TABLE private.audit_events, private.audit_chain_heads IN ACCESS EXCLUSIVE MODE;

DO $verify_legacy$
DECLARE stream text; result record;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
   WHERE p.oid='private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)'::regprocedure
   AND p.proowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_data_owner')
   AND NOT p.prosecdef) THEN
  RAISE EXCEPTION 'Restricted executor foundation is required';
 END IF;
 FOR stream IN SELECT stream_key FROM private.audit_events
   UNION SELECT stream_key FROM private.audit_chain_heads LOOP
  SELECT * INTO result FROM api.verify_audit_stream(stream);
  IF result.is_valid IS DISTINCT FROM true THEN
   RAISE EXCEPTION 'Legacy audit history requires Owner review before UTC normalization';
  END IF;
 END LOOP;
END $verify_legacy$;

-- jsonb_build_object serializes timestamptz using the execution timezone.
-- Fix it inside the pure helper, independent of Edge/client session settings.
ALTER FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)
 SET timezone = 'UTC';
COMMIT;
