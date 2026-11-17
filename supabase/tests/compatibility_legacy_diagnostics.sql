-- Synthetic catalog fixtures only. Never run on an existing database.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet OR current_user<>'gf_provider_admin'
 OR to_regclass('private.pin_enrollment_global_rate_limits') IS NOT NULL
 THEN RAISE EXCEPTION 'Fresh synthetic legacy fixture required'; END IF;
END $guard$;
CREATE TABLE private.pin_enrollment_global_rate_limits(id integer PRIMARY KEY);
CREATE VIEW private.gf_compatibility_legacy_dependency AS SELECT id FROM private.pin_enrollment_global_rate_limits;
CREATE POLICY gf_compatibility_legacy_fixture ON private.pin_enrollment_global_rate_limits FOR SELECT TO anon USING(true);
COMMIT;
-- Standalone read-only transaction, never nested in the fixture transaction.
\ir ../recovery/diagnostics/legacy-dependencies.sql
BEGIN;
DROP VIEW private.gf_compatibility_legacy_dependency;
DROP TABLE private.pin_enrollment_global_rate_limits;
COMMIT;
\echo 'PASS: synthetic legacy dependency fixture removed; no existing objects adopted.'
