-- Isolated SQL-query fixture, not migration runner history or applied-source evidence.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN IF current_database()<>'gymforce_batch1_synthetic' OR current_user<>'gf_provider_admin'
OR current_setting('gymforce.synthetic_run_id',true) IS NULL OR to_regnamespace('supabase_migrations') IS NOT NULL
THEN RAISE EXCEPTION 'Fresh synthetic history fixture required'; END IF; END $guard$;
CREATE SCHEMA supabase_migrations;
CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY);
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('20261028061728'),('20261028062516'),('20261028062602'),('20261028062706'),('20261028062757'),('20261028062853'),('20261028062935'),('20261028063027'),('20261028063404'),('20261028063446'),('20261028063638'),('20261028064100'),('20261029100000'),('20261030120000'),('20261030130000'),('20261030140000'),('20261030150000'),('20261030160000'),('20261030170000'),('20261030180000');
COMMIT;
\ir ../../history.sql
BEGIN;
DROP TABLE supabase_migrations.schema_migrations;
DROP SCHEMA supabase_migrations;
COMMIT;
