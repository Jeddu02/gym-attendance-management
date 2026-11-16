-- Destructive cleanup of the dedicated disposable test database only.
-- Invoke with psql connected to gymforce_pg18_test on 127.0.0.1:55432.
\set ON_ERROR_STOP on

\if :{?expected_cluster_marker}
\else
    \echo 'Refusing cleanup: expected_cluster_marker was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_system_identifier}
\else
    \echo 'Refusing cleanup: expected_system_identifier was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_data_directory}
\else
    \echo 'Refusing cleanup: expected_data_directory was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT CASE
    WHEN current_setting('gymforce.test_cluster_marker', true) = :'expected_cluster_marker'
     AND (pg_catalog.pg_control_system()).system_identifier::text = :'expected_system_identifier'
     AND lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) =
         lower(rtrim(replace(:'expected_data_directory', E'\\', '/'), '/'))
     AND current_user = 'postgres'
     AND session_user = 'postgres'
     AND (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user)
    THEN 'true' ELSE 'false'
END AS cluster_marker_matches
\gset
\if :cluster_marker_matches
\else
    \echo 'Refusing cleanup: cluster marker, system identifier, or data directory does not match.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

DO $cleanup_guard$
BEGIN
    IF current_database() <> 'gymforce_pg18_test'
       OR current_setting('port') <> '55432'
       OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
        RAISE EXCEPTION
            'Refusing cleanup outside gymforce_pg18_test on 127.0.0.1:55432';
    END IF;
    IF current_user <> 'postgres' OR session_user <> 'postgres' OR NOT
       (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user) THEN
        RAISE EXCEPTION 'Run cleanup as the local PostgreSQL superuser postgres';
    END IF;
END;
$cleanup_guard$;

\connect postgres

SELECT CASE
    WHEN current_database() = 'postgres'
     AND current_user = 'postgres' AND session_user = 'postgres'
     AND (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user)
     AND current_setting('port') = '55432'
     AND inet_server_addr() = '127.0.0.1'::inet
     AND current_setting('gymforce.test_cluster_marker', true) = :'expected_cluster_marker'
     AND (pg_catalog.pg_control_system()).system_identifier::text = :'expected_system_identifier'
     AND lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) =
         lower(rtrim(replace(:'expected_data_directory', E'\\', '/'), '/'))
    THEN 'true' ELSE 'false'
END AS connected_cluster_matches
\gset
\if :connected_cluster_matches
\else
    \echo 'Refusing cleanup: maintenance connection is not the marked local cluster.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

DROP DATABASE gymforce_pg18_test WITH (FORCE);
