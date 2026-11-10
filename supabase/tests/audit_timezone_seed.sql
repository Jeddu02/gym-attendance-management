-- Committed synthetic legacy history used to prove no rehash during migration.
BEGIN;
SET LOCAL TIME ZONE 'UTC';
DO $seed$
DECLARE first_hash text;
BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
  RAISE EXCEPTION 'Synthetic target required';
 END IF;
 IF EXISTS(SELECT 1 FROM private.audit_events WHERE stream_key='synthetic-timezone') THEN
  RAISE EXCEPTION 'Timezone fixture collision';
 END IF;
 PERFORM api.append_audit_event('synthetic-timezone',NULL,'test.first','synthetic','fixture-first','{}');
 SELECT event_hash INTO STRICT first_hash FROM private.audit_events WHERE stream_key='synthetic-timezone';
 PERFORM api.append_audit_event('synthetic-timezone',NULL,'test.snapshot','synthetic','fixture-snapshot',jsonb_build_object('original_hash',first_hash));
END $seed$;
COMMIT;
