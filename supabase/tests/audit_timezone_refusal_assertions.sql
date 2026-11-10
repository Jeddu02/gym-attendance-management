BEGIN READ ONLY;
SET LOCAL TIME ZONE 'America/New_York';
DO $assert_refusal$
DECLARE valid boolean; n bigint;
BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
  RAISE EXCEPTION 'Synthetic target required';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid='private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)'::regprocedure
   AND proconfig @> ARRAY['TimeZone=UTC']::text[]) THEN
  RAISE EXCEPTION 'Refused migration changed the helper timezone';
 END IF;
 IF (SELECT count(*) FROM private.audit_events WHERE stream_key='synthetic-incompatible-timezone')<>2 OR
    (SELECT event_hash FROM private.audit_events WHERE subject_id='incompatible-first') IS DISTINCT FROM
    (SELECT details->>'original_hash' FROM private.audit_events WHERE subject_id='incompatible-snapshot') THEN
  RAISE EXCEPTION 'Refused migration changed legacy events or original hashes';
 END IF;
 SELECT is_valid,checked_events INTO valid,n FROM api.verify_audit_stream('synthetic-incompatible-timezone');
 IF valid IS DISTINCT FROM true OR n<>2 THEN RAISE EXCEPTION 'Refused migration changed legacy head/history'; END IF;
END $assert_refusal$;
ROLLBACK;
\echo 'PASS: incompatible legacy audit migration refused and rolled back without rehash/config/head changes.'
