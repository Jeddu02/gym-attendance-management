BEGIN;
SET LOCAL TIME ZONE 'America/New_York';
DO $seed$
DECLARE original_hash text;
BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
  RAISE EXCEPTION 'Synthetic target required';
 END IF;
 IF EXISTS(SELECT 1 FROM private.audit_events WHERE stream_key='synthetic-incompatible-timezone') THEN
  RAISE EXCEPTION 'Incompatible fixture collision';
 END IF;
 PERFORM api.append_audit_event('synthetic-incompatible-timezone',NULL,'test.first','synthetic','incompatible-first','{}');
 SELECT event_hash INTO STRICT original_hash FROM private.audit_events WHERE stream_key='synthetic-incompatible-timezone';
 PERFORM api.append_audit_event('synthetic-incompatible-timezone',NULL,'test.snapshot','synthetic','incompatible-snapshot',jsonb_build_object('original_hash',original_hash));
END $seed$;
COMMIT;
