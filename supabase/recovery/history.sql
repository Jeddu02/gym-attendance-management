-- OWNER REVIEW REQUIRED. Not executed against production.
-- One version-only JSON cell; no migration statements, names, bodies or records.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
SELECT jsonb_build_object('format', 1, 'versions',
  COALESCE(jsonb_agg(version::text ORDER BY version::text), '[]'::jsonb)) AS history
FROM supabase_migrations.schema_migrations;
ROLLBACK;
