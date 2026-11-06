-- Run as postgres against a disposable local database after all migrations.
-- This suite is read-only and does not contact the hosted project.
DO $assertions$
DECLARE
    v_table text;
    v_signature text;
    v_function oid;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'payment_records', 'payment_allocations', 'payment_events'
    ] LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'private'
              AND c.relname = v_table
              AND c.relrowsecurity
        ) THEN
            RAISE EXCEPTION 'RLS is not enabled on private.%', v_table;
        END IF;

        IF pg_catalog.has_table_privilege('anon', 'private.' || v_table, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
           OR pg_catalog.has_table_privilege('authenticated', 'private.' || v_table, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
            RAISE EXCEPTION 'Browser role has a direct privilege on private.%', v_table;
        END IF;
    END LOOP;

    FOREACH v_signature IN ARRAY ARRAY[
        'api.owner_record_membership_payment(uuid,uuid,uuid,numeric,text,text)',
        'api.owner_confirm_membership_payment(uuid,uuid,boolean)',
        'api.owner_reject_membership_payment(uuid,uuid,text)',
        'api.owner_list_membership_payments(uuid,text,text,integer,integer)',
        'api.owner_list_membership_purchases(uuid,text,text,integer,integer)'
    ] LOOP
        v_function := pg_catalog.to_regprocedure(v_signature);
        IF v_function IS NULL THEN
            RAISE EXCEPTION 'Required payment RPC is missing: %', v_signature;
        END IF;
        IF NOT (SELECT p.prosecdef FROM pg_catalog.pg_proc p WHERE p.oid = v_function)
           OR NOT (SELECT COALESCE(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']::text[]
                   FROM pg_catalog.pg_proc p WHERE p.oid = v_function) THEN
            RAISE EXCEPTION 'Payment RPC lacks SECURITY DEFINER or an empty search_path: %', v_signature;
        END IF;
        IF pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
           OR pg_catalog.has_function_privilege('authenticated', v_function, 'EXECUTE')
           OR NOT pg_catalog.has_function_privilege('service_role', v_function, 'EXECUTE') THEN
            RAISE EXCEPTION 'Payment RPC grants do not match the server-only boundary: %', v_signature;
        END IF;
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_proc p
            CROSS JOIN LATERAL pg_catalog.aclexplode(
                COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))
            ) acl
            WHERE p.oid = v_function
              AND acl.grantee = 0
              AND acl.privilege_type = 'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'PUBLIC can execute payment RPC: %', v_signature;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_index i
        WHERE i.indexrelid = 'private.payment_allocations_membership_purchase_uidx'::pg_catalog.regclass
          AND i.indisunique
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_index i
        WHERE i.indexrelid = 'private.payment_records_pending_membership_uidx'::pg_catalog.regclass
          AND i.indisunique
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_index i
        WHERE i.indexrelid = 'private.payment_records_operation_id_uidx'::pg_catalog.regclass
          AND i.indisunique
    ) THEN
        RAISE EXCEPTION 'Required payment uniqueness constraints/indexes are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = 'private.membership_purchases'::pg_catalog.regclass
          AND tgname = 'membership_purchase_requires_confirmed_payment'
          AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = 'private.payment_events'::pg_catalog.regclass
          AND tgname = 'payment_events_no_update_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Required payment integrity/append-only triggers are missing';
    END IF;
END;
$assertions$;
