-- OWNER REVIEW COPY. Reads private history internally; emits PASS/FAIL/UNKNOWN only.
-- Run only after 01 confirms all referenced columns/types and full Owner-role
-- SELECT visibility. Permission/timeout/schema errors mean UNKNOWN, not PASS.
-- No application RPC or helper is called. Canonical hash is recomputed inline
-- using PostgreSQL built-ins, matching the source version-1 UTC serialization.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
SET LOCAL TIME ZONE 'UTC';
WITH visibility AS (
 SELECT bool_and(pg_catalog.has_table_privilege(current_user,c.oid,'SELECT')
  AND NOT pg_catalog.row_security_active(c.oid)) AND count(*)=2 AS complete
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relname IN ('audit_events','audit_chain_heads') AND c.relkind IN ('r','p')
), ordered AS MATERIALIZED (
 SELECT e.*,lag(e.event_hash) OVER(PARTITION BY e.stream_key ORDER BY e.id) AS expected_previous,
  pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'version',1,'id',e.id,'stream_key',e.stream_key,'previous_event_hash',e.previous_event_hash,
    'actor_user_id',e.actor_user_id,'event_type',e.event_type,'subject_type',e.subject_type,
    'subject_id',e.subject_id,'details',e.details,'created_at',e.created_at)::text,'UTF8')),'hex') AS expected_hash
 FROM private.audit_events e
), tails AS (
 SELECT DISTINCT ON(stream_key) stream_key,id,event_hash FROM ordered ORDER BY stream_key,id DESC
), facts AS (
 SELECT
  NOT EXISTS(SELECT 1 FROM ordered WHERE stream_key IS NULL OR btrim(stream_key)='')
   AND NOT EXISTS(SELECT 1 FROM private.audit_chain_heads WHERE stream_key IS NULL OR btrim(stream_key)='') AS stream_keys_valid,
  NOT EXISTS(SELECT 1 FROM ordered WHERE previous_event_hash IS DISTINCT FROM expected_previous) AS predecessor_links_valid,
  NOT EXISTS(SELECT 1 FROM ordered WHERE event_hash IS DISTINCT FROM expected_hash) AS utc_hashes_valid,
  NOT EXISTS(SELECT 1 FROM tails t FULL JOIN private.audit_chain_heads h USING(stream_key)
    WHERE t.id IS NULL OR h.stream_key IS NULL OR t.id IS DISTINCT FROM h.last_event_id
      OR t.event_hash IS DISTINCT FROM h.last_event_hash) AS heads_valid
)
SELECT x.check_name,CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN'
 WHEN x.ok THEN 'PASS' ELSE 'FAIL' END AS result
FROM visibility v CROSS JOIN facts f CROSS JOIN LATERAL (VALUES
 ('audit_stream_keys',f.stream_keys_valid),('audit_predecessor_links',f.predecessor_links_valid),
 ('audit_utc_hashes',f.utc_hashes_valid),('audit_chain_heads',f.heads_valid)) x(check_name,ok);
ROLLBACK;
