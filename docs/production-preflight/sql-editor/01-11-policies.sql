-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 11. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Policy metadata only; expression bodies can contain private constants.
SELECT n.nspname AS schema_name,c.relname AS relation,p.polname AS policy,
       p.polcmd AS command,p.polpermissive AS permissive,
       p.polqual IS NOT NULL AS has_using,p.polwithcheck IS NOT NULL AS has_check,
       ARRAY(SELECT CASE WHEN x.role_oid=0 THEN 'PUBLIC'
            WHEN r.rolname IN ('postgres','anon','authenticated','service_role',
                 'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
            THEN r.rolname ELSE 'OTHER_ROLE' END
            FROM unnest(p.polroles) x(role_oid)
            LEFT JOIN pg_catalog.pg_roles r ON r.oid=x.role_oid ORDER BY 1) AS roles
FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings') ORDER BY 1,2,3;
ROLLBACK;
