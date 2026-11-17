-- Synthetic pre-P01 checks; no financial/member/audit history is changed.
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
INSERT INTO private.membership_plans(name,price_php) VALUES
 (' Recovery   duplicate ',300),('recovery duplicate',300);
DO $duplicate$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.membership_plans
  GROUP BY lower(btrim(regexp_replace(name,'\s+',' ','g'))) HAVING count(*)>1)
 THEN RAISE EXCEPTION 'Legacy normalized-name conflict missed'; END IF;
END $duplicate$;
ROLLBACK;
BEGIN;
INSERT INTO private.cash_drawer_sessions(opened_by,opening_float_php)
 VALUES('00000000-0000-4000-8000-000000000001',0);
DO $legacy$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.cash_drawer_sessions)
 THEN RAISE EXCEPTION 'Legacy cash gate missed an existing session'; END IF;
END $legacy$;
ROLLBACK;
\echo 'PASS: conflicting normalized plan and legacy cash fixtures detected; originals rolled back.'
