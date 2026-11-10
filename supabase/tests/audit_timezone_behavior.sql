\set ON_ERROR_STOP on
BEGIN;
DO $timezone_test$
DECLARE zone text; valid boolean; events bigint;
BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
  RAISE EXCEPTION 'Synthetic target required';
 END IF;
 IF (SELECT count(*) FROM private.audit_events WHERE stream_key='synthetic-timezone')<>2 THEN
  RAISE EXCEPTION 'Missing legacy fixture';
 END IF;
 IF (SELECT event_hash FROM private.audit_events WHERE subject_id='fixture-first') IS DISTINCT FROM
    (SELECT details->>'original_hash' FROM private.audit_events WHERE subject_id='fixture-snapshot') THEN
  RAISE EXCEPTION 'Legacy event hash was changed';
 END IF;
 FOREACH zone IN ARRAY ARRAY['UTC','Asia/Manila','America/New_York','Europe/Berlin'] LOOP
  PERFORM set_config('TimeZone',zone,true);
  SET LOCAL ROLE service_role;
  PERFORM api.append_audit_event('synthetic-timezone',NULL,'test.zone','synthetic',NULL,jsonb_build_object('test_zone',zone));
  SELECT is_valid,checked_events INTO valid,events FROM api.verify_audit_stream('synthetic-timezone');
  RESET ROLE;
  IF valid IS DISTINCT FROM true OR events<3 THEN RAISE EXCEPTION 'Audit verification depends on session timezone'; END IF;
 END LOOP;
END $timezone_test$;
ROLLBACK;
\echo 'PASS: preserved legacy hashes and stable audit verification across four timezones.'
