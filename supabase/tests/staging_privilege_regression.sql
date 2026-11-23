-- GYMFORCE staging-only, read-only privilege regression gate.
-- Execute with Supabase SQL Editor or psql against STAGING ONLY.
-- It raises an exception on a failed invariant and makes no changes.
DO $audit$
DECLARE
  bad text;
BEGIN
  SELECT string_agg(n.nspname, ', ' ORDER BY n.nspname) INTO bad
  FROM pg_namespace n
  WHERE n.nspname IN ('private','api')
    AND (has_schema_privilege('anon',n.oid,'USAGE')
      OR has_schema_privilege('authenticated',n.oid,'USAGE')
      OR has_schema_privilege('anon',n.oid,'CREATE')
      OR has_schema_privilege('authenticated',n.oid,'CREATE'));
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'Browser-facing roles have private/API schema access: %', bad;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'private')
     OR NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'api') THEN
    RAISE EXCEPTION 'Expected private and api schemas are missing';
  END IF;

  SELECT string_agg(format('%I.%I',n.nspname,c.relname), ', ' ORDER BY n.nspname,c.relname)
    INTO bad
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('private','api','public')
    AND c.relkind IN ('r','p','v','m','f')
    AND (
      has_table_privilege('anon',c.oid,'SELECT')
      OR has_table_privilege('anon',c.oid,'INSERT')
      OR has_table_privilege('anon',c.oid,'UPDATE')
      OR has_table_privilege('anon',c.oid,'DELETE')
      OR has_table_privilege('anon',c.oid,'TRUNCATE')
      OR has_table_privilege('anon',c.oid,'REFERENCES')
      OR has_table_privilege('anon',c.oid,'TRIGGER')
      OR has_table_privilege('authenticated',c.oid,'SELECT')
      OR has_table_privilege('authenticated',c.oid,'INSERT')
      OR has_table_privilege('authenticated',c.oid,'UPDATE')
      OR has_table_privilege('authenticated',c.oid,'DELETE')
      OR has_table_privilege('authenticated',c.oid,'TRUNCATE')
      OR has_table_privilege('authenticated',c.oid,'REFERENCES')
      OR has_table_privilege('authenticated',c.oid,'TRIGGER')
    );
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'Browser-facing roles have direct relation privileges: %', bad;
  END IF;

  SELECT string_agg(format('%I.%I',n.nspname,c.relname), ', ' ORDER BY n.nspname,c.relname)
    INTO bad
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('private','api','public')
    AND c.relkind IN ('r','p')
    AND NOT c.relrowsecurity;
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'RLS missing on application tables: %', bad;
  END IF;

  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text)
    INTO bad
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('private','api','public')
    AND (has_function_privilege('anon',p.oid,'EXECUTE')
      OR has_function_privilege('authenticated',p.oid,'EXECUTE'));
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'Browser-facing roles can execute application functions: %', bad;
  END IF;

  RAISE NOTICE 'PASS: application schema, table, RLS, and function privilege invariants';
END
$audit$;
