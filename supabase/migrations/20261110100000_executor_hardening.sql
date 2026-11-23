-- Forward source migration. Applying this file requires a separately authorized
-- Owner-controlled maintenance window and recovery plan. No cloud is provisioned.
-- Scope: current server-only RPCs; no new business workflow or access period.
-- Derived from the pinned November 6 executor matrix, without native cluster IDs.
-- Provider-owned public/graphql/auth/extension objects are outside this allowlist.
-- No transaction nesting: this file owns one transaction; do not wrap in rollback
-- to simulate a dry run. Use a disposable isolated synthetic database for tests.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-owner-executor-foundation-v1',0));

DO $reserved_roles$
DECLARE role_name text;
BEGIN
    FOREACH role_name IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=role_name) THEN
            EXECUTE pg_catalog.format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',role_name);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=role_name
            AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
            AND NOT rolinherit AND NOT rolreplication AND NOT rolbypassrls) THEN
            RAISE EXCEPTION 'Unsafe existing reserved role %; refusing to change attributes',role_name;
        END IF;
    END LOOP;
    -- Supabase grants freshly created roles to its postgres maintenance role.
    -- Accept only that provider-managed membership, never another role or user.
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles parent ON parent.oid=m.roleid
        JOIN pg_catalog.pg_roles member ON member.oid=m.member
        WHERE (parent.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')
            OR member.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor'))
          AND NOT (parent.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')
            AND member.rolname='postgres')) THEN
        RAISE EXCEPTION 'Unexpected reserved role membership; refusing membership changes';
    END IF;
END;
$reserved_roles$;

LOCK TABLE private.attendance_checkins, private.attendance_validity_resolutions, private.audit_chain_heads, private.audit_events, private.cash_drawer_sessions, private.cash_reconciliation_adjustments, private.cash_reconciliations, private.member_pin_credentials, private.member_pin_setup_tokens, private.members, private.membership_plans, private.membership_purchases, private.owner_access, private.payment_allocations, private.payment_corrections, private.payment_events, private.payment_records, private.pin_attempt_buckets, private.pin_enrollment_global_rate_limit_events, private.walkin_fee_versions, private.walkin_requests, public.gym_settings IN ACCESS EXCLUSIVE MODE;
SET LOCAL gymforce.assertion_profile='current_server_only';
DO $portable_metadata$
DECLARE r record;
BEGIN
    -- A matching body is insufficient when its language or execution metadata drift.
    FOR r IN SELECT * FROM (VALUES
        ('api.append_audit_event(text, uuid, text, text, text, jsonb)','plpgsql','v','u',false,false,false,2),
        ('api.is_active_owner_for_user(uuid)','sql','s','u',false,false,false,0),
        ('api.member_enroll_pin(text, text)','plpgsql','v','u',false,false,false,0),
        ('api.owner_confirm_membership_payment(uuid, uuid, boolean)','plpgsql','v','u',false,false,false,0),
        ('api.owner_create_membership_purchase(uuid, uuid, uuid)','plpgsql','v','u',false,false,false,0),
        ('api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','plpgsql','v','u',false,false,false,0),
        ('api.owner_list_members(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_list_membership_payments(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_list_membership_plans(uuid)','plpgsql','v','u',false,false,false,0),
        ('api.owner_list_membership_purchases(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','plpgsql','v','u',false,false,false,1),
        ('api.owner_register_member(uuid, text, bytea, bytea)','plpgsql','v','u',false,false,false,0),
        ('api.owner_reject_membership_payment(uuid, uuid, text)','plpgsql','v','u',false,false,false,0),
        ('api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','plpgsql','v','u',false,false,false,0),
        ('api.reserve_pin_enrollment_request()','plpgsql','v','u',false,false,false,0),
        ('api.verify_audit_stream(text)','plpgsql','v','u',false,true,false,0),
        ('private.audit_events_chain_insert()','plpgsql','v','u',false,false,false,0),
        ('private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','sql','i','u',false,false,false,0),
        ('private.guard_membership_payment_allocation()','plpgsql','v','u',false,false,false,0),
        ('private.guard_membership_payment_record_insert()','plpgsql','v','u',false,false,false,0),
        ('private.guard_membership_payment_record_update()','plpgsql','v','u',false,false,false,0),
        ('private.guard_purchase_pending_activation()','plpgsql','v','u',false,false,false,0),
        ('private.is_active_owner()','sql','s','u',false,false,false,0),
        ('private.prevent_audit_event_mutation()','plpgsql','v','u',false,false,false,0),
        ('private.prevent_payment_history_mutation()','plpgsql','v','u',false,false,false,0)
    ) v(signature,language,volatility,parallel,expected_strict,expected_returns_set,expected_leakproof,default_count) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_language l ON l.oid=p.prolang
          WHERE p.oid=pg_catalog.to_regprocedure(r.signature) AND p.prokind='f' AND l.lanname=r.language
            AND p.provolatile::text=r.volatility AND p.proparallel::text=r.parallel
            AND p.proisstrict=r.expected_strict AND p.proretset=r.expected_returns_set AND p.proleakproof=r.expected_leakproof
            AND p.pronargdefaults=r.default_count AND p.prosupport=0 AND p.provariadic=0
            AND p.probin IS NULL AND p.prosqlbody IS NULL) THEN
            RAISE EXCEPTION 'Routine execution metadata drift: %',r.signature;
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) AND NOT t.tgisinternal)<>13 THEN
        RAISE EXCEPTION 'Unexpected/missing application trigger';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_rewrite rw JOIN pg_catalog.pg_class c ON c.oid=rw.ev_class
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) THEN
        RAISE EXCEPTION 'Unexpected application rewrite rule/view';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind='S')<>3 THEN
        RAISE EXCEPTION 'Unexpected/missing application sequence';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind NOT IN ('r','i','S','t')) THEN
        RAISE EXCEPTION 'Unexpected private relation kind';
    END IF;
    -- The sole provider dependency granted here must still be pgcrypto's digest.
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_depend d
        ON d.classid='pg_catalog.pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e'
        JOIN pg_catalog.pg_extension e ON e.oid=d.refobjid
        JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace
        WHERE p.oid=pg_catalog.to_regprocedure('extensions.digest(bytea,text)')
          AND e.extname='pgcrypto' AND n.nspname='extensions' AND NOT p.prosecdef
          AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles role_info
            WHERE role_info.oid=p.proowner AND role_info.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor'))) THEN
        RAISE EXCEPTION 'Unreviewed pgcrypto digest dependency';
    END IF;
END;
$portable_metadata$;

DO $phase_assertions$
DECLARE
    profile text := pg_catalog.current_setting('gymforce.assertion_profile',true);
    target boolean;
    r record; caller text; privilege_name text; v_column text; expected boolean;
    routine_oid oid; relation_oid oid; actual_owner text; actual_columns text;
    expected_expr text; actual_qual text; actual_check text; actual_policy record;
BEGIN
    IF profile IN ('historical_phase1','future_attendance') THEN
        RAISE EXCEPTION 'Profile % is not an executable acceptance profile: historical assumptions are archival; future Attendance is unimplemented', profile;
    END IF;
    IF profile IS NULL OR profile NOT IN ('current_server_only','proposed_owner_executor') THEN
        RAISE EXCEPTION 'Select an explicit current_server_only or proposed_owner_executor assertion profile';
    END IF;
    target := profile='proposed_owner_executor';
    -- Reserved roles remain non-login and cannot bypass RLS or assume others.
    FOREACH caller IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=caller
            AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb
            AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication AND NOT rolbypassrls) THEN
            RAISE EXCEPTION 'Unsafe/missing reserved role %',caller;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members e
        JOIN pg_catalog.pg_roles parent ON parent.oid=e.roleid
        JOIN pg_catalog.pg_roles member ON member.oid=e.member
        WHERE (parent.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')
            OR member.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor'))
          AND NOT (parent.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')
            AND member.rolname='postgres')) THEN
        RAISE EXCEPTION 'Unexpected reserved-role membership edge exists';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) AND c.relkind IN ('r','p'))<>22 THEN
        RAISE EXCEPTION 'Application table inventory drift';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='api' AND c.relkind IN ('r','p','v','m','S','f')) THEN
        RAISE EXCEPTION 'API schema unexpectedly contains data relations';
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.attendance_checkins','id:uuid|member_id:uuid|walkin_request_id:uuid|gym_local_date:date|checked_in_at:timestamp with time zone|attendance_status:text'),
        ('private.attendance_validity_resolutions','id:uuid|attendance_id:uuid|prior_status:text|new_status:text|reason:text|resolved_by:uuid|resolved_at:timestamp with time zone'),
        ('private.audit_chain_heads','stream_key:text|last_event_id:bigint|last_event_hash:text|updated_at:timestamp with time zone'),
        ('private.audit_events','id:bigint|actor_user_id:uuid|event_type:text|subject_type:text|subject_id:text|details:jsonb|created_at:timestamp with time zone|stream_key:text|previous_event_hash:text|event_hash:text'),
        ('private.cash_drawer_sessions','id:uuid|opened_at:timestamp with time zone|opened_by:uuid|opening_float_php:numeric(12,2)|session_status:text|closed_at:timestamp with time zone|closed_by:uuid'),
        ('private.cash_reconciliation_adjustments','id:uuid|reconciliation_id:uuid|amount_delta_php:numeric(12,2)|reason:text|evidence_reference:text|recorded_by:uuid|created_at:timestamp with time zone'),
        ('private.cash_reconciliations','id:uuid|drawer_session_id:uuid|expected_cash_php:numeric(12,2)|counted_cash_php:numeric(12,2)|variance_php:numeric(12,2)|reconciled_by:uuid|reconciled_at:timestamp with time zone|notes:text'),
        ('private.member_pin_credentials','member_id:uuid|password_hash:text|credential_version:integer|created_at:timestamp with time zone|updated_at:timestamp with time zone'),
        ('private.member_pin_setup_tokens','id:uuid|member_id:uuid|token_hash:text|token_purpose:text|expires_at:timestamp with time zone|consumed_at:timestamp with time zone|created_at:timestamp with time zone'),
        ('private.members','id:uuid|member_code:text|full_name:text|mobile_lookup_hash:bytea|mobile_encrypted:bytea|status:text|created_at:timestamp with time zone|updated_at:timestamp with time zone|approved_at:timestamp with time zone'),
        ('private.membership_plans','id:uuid|name:text|price_php:numeric(12,2)|is_active:boolean|created_at:timestamp with time zone'),
        ('private.membership_purchases','id:uuid|member_id:uuid|plan_id:uuid|price_php:numeric(12,2)|purchase_status:text|activation_date:date|expiry_date:date|created_at:timestamp with time zone'),
        ('private.owner_access','user_id:uuid|is_active:boolean|created_at:timestamp with time zone|deactivated_at:timestamp with time zone'),
        ('private.payment_allocations','id:uuid|payment_id:uuid|membership_purchase_id:uuid|walkin_request_id:uuid|allocated_by:uuid|allocated_at:timestamp with time zone'),
        ('private.payment_corrections','id:uuid|payment_id:uuid|proposed_amount_php:numeric(12,2)|proposed_payment_method:text|reason:text|evidence_reference:text|correction_status:text|proposed_by:uuid|proposed_at:timestamp with time zone|decided_by:uuid|decided_at:timestamp with time zone|decision_reason:text'),
        ('private.payment_events','id:bigint|payment_id:uuid|event_type:text|reason:text|actor_user_id:uuid|created_at:timestamp with time zone'),
        ('private.payment_records','id:uuid|amount_php:numeric(12,2)|payment_method:text|received_at:timestamp with time zone|verification_status:text|external_reference:text|evidence_reference:text|recorded_by:uuid|created_at:timestamp with time zone|operation_id:uuid|target_membership_purchase_id:uuid'),
        ('private.pin_attempt_buckets','id:uuid|bucket_type:text|identifier_digest:text|window_started_at:timestamp with time zone|failed_attempts:integer|blocked_until:timestamp with time zone|updated_at:timestamp with time zone'),
        ('private.pin_enrollment_global_rate_limit_events','id:bigint|requested_at:timestamp with time zone'),
        ('private.walkin_fee_versions','id:uuid|fee_php:numeric(12,2)|currency:text|effective_from:timestamp with time zone|created_by:uuid|created_at:timestamp with time zone'),
        ('private.walkin_requests','id:uuid|fee_version_id:uuid|fee_php:numeric(12,2)|currency:text|request_status:text|created_at:timestamp with time zone|expires_at:timestamp with time zone|confirmed_by:uuid|confirmed_at:timestamp with time zone'),
        ('public.gym_settings','setting_key:text|setting_value:jsonb|updated_at:timestamp with time zone')
    ) v(name,columns) LOOP
        relation_oid := pg_catalog.to_regclass(r.name);
        IF relation_oid IS NULL THEN RAISE EXCEPTION 'Missing %',r.name; END IF;
        SELECT pg_catalog.string_agg(a.attname||':'||pg_catalog.format_type(a.atttypid,a.atttypmod),'|' ORDER BY a.attnum)
          INTO actual_columns FROM pg_catalog.pg_attribute a
          WHERE a.attrelid=relation_oid AND a.attnum>0 AND NOT a.attisdropped;
        IF actual_columns IS DISTINCT FROM r.columns THEN RAISE EXCEPTION 'Column/type inventory drift: %',r.name; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid=relation_oid AND c.relrowsecurity
             AND c.relowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END)
             AND (NOT target OR c.relforcerowsecurity)) THEN
            RAISE EXCEPTION 'Ownership/RLS mismatch: %',r.name;
        END IF;
        -- No direct browser/service/dormant-login access, including column grants.
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
            IF pg_catalog.has_table_privilege(caller,relation_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
              OR pg_catalog.has_any_column_privilege(caller,relation_oid,'SELECT,INSERT,UPDATE,REFERENCES') THEN
                RAISE EXCEPTION 'Direct protected relation access: % / %',caller,r.name;
            END IF;
        END LOOP;
        FOREACH caller IN ARRAY ARRAY['gym_owner_executor','gym_public_executor'] LOOP
            FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','REFERENCES'] LOOP
                FOR v_column IN SELECT attname FROM pg_catalog.pg_attribute
                    WHERE attrelid=relation_oid AND attnum>0 AND NOT attisdropped LOOP
                    SELECT target AND EXISTS (SELECT 1 FROM (VALUES
                        ('private.owner_access','gym_owner_executor','SELECT','user_id'),
        ('private.owner_access','gym_owner_executor','SELECT','is_active'),
        ('private.owner_access','gym_owner_executor','SELECT','created_at'),
        ('private.owner_access','gym_owner_executor','SELECT','deactivated_at'),
        ('private.members','gym_owner_executor','SELECT','id'),
        ('private.members','gym_owner_executor','SELECT','member_code'),
        ('private.members','gym_owner_executor','SELECT','full_name'),
        ('private.members','gym_owner_executor','SELECT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','SELECT','mobile_encrypted'),
        ('private.members','gym_owner_executor','SELECT','status'),
        ('private.members','gym_owner_executor','SELECT','created_at'),
        ('private.members','gym_owner_executor','SELECT','updated_at'),
        ('private.members','gym_owner_executor','SELECT','approved_at'),
        ('private.members','gym_owner_executor','INSERT','member_code'),
        ('private.members','gym_owner_executor','INSERT','full_name'),
        ('private.members','gym_owner_executor','INSERT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','INSERT','mobile_encrypted'),
        ('private.members','gym_owner_executor','INSERT','status'),
        ('private.members','gym_owner_executor','UPDATE','updated_at'),
        ('private.membership_plans','gym_owner_executor','SELECT','id'),
        ('private.membership_plans','gym_owner_executor','SELECT','name'),
        ('private.membership_plans','gym_owner_executor','SELECT','price_php'),
        ('private.membership_plans','gym_owner_executor','SELECT','is_active'),
        ('private.membership_plans','gym_owner_executor','SELECT','created_at'),
        ('private.membership_plans','gym_owner_executor','INSERT','name'),
        ('private.membership_plans','gym_owner_executor','INSERT','price_php'),
        ('private.membership_plans','gym_owner_executor','INSERT','is_active'),
        ('private.membership_plans','gym_owner_executor','UPDATE','name'),
        ('private.membership_plans','gym_owner_executor','UPDATE','price_php'),
        ('private.membership_plans','gym_owner_executor','UPDATE','is_active'),
        ('private.membership_purchases','gym_owner_executor','SELECT','id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','member_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','price_php'),
        ('private.membership_purchases','gym_owner_executor','SELECT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','SELECT','activation_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','expiry_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','created_at'),
        ('private.membership_purchases','gym_owner_executor','INSERT','member_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','price_php'),
        ('private.membership_purchases','gym_owner_executor','INSERT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','purchase_status'),
        ('private.payment_records','gym_owner_executor','SELECT','id'),
        ('private.payment_records','gym_owner_executor','SELECT','amount_php'),
        ('private.payment_records','gym_owner_executor','SELECT','payment_method'),
        ('private.payment_records','gym_owner_executor','SELECT','received_at'),
        ('private.payment_records','gym_owner_executor','SELECT','verification_status'),
        ('private.payment_records','gym_owner_executor','SELECT','external_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','evidence_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','recorded_by'),
        ('private.payment_records','gym_owner_executor','SELECT','created_at'),
        ('private.payment_records','gym_owner_executor','SELECT','operation_id'),
        ('private.payment_records','gym_owner_executor','SELECT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','INSERT','amount_php'),
        ('private.payment_records','gym_owner_executor','INSERT','payment_method'),
        ('private.payment_records','gym_owner_executor','INSERT','verification_status'),
        ('private.payment_records','gym_owner_executor','INSERT','external_reference'),
        ('private.payment_records','gym_owner_executor','INSERT','recorded_by'),
        ('private.payment_records','gym_owner_executor','INSERT','operation_id'),
        ('private.payment_records','gym_owner_executor','INSERT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','UPDATE','verification_status'),
        ('private.payment_allocations','gym_owner_executor','SELECT','id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','walkin_request_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_by'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_at'),
        ('private.payment_allocations','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','allocated_by'),
        ('private.payment_events','gym_owner_executor','SELECT','id'),
        ('private.payment_events','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_events','gym_owner_executor','SELECT','event_type'),
        ('private.payment_events','gym_owner_executor','SELECT','reason'),
        ('private.payment_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.payment_events','gym_owner_executor','SELECT','created_at'),
        ('private.payment_events','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_events','gym_owner_executor','INSERT','event_type'),
        ('private.payment_events','gym_owner_executor','INSERT','reason'),
        ('private.payment_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','id'),
        ('private.audit_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','event_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_id'),
        ('private.audit_events','gym_owner_executor','SELECT','details'),
        ('private.audit_events','gym_owner_executor','SELECT','created_at'),
        ('private.audit_events','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_events','gym_owner_executor','SELECT','previous_event_hash'),
        ('private.audit_events','gym_owner_executor','SELECT','event_hash'),
        ('private.audit_events','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','INSERT','event_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_id'),
        ('private.audit_events','gym_owner_executor','INSERT','details'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','updated_at'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','created_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','consumed_at'),
        ('private.members','gym_public_executor','SELECT','id'),
        ('private.members','gym_public_executor','SELECT','status'),
        ('private.members','gym_public_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','consumed_at'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','password_hash'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','credential_version'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','created_at'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','updated_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','requested_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','requested_at')
                    ) g(table_name,role_name,command,column_name)
                    WHERE g.table_name=r.name AND g.role_name=caller
                      AND g.command=privilege_name AND g.column_name=v_column)
                    INTO expected;
                    IF pg_catalog.has_column_privilege(caller,relation_oid,v_column,privilege_name) IS DISTINCT FROM expected THEN
                        RAISE EXCEPTION 'Column ACL mismatch: %.% / % / %',r.name,v_column,caller,privilege_name;
                    END IF;
                END LOOP;
            END LOOP;
            IF pg_catalog.has_table_privilege(caller,relation_oid,'TRUNCATE,REFERENCES,TRIGGER')
               OR pg_catalog.has_table_privilege(caller,relation_oid,'DELETE') IS DISTINCT FROM
                 (target AND caller='gym_public_executor' AND r.name='private.pin_enrollment_global_rate_limit_events') THEN
                RAISE EXCEPTION 'Unexpected table-wide destructive privilege: % / %',caller,r.name;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c,
            LATERAL pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault('r',c.relowner))) a
            WHERE c.oid=relation_oid AND a.grantee<>c.relowner
            AND NOT (target AND r.name='private.pin_enrollment_global_rate_limit_events'
                     AND a.grantee=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_public_executor')
                     AND a.privilege_type='DELETE' AND NOT a.is_grantable)) THEN
            RAISE EXCEPTION 'Unreviewed relation ACL principal/grant: %',r.name;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_attribute col,
            LATERAL pg_catalog.aclexplode(col.attacl) a
            WHERE col.attrelid=relation_oid AND col.attnum>0
              AND a.grantee<>(SELECT relowner FROM pg_catalog.pg_class WHERE oid=relation_oid)
              AND (a.is_grantable OR NOT (target AND EXISTS (SELECT 1 FROM (VALUES
                  ('private.owner_access','gym_owner_executor','SELECT','user_id'),
        ('private.owner_access','gym_owner_executor','SELECT','is_active'),
        ('private.owner_access','gym_owner_executor','SELECT','created_at'),
        ('private.owner_access','gym_owner_executor','SELECT','deactivated_at'),
        ('private.members','gym_owner_executor','SELECT','id'),
        ('private.members','gym_owner_executor','SELECT','member_code'),
        ('private.members','gym_owner_executor','SELECT','full_name'),
        ('private.members','gym_owner_executor','SELECT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','SELECT','mobile_encrypted'),
        ('private.members','gym_owner_executor','SELECT','status'),
        ('private.members','gym_owner_executor','SELECT','created_at'),
        ('private.members','gym_owner_executor','SELECT','updated_at'),
        ('private.members','gym_owner_executor','SELECT','approved_at'),
        ('private.members','gym_owner_executor','INSERT','member_code'),
        ('private.members','gym_owner_executor','INSERT','full_name'),
        ('private.members','gym_owner_executor','INSERT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','INSERT','mobile_encrypted'),
        ('private.members','gym_owner_executor','INSERT','status'),
        ('private.members','gym_owner_executor','UPDATE','updated_at'),
        ('private.membership_plans','gym_owner_executor','SELECT','id'),
        ('private.membership_plans','gym_owner_executor','SELECT','name'),
        ('private.membership_plans','gym_owner_executor','SELECT','price_php'),
        ('private.membership_plans','gym_owner_executor','SELECT','is_active'),
        ('private.membership_plans','gym_owner_executor','SELECT','created_at'),
        ('private.membership_plans','gym_owner_executor','INSERT','name'),
        ('private.membership_plans','gym_owner_executor','INSERT','price_php'),
        ('private.membership_plans','gym_owner_executor','INSERT','is_active'),
        ('private.membership_plans','gym_owner_executor','UPDATE','name'),
        ('private.membership_plans','gym_owner_executor','UPDATE','price_php'),
        ('private.membership_plans','gym_owner_executor','UPDATE','is_active'),
        ('private.membership_purchases','gym_owner_executor','SELECT','id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','member_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','price_php'),
        ('private.membership_purchases','gym_owner_executor','SELECT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','SELECT','activation_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','expiry_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','created_at'),
        ('private.membership_purchases','gym_owner_executor','INSERT','member_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','price_php'),
        ('private.membership_purchases','gym_owner_executor','INSERT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','purchase_status'),
        ('private.payment_records','gym_owner_executor','SELECT','id'),
        ('private.payment_records','gym_owner_executor','SELECT','amount_php'),
        ('private.payment_records','gym_owner_executor','SELECT','payment_method'),
        ('private.payment_records','gym_owner_executor','SELECT','received_at'),
        ('private.payment_records','gym_owner_executor','SELECT','verification_status'),
        ('private.payment_records','gym_owner_executor','SELECT','external_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','evidence_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','recorded_by'),
        ('private.payment_records','gym_owner_executor','SELECT','created_at'),
        ('private.payment_records','gym_owner_executor','SELECT','operation_id'),
        ('private.payment_records','gym_owner_executor','SELECT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','INSERT','amount_php'),
        ('private.payment_records','gym_owner_executor','INSERT','payment_method'),
        ('private.payment_records','gym_owner_executor','INSERT','verification_status'),
        ('private.payment_records','gym_owner_executor','INSERT','external_reference'),
        ('private.payment_records','gym_owner_executor','INSERT','recorded_by'),
        ('private.payment_records','gym_owner_executor','INSERT','operation_id'),
        ('private.payment_records','gym_owner_executor','INSERT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','UPDATE','verification_status'),
        ('private.payment_allocations','gym_owner_executor','SELECT','id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','walkin_request_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_by'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_at'),
        ('private.payment_allocations','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','allocated_by'),
        ('private.payment_events','gym_owner_executor','SELECT','id'),
        ('private.payment_events','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_events','gym_owner_executor','SELECT','event_type'),
        ('private.payment_events','gym_owner_executor','SELECT','reason'),
        ('private.payment_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.payment_events','gym_owner_executor','SELECT','created_at'),
        ('private.payment_events','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_events','gym_owner_executor','INSERT','event_type'),
        ('private.payment_events','gym_owner_executor','INSERT','reason'),
        ('private.payment_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','id'),
        ('private.audit_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','event_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_id'),
        ('private.audit_events','gym_owner_executor','SELECT','details'),
        ('private.audit_events','gym_owner_executor','SELECT','created_at'),
        ('private.audit_events','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_events','gym_owner_executor','SELECT','previous_event_hash'),
        ('private.audit_events','gym_owner_executor','SELECT','event_hash'),
        ('private.audit_events','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','INSERT','event_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_id'),
        ('private.audit_events','gym_owner_executor','INSERT','details'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','updated_at'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','created_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','consumed_at'),
        ('private.members','gym_public_executor','SELECT','id'),
        ('private.members','gym_public_executor','SELECT','status'),
        ('private.members','gym_public_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','consumed_at'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','password_hash'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','credential_version'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','created_at'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','updated_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','requested_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','requested_at')
              ) g(table_name,role_name,command,column_name)
              JOIN pg_catalog.pg_roles rr ON rr.rolname=g.role_name
              WHERE g.table_name=r.name AND g.column_name=col.attname
                AND rr.oid=a.grantee AND g.command=a.privilege_type)))) THEN
            RAISE EXCEPTION 'Unreviewed column ACL principal/grant: %',r.name;
        END IF;
    END LOOP;
    IF NOT target AND EXISTS (SELECT 1 FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings'))) THEN
        RAISE EXCEPTION 'Current profile policy inventory changed';
    END IF;
    IF target THEN
        IF (SELECT count(*) FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
            JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')))<>34 THEN
            RAISE EXCEPTION 'Policy count drift';
        END IF;
        FOR r IN SELECT * FROM (VALUES
            ('private.owner_access','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.members','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.members','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.members','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.membership_plans','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.membership_plans','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.membership_plans','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.membership_purchases','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.membership_purchases','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.payment_records','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_records','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.payment_records','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.payment_allocations','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_allocations','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.payment_events','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_events','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_events','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.audit_events','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.members','gym_public_executor','SELECT','gf_public_select'),
        ('private.members','gym_public_executor','UPDATE','gf_public_update'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','gf_public_select'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','gf_public_update'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','gf_public_select'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','gf_public_insert'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','gf_public_select'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','gf_public_insert'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','DELETE','gf_public_delete')
        ) v(table_name,role_name,command,policy_name) LOOP
            SELECT * INTO actual_policy FROM pg_catalog.pg_policy
              WHERE polrelid=pg_catalog.to_regclass(r.table_name) AND polname=r.policy_name;
            IF NOT FOUND OR NOT actual_policy.polpermissive
               OR actual_policy.polroles IS DISTINCT FROM ARRAY[(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=r.role_name)]
               OR actual_policy.polcmd::text IS DISTINCT FROM (CASE r.command WHEN 'SELECT' THEN 'r' WHEN 'INSERT' THEN 'a' WHEN 'UPDATE' THEN 'w' WHEN 'DELETE' THEN 'd' END) THEN
                RAISE EXCEPTION 'Role/command policy mismatch: % / %',r.table_name,r.policy_name;
            END IF;
            expected_expr := 'current_user='||quote_literal(r.role_name)||'::name';
            actual_qual := lower(regexp_replace(pg_catalog.pg_get_expr(actual_policy.polqual,actual_policy.polrelid),'[[:space:]()]','','g'));
            actual_check := lower(regexp_replace(pg_catalog.pg_get_expr(actual_policy.polwithcheck,actual_policy.polrelid),'[[:space:]()]','','g'));
            IF (r.command IN ('SELECT','UPDATE','DELETE') AND actual_qual IS DISTINCT FROM expected_expr)
               OR (r.command='INSERT' AND actual_qual IS NOT NULL)
               OR (r.command IN ('INSERT','UPDATE') AND actual_check IS DISTINCT FROM expected_expr)
               OR (r.command IN ('SELECT','DELETE') AND actual_check IS NOT NULL) THEN
                RAISE EXCEPTION 'Policy predicate mismatch: % / %',r.table_name,r.policy_name;
            END IF;
        END LOOP;
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.audit_events_id_seq','gym_owner_executor'),
        ('private.payment_events_id_seq','gym_owner_executor'),
        ('private.pin_enrollment_global_rate_limit_events_id_seq','gym_public_executor')
    ) v(name,executor) LOOP
        relation_oid := pg_catalog.to_regclass(r.name);
        IF relation_oid IS NULL OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
            WHERE c.oid=relation_oid AND c.relkind='S' AND c.relowner=(SELECT oid FROM pg_catalog.pg_roles
            WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END)) THEN
            RAISE EXCEPTION 'Sequence ownership mismatch: %',r.name;
        END IF;
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
            IF pg_catalog.has_sequence_privilege(caller,relation_oid,'SELECT,UPDATE')
               OR pg_catalog.has_sequence_privilege(caller,relation_oid,'USAGE') THEN
                RAISE EXCEPTION 'Sequence ACL mismatch: % / %',r.name,caller;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c,
            LATERAL pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault('S',c.relowner))) a
            WHERE c.oid=relation_oid AND a.grantee<>c.relowner) THEN
            RAISE EXCEPTION 'Unreviewed sequence ACL: %',r.name;
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname IN ('private','api'))<>25 THEN RAISE EXCEPTION 'Routine inventory drift'; END IF;
    FOR r IN SELECT * FROM (VALUES
        ('api.append_audit_event(text, uuid, text, text, text, jsonb)','7a05ca54592137c75b9adda7023516a8','gym_owner_executor','true','true','service_role,gym_public_executor'),
        ('api.is_active_owner_for_user(uuid)','830f29066e37d9f2593c3cd99878ae93','gym_owner_executor','true','true','service_role'),
        ('api.member_enroll_pin(text, text)','6bf1d4a963b2b853ba9cdc7cb582c342','gym_public_executor','true','true','service_role'),
        ('api.owner_confirm_membership_payment(uuid, uuid, boolean)','ce58f4473d75469ef2676f232794dce0','gym_owner_executor','true','true','service_role'),
        ('api.owner_create_membership_purchase(uuid, uuid, uuid)','f8f310bd5576274401706c5213c6746d','gym_owner_executor','true','true','service_role'),
        ('api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','7a226978d83e191643a436c829f9dd07','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_members(uuid, text, text, integer, integer)','342dd9a2131e068c1a849694b053ebdf','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_payments(uuid, text, text, integer, integer)','6ac0d61dfc24c15123812ec788294197','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_plans(uuid)','fc3ed2be2834b6458f2835bfc18d9b4e','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_purchases(uuid, text, text, integer, integer)','d6fd6f1ba099afe317dcf1606d49d64f','gym_owner_executor','true','true','service_role'),
        ('api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','c21766acb601a8b92dc26d59f73be2a3','gym_owner_executor','true','true','service_role'),
        ('api.owner_register_member(uuid, text, bytea, bytea)','e56b20e809c8dfcebd782d4e8aa5fbb5','gym_owner_executor','true','true','service_role'),
        ('api.owner_reject_membership_payment(uuid, uuid, text)','b55e7879cbae6d9074264826ed75eac0','gym_owner_executor','true','true','service_role'),
        ('api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','c128144cda372362b26ec91dc64fd6fa','gym_owner_executor','true','true','service_role'),
        ('api.reserve_pin_enrollment_request()','ed1a67d4a3cd30fed31a0ee36222eb5b','gym_public_executor','true','true','service_role'),
        ('api.verify_audit_stream(text)','f7c5cdb53ec4cf2d845e38f404df5fb9','gym_owner_executor','true','true','service_role'),
        ('private.audit_events_chain_insert()','6fa6a434395de93250213752513ffb34','gym_data_owner','false','true','gym_owner_executor'),
        ('private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','a0635caf0c329b24571bd68df684f69f','gym_data_owner','false','false','gym_owner_executor'),
        ('private.guard_membership_payment_allocation()','4836529309d8c518d42d24b9d191d6d5','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_membership_payment_record_insert()','edaae9f3a89330d4e55ce37d7d16d074','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_membership_payment_record_update()','9386192bae0b7aec6e34fce2e2aadbda','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_purchase_pending_activation()','c3467a65c399cf75243d4e3e9e31b36c','gym_data_owner','false','true','gym_owner_executor'),
        ('private.is_active_owner()','76af3203b0fe03c30e1eb6d8264a04e6','gym_data_owner','false','false',''),
        ('private.prevent_audit_event_mutation()','d835b9b2db211d2439e03ec9d8a6337d','gym_data_owner','false','true','gym_owner_executor'),
        ('private.prevent_payment_history_mutation()','0ad4feeac81403c334c6665ff018485e','gym_data_owner','false','true','gym_owner_executor')
    ) v(signature,body_md5,target_owner,target_definer,baseline_definer,callers) LOOP
        routine_oid := pg_catalog.to_regprocedure(r.signature);
        IF routine_oid IS NULL OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
            WHERE p.oid=routine_oid AND md5(p.prosrc)=r.body_md5
              AND p.proowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN r.target_owner ELSE 'postgres' END)
              AND p.prosecdef=CASE WHEN target THEN r.target_definer::boolean ELSE r.baseline_definer::boolean END
              AND p.proconfig=ARRAY['search_path=""']::text[]) THEN
            RAISE EXCEPTION 'Routine body/owner/execution/config mismatch: %',r.signature;
        END IF;
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
            expected := CASE WHEN target THEN caller=r.target_owner OR caller=ANY(string_to_array(r.callers,','))
                             ELSE caller='service_role' AND r.signature LIKE 'api.%' END;
            IF pg_catalog.has_function_privilege(caller,routine_oid,'EXECUTE') IS DISTINCT FROM expected THEN
                RAISE EXCEPTION 'Routine execute mismatch: % / %',r.signature,caller;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p,
            LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
            WHERE p.oid=routine_oid AND (a.is_grantable AND a.grantee<>p.proowner OR
              a.grantee<>p.proowner AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles rr
                WHERE rr.oid=a.grantee AND rr.rolname=ANY(CASE WHEN target THEN string_to_array(r.callers,',')
                ELSE CASE WHEN r.signature LIKE 'api.%' THEN ARRAY['service_role'] ELSE ARRAY[]::text[] END END)))) THEN
            RAISE EXCEPTION 'PUBLIC/unreviewed routine grantee: %',r.signature;
        END IF;
    END LOOP;
    FOREACH caller IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF pg_catalog.has_schema_privilege(caller,'private','USAGE,CREATE')
           OR pg_catalog.has_schema_privilege(caller,'api','USAGE,CREATE') THEN
            RAISE EXCEPTION 'Browser/dormant schema exposure: %',caller;
        END IF;
    END LOOP;
    IF pg_catalog.has_schema_privilege('service_role','private','USAGE,CREATE')
       OR NOT pg_catalog.has_schema_privilege('service_role','api','USAGE')
       OR pg_catalog.has_schema_privilege('service_role','api','CREATE') THEN
        RAISE EXCEPTION 'Service-role schema boundary mismatch';
    END IF;
    FOREACH caller IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF pg_catalog.has_schema_privilege(caller,'private','CREATE')
           OR pg_catalog.has_schema_privilege(caller,'api','CREATE')
           OR pg_catalog.has_schema_privilege(caller,'public','CREATE') THEN
            RAISE EXCEPTION 'Reserved role has schema CREATE: %',caller;
        END IF;
        IF pg_catalog.has_schema_privilege(caller,'private','USAGE') IS DISTINCT FROM target THEN
            RAISE EXCEPTION 'Reserved private schema USAGE mismatch: %',caller;
        END IF;
        IF pg_catalog.has_schema_privilege(caller,'api','USAGE') IS DISTINCT FROM
           (target AND caller IN ('gym_owner_executor','gym_public_executor')) THEN
            RAISE EXCEPTION 'Reserved API schema USAGE mismatch: %',caller;
        END IF;
    END LOOP;
    IF target AND (NOT pg_catalog.has_schema_privilege('gym_owner_executor','extensions','USAGE')
       OR NOT pg_catalog.has_function_privilege('gym_owner_executor','extensions.digest(bytea,text)','EXECUTE')) THEN
        RAISE EXCEPTION 'Audit digest dependency unavailable to Owner executor';
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.audit_events','audit_events_chain_insert_trigger','CREATE TRIGGER audit_events_chain_insert_trigger BEFORE INSERT ON private.audit_events FOR EACH ROW EXECUTE FUNCTION private.audit_events_chain_insert()'),
        ('private.audit_events','audit_events_no_truncate','CREATE TRIGGER audit_events_no_truncate BEFORE TRUNCATE ON private.audit_events FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_audit_event_mutation()'),
        ('private.audit_events','audit_events_no_update_delete','CREATE TRIGGER audit_events_no_update_delete BEFORE DELETE OR UPDATE ON private.audit_events FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_event_mutation()'),
        ('private.membership_purchases','membership_purchase_requires_confirmed_payment','CREATE TRIGGER membership_purchase_requires_confirmed_payment BEFORE INSERT OR UPDATE ON private.membership_purchases FOR EACH ROW EXECUTE FUNCTION private.guard_purchase_pending_activation()'),
        ('private.payment_allocations','payment_allocations_no_truncate','CREATE TRIGGER payment_allocations_no_truncate BEFORE TRUNCATE ON private.payment_allocations FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_allocations','payment_allocations_no_update_delete','CREATE TRIGGER payment_allocations_no_update_delete BEFORE DELETE OR UPDATE ON private.payment_allocations FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_allocations','payment_allocations_validate_membership','CREATE TRIGGER payment_allocations_validate_membership BEFORE INSERT ON private.payment_allocations FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_allocation()'),
        ('private.payment_events','payment_events_no_truncate','CREATE TRIGGER payment_events_no_truncate BEFORE TRUNCATE ON private.payment_events FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_events','payment_events_no_update_delete','CREATE TRIGGER payment_events_no_update_delete BEFORE DELETE OR UPDATE ON private.payment_events FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_guard_update','CREATE TRIGGER payment_records_guard_update BEFORE UPDATE ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_record_update()'),
        ('private.payment_records','payment_records_no_delete','CREATE TRIGGER payment_records_no_delete BEFORE DELETE ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_no_truncate','CREATE TRIGGER payment_records_no_truncate BEFORE TRUNCATE ON private.payment_records FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_validate_membership_insert','CREATE TRIGGER payment_records_validate_membership_insert BEFORE INSERT ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_record_insert()')
    ) v(table_name,name,definition) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger t WHERE t.tgrelid=pg_catalog.to_regclass(r.table_name)
            AND t.tgname=r.name AND t.tgenabled='O' AND pg_catalog.pg_get_triggerdef(t.oid)=r.definition) THEN
            RAISE EXCEPTION 'Trigger definition/state drift: %.%',r.table_name,r.name;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS profile %: catalog checks only; executor mutation/concurrency acceptance remains a separate required gate',profile;
    IF NOT target THEN
        RAISE WARNING 'Ownership/executor hardening remains unsatisfied in current_server_only profile';
    END IF;
END;
$phase_assertions$;
DO $dependency_assertions$
DECLARE r record; target boolean := current_setting('gymforce.assertion_profile')='proposed_owner_executor'; expected_owner oid;
BEGIN
    SELECT oid INTO expected_owner FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.audit_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.audit_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.audit_events_id_seq'; END IF;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.payment_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.payment_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.payment_events_id_seq'; END IF;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.pin_enrollment_global_rate_limit_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.pin_enrollment_global_rate_limit_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.pin_enrollment_global_rate_limit_events_id_seq'; END IF;
    FOR r IN SELECT * FROM (VALUES
        ('index','private.attendance_checkins_pkey','private.attendance_checkins'),
        ('index','private.attendance_date_idx','private.attendance_checkins'),
        ('index','private.attendance_member_date_idx','private.attendance_checkins'),
        ('index','private.attendance_one_checkin_per_walkin','private.attendance_checkins'),
        ('index','private.attendance_one_member_valid_checkin_per_day','private.attendance_checkins'),
        ('index','private.attendance_validity_resolutions_pkey','private.attendance_validity_resolutions'),
        ('index','private.audit_chain_heads_pkey','private.audit_chain_heads'),
        ('index','private.audit_events_actor_created_idx','private.audit_events'),
        ('index','private.audit_events_created_at_idx','private.audit_events'),
        ('index','private.audit_events_pkey','private.audit_events'),
        ('index','private.audit_events_stream_created_idx','private.audit_events'),
        ('index','private.cash_adjustments_reconciliation_idx','private.cash_reconciliation_adjustments'),
        ('index','private.cash_drawer_only_one_open_session','private.cash_drawer_sessions'),
        ('index','private.cash_drawer_sessions_pkey','private.cash_drawer_sessions'),
        ('index','private.cash_reconciliation_adjustments_pkey','private.cash_reconciliation_adjustments'),
        ('index','private.cash_reconciliations_date_idx','private.cash_reconciliations'),
        ('index','private.cash_reconciliations_drawer_session_id_key','private.cash_reconciliations'),
        ('index','private.cash_reconciliations_pkey','private.cash_reconciliations'),
        ('index','private.member_pin_credentials_pkey','private.member_pin_credentials'),
        ('index','private.member_pin_setup_tokens_active_enrollment_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_expiry_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_member_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_pkey','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_token_hash_key','private.member_pin_setup_tokens'),
        ('index','private.members_member_code_key','private.members'),
        ('index','private.members_mobile_lookup_hash_key','private.members'),
        ('index','private.members_pkey','private.members'),
        ('index','private.members_status_idx','private.members'),
        ('index','private.membership_plans_normalized_name_uidx','private.membership_plans'),
        ('index','private.membership_plans_pkey','private.membership_plans'),
        ('index','private.membership_purchases_member_idx','private.membership_purchases'),
        ('index','private.membership_purchases_no_overlapping_periods','private.membership_purchases'),
        ('index','private.membership_purchases_pkey','private.membership_purchases'),
        ('index','private.membership_purchases_plan_idx','private.membership_purchases'),
        ('index','private.owner_access_pkey','private.owner_access'),
        ('index','private.payment_allocations_membership_idx','private.payment_allocations'),
        ('index','private.payment_allocations_membership_purchase_uidx','private.payment_allocations'),
        ('index','private.payment_allocations_payment_id_key','private.payment_allocations'),
        ('index','private.payment_allocations_pkey','private.payment_allocations'),
        ('index','private.payment_allocations_walkin_idx','private.payment_allocations'),
        ('index','private.payment_corrections_payment_idx','private.payment_corrections'),
        ('index','private.payment_corrections_pkey','private.payment_corrections'),
        ('index','private.payment_events_payment_created_idx','private.payment_events'),
        ('index','private.payment_events_pkey','private.payment_events'),
        ('index','private.payment_records_membership_external_reference_uidx','private.payment_records'),
        ('index','private.payment_records_membership_idx','private.payment_records'),
        ('index','private.payment_records_operation_id_uidx','private.payment_records'),
        ('index','private.payment_records_pending_membership_uidx','private.payment_records'),
        ('index','private.payment_records_pkey','private.payment_records'),
        ('index','private.pin_attempt_buckets_blocked_idx','private.pin_attempt_buckets'),
        ('index','private.pin_attempt_buckets_pkey','private.pin_attempt_buckets'),
        ('index','private.pin_bucket_unique_window','private.pin_attempt_buckets'),
        ('index','private.pin_enrollment_global_rate_limit_events_pkey','private.pin_enrollment_global_rate_limit_events'),
        ('index','private.pin_enrollment_global_rate_limit_events_requested_at_idx','private.pin_enrollment_global_rate_limit_events'),
        ('index','private.walkin_fee_versions_pkey','private.walkin_fee_versions'),
        ('index','private.walkin_requests_pkey','private.walkin_requests'),
        ('index','public.gym_settings_pkey','public.gym_settings'),
        ('type','private._attendance_checkins','private.attendance_checkins'),
        ('type','private._attendance_validity_resolutions','private.attendance_validity_resolutions'),
        ('type','private._audit_chain_heads','private.audit_chain_heads'),
        ('type','private._audit_events','private.audit_events'),
        ('type','private._cash_drawer_sessions','private.cash_drawer_sessions'),
        ('type','private._cash_reconciliation_adjustments','private.cash_reconciliation_adjustments'),
        ('type','private._cash_reconciliations','private.cash_reconciliations'),
        ('type','private._member_pin_credentials','private.member_pin_credentials'),
        ('type','private._member_pin_setup_tokens','private.member_pin_setup_tokens'),
        ('type','private._members','private.members'),
        ('type','private._membership_plans','private.membership_plans'),
        ('type','private._membership_purchases','private.membership_purchases'),
        ('type','private._owner_access','private.owner_access'),
        ('type','private._payment_allocations','private.payment_allocations'),
        ('type','private._payment_corrections','private.payment_corrections'),
        ('type','private._payment_events','private.payment_events'),
        ('type','private._payment_records','private.payment_records'),
        ('type','private._pin_attempt_buckets','private.pin_attempt_buckets'),
        ('type','private._pin_enrollment_global_rate_limit_events','private.pin_enrollment_global_rate_limit_events'),
        ('type','private._walkin_fee_versions','private.walkin_fee_versions'),
        ('type','private._walkin_requests','private.walkin_requests'),
        ('type','private.attendance_checkins','private.attendance_checkins'),
        ('type','private.attendance_validity_resolutions','private.attendance_validity_resolutions'),
        ('type','private.audit_chain_heads','private.audit_chain_heads'),
        ('type','private.audit_events','private.audit_events'),
        ('type','private.cash_drawer_sessions','private.cash_drawer_sessions'),
        ('type','private.cash_reconciliation_adjustments','private.cash_reconciliation_adjustments'),
        ('type','private.cash_reconciliations','private.cash_reconciliations'),
        ('type','private.member_pin_credentials','private.member_pin_credentials'),
        ('type','private.member_pin_setup_tokens','private.member_pin_setup_tokens'),
        ('type','private.members','private.members'),
        ('type','private.membership_plans','private.membership_plans'),
        ('type','private.membership_purchases','private.membership_purchases'),
        ('type','private.owner_access','private.owner_access'),
        ('type','private.payment_allocations','private.payment_allocations'),
        ('type','private.payment_corrections','private.payment_corrections'),
        ('type','private.payment_events','private.payment_events'),
        ('type','private.payment_records','private.payment_records'),
        ('type','private.pin_attempt_buckets','private.pin_attempt_buckets'),
        ('type','private.pin_enrollment_global_rate_limit_events','private.pin_enrollment_global_rate_limit_events'),
        ('type','private.walkin_fee_versions','private.walkin_fee_versions'),
        ('type','private.walkin_requests','private.walkin_requests'),
        ('type','public._gym_settings','public.gym_settings'),
        ('type','public.gym_settings','public.gym_settings')
    ) v(kind,name,parent) LOOP
        IF r.kind='index' AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_index i ON i.indexrelid=c.oid WHERE c.oid=pg_catalog.to_regclass(r.name)
              AND i.indrelid=pg_catalog.to_regclass(r.parent) AND c.relowner=expected_owner
              AND i.indisvalid AND i.indisready) THEN
            RAISE EXCEPTION 'Dependent index owner/binding/validity mismatch: %',r.name;
        ELSIF r.kind='type' AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type t
            JOIN pg_catalog.pg_class c ON c.oid=pg_catalog.to_regclass(r.parent)
            JOIN pg_catalog.pg_type base ON base.oid=c.reltype
            WHERE t.oid=pg_catalog.to_regtype(r.name) AND (t.oid=base.oid OR t.oid=base.typarray)
              AND t.typowner=expected_owner) THEN
            RAISE EXCEPTION 'Dependent type owner/binding mismatch: %',r.name;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_namespace n ON n.oid=c.connamespace
       WHERE (n.nspname='private' OR c.conrelid=pg_catalog.to_regclass('public.gym_settings')) AND NOT c.convalidated) THEN
        RAISE EXCEPTION 'Unvalidated application constraint';
    END IF;
END;
$dependency_assertions$;

-- Explicit object allowlist. Index/constraint and identity dependencies follow
-- table ownership. No REASSIGN OWNED or changes to Auth/extension ownership.
ALTER TABLE private.attendance_checkins OWNER TO gym_data_owner;
ALTER TABLE private.attendance_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.attendance_checkins FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.attendance_checkins FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.attendance_validity_resolutions OWNER TO gym_data_owner;
ALTER TABLE private.attendance_validity_resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.attendance_validity_resolutions FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.attendance_validity_resolutions FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.audit_chain_heads OWNER TO gym_data_owner;
ALTER TABLE private.audit_chain_heads ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.audit_chain_heads FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.audit_chain_heads FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.audit_events OWNER TO gym_data_owner;
ALTER TABLE private.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.audit_events FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.audit_events FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.cash_drawer_sessions OWNER TO gym_data_owner;
ALTER TABLE private.cash_drawer_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cash_drawer_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.cash_drawer_sessions FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.cash_reconciliation_adjustments OWNER TO gym_data_owner;
ALTER TABLE private.cash_reconciliation_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cash_reconciliation_adjustments FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.cash_reconciliation_adjustments FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.cash_reconciliations OWNER TO gym_data_owner;
ALTER TABLE private.cash_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cash_reconciliations FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.cash_reconciliations FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.member_pin_credentials OWNER TO gym_data_owner;
ALTER TABLE private.member_pin_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.member_pin_credentials FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.member_pin_credentials FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.member_pin_setup_tokens OWNER TO gym_data_owner;
ALTER TABLE private.member_pin_setup_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.member_pin_setup_tokens FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.member_pin_setup_tokens FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.members OWNER TO gym_data_owner;
ALTER TABLE private.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.members FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.members FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.membership_plans OWNER TO gym_data_owner;
ALTER TABLE private.membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.membership_plans FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.membership_plans FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.membership_purchases OWNER TO gym_data_owner;
ALTER TABLE private.membership_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.membership_purchases FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.membership_purchases FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.owner_access OWNER TO gym_data_owner;
ALTER TABLE private.owner_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.owner_access FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.owner_access FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.payment_allocations OWNER TO gym_data_owner;
ALTER TABLE private.payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.payment_allocations FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.payment_allocations FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.payment_corrections OWNER TO gym_data_owner;
ALTER TABLE private.payment_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.payment_corrections FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.payment_corrections FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.payment_events OWNER TO gym_data_owner;
ALTER TABLE private.payment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.payment_events FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.payment_events FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.payment_records OWNER TO gym_data_owner;
ALTER TABLE private.payment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.payment_records FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.payment_records FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.pin_attempt_buckets OWNER TO gym_data_owner;
ALTER TABLE private.pin_attempt_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.pin_attempt_buckets FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.pin_attempt_buckets FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.pin_enrollment_global_rate_limit_events OWNER TO gym_data_owner;
ALTER TABLE private.pin_enrollment_global_rate_limit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.pin_enrollment_global_rate_limit_events FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.pin_enrollment_global_rate_limit_events FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.walkin_fee_versions OWNER TO gym_data_owner;
ALTER TABLE private.walkin_fee_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.walkin_fee_versions FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.walkin_fee_versions FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE private.walkin_requests OWNER TO gym_data_owner;
ALTER TABLE private.walkin_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.walkin_requests FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE private.walkin_requests FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
ALTER TABLE public.gym_settings OWNER TO gym_data_owner;
ALTER TABLE public.gym_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.gym_settings FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
-- Identity sequence private.audit_events_id_seq ownership follows its parent table; checked below.
REVOKE ALL PRIVILEGES ON SEQUENCE private.audit_events_id_seq FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
-- Identity sequence private.payment_events_id_seq ownership follows its parent table; checked below.
REVOKE ALL PRIVILEGES ON SEQUENCE private.payment_events_id_seq FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
-- Identity sequence private.pin_enrollment_global_rate_limit_events_id_seq ownership follows its parent table; checked below.
REVOKE ALL PRIVILEGES ON SEQUENCE private.pin_enrollment_global_rate_limit_events_id_seq FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;

-- Schemas keep their existing owners. Role attributes/memberships unchanged.
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
REVOKE ALL ON SCHEMA api FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT USAGE ON SCHEMA private TO gym_data_owner, gym_owner_executor, gym_public_executor;
GRANT USAGE ON SCHEMA public TO gym_data_owner;
GRANT USAGE ON SCHEMA api TO service_role, gym_owner_executor, gym_public_executor;
GRANT USAGE ON SCHEMA extensions TO gym_owner_executor;
-- Only this extension routine ACL changes; body/owner/version are untouched.
GRANT EXECUTE ON FUNCTION extensions.digest(bytea,text) TO gym_owner_executor;

-- Least-column grants and command/role-scoped RLS policies. Predicates do NOT
-- authenticate an Owner: the unchanged, body-pinned RPCs enforce that boundary.
-- No login or membership may reach an executor except approved definer entrypoints.
GRANT SELECT (user_id, is_active, created_at, deactivated_at) ON TABLE private.owner_access TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.owner_access FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, member_code, full_name, mobile_lookup_hash, mobile_encrypted, status, created_at, updated_at, approved_at) ON TABLE private.members TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.members FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (member_code, full_name, mobile_lookup_hash, mobile_encrypted, status) ON TABLE private.members TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.members FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (updated_at) ON TABLE private.members TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.members FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, name, price_php, is_active, created_at) ON TABLE private.membership_plans TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.membership_plans FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (name, price_php, is_active) ON TABLE private.membership_plans TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.membership_plans FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (name, price_php, is_active) ON TABLE private.membership_plans TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.membership_plans FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, member_id, plan_id, price_php, purchase_status, activation_date, expiry_date, created_at) ON TABLE private.membership_purchases TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.membership_purchases FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (member_id, plan_id, price_php, purchase_status) ON TABLE private.membership_purchases TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.membership_purchases FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (purchase_status) ON TABLE private.membership_purchases TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.membership_purchases FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, amount_php, payment_method, received_at, verification_status, external_reference, evidence_reference, recorded_by, created_at, operation_id, target_membership_purchase_id) ON TABLE private.payment_records TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.payment_records FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (amount_php, payment_method, verification_status, external_reference, recorded_by, operation_id, target_membership_purchase_id) ON TABLE private.payment_records TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.payment_records FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (verification_status) ON TABLE private.payment_records TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.payment_records FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, payment_id, membership_purchase_id, walkin_request_id, allocated_by, allocated_at) ON TABLE private.payment_allocations TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.payment_allocations FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (payment_id, membership_purchase_id, allocated_by) ON TABLE private.payment_allocations TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.payment_allocations FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, payment_id, event_type, reason, actor_user_id, created_at) ON TABLE private.payment_events TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.payment_events FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (payment_id, event_type, reason, actor_user_id) ON TABLE private.payment_events TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.payment_events FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, actor_user_id, event_type, subject_type, subject_id, details, created_at, stream_key, previous_event_hash, event_hash) ON TABLE private.audit_events TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.audit_events FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (stream_key, actor_user_id, event_type, subject_type, subject_id, details) ON TABLE private.audit_events TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.audit_events FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (stream_key, last_event_id, last_event_hash, updated_at) ON TABLE private.audit_chain_heads TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.audit_chain_heads FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (stream_key, last_event_id, last_event_hash) ON TABLE private.audit_chain_heads TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.audit_chain_heads FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (last_event_id, last_event_hash, updated_at) ON TABLE private.audit_chain_heads TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.audit_chain_heads FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, member_id, token_hash, token_purpose, expires_at, consumed_at, created_at) ON TABLE private.member_pin_setup_tokens TO gym_owner_executor;
CREATE POLICY gf_owner_select ON private.member_pin_setup_tokens FOR SELECT TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name);
GRANT INSERT (member_id, token_hash, token_purpose, expires_at) ON TABLE private.member_pin_setup_tokens TO gym_owner_executor;
CREATE POLICY gf_owner_insert ON private.member_pin_setup_tokens FOR INSERT TO gym_owner_executor WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT UPDATE (consumed_at) ON TABLE private.member_pin_setup_tokens TO gym_owner_executor;
CREATE POLICY gf_owner_update ON private.member_pin_setup_tokens FOR UPDATE TO gym_owner_executor USING (CURRENT_USER = 'gym_owner_executor'::name) WITH CHECK (CURRENT_USER = 'gym_owner_executor'::name);
GRANT SELECT (id, status) ON TABLE private.members TO gym_public_executor;
CREATE POLICY gf_public_select ON private.members FOR SELECT TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name);
GRANT UPDATE (updated_at) ON TABLE private.members TO gym_public_executor;
CREATE POLICY gf_public_update ON private.members FOR UPDATE TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name) WITH CHECK (CURRENT_USER = 'gym_public_executor'::name);
GRANT SELECT (id, member_id, token_hash, token_purpose, expires_at, consumed_at) ON TABLE private.member_pin_setup_tokens TO gym_public_executor;
CREATE POLICY gf_public_select ON private.member_pin_setup_tokens FOR SELECT TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name);
GRANT UPDATE (consumed_at) ON TABLE private.member_pin_setup_tokens TO gym_public_executor;
CREATE POLICY gf_public_update ON private.member_pin_setup_tokens FOR UPDATE TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name) WITH CHECK (CURRENT_USER = 'gym_public_executor'::name);
GRANT SELECT (member_id) ON TABLE private.member_pin_credentials TO gym_public_executor;
CREATE POLICY gf_public_select ON private.member_pin_credentials FOR SELECT TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name);
GRANT INSERT (member_id, password_hash, credential_version, created_at, updated_at) ON TABLE private.member_pin_credentials TO gym_public_executor;
CREATE POLICY gf_public_insert ON private.member_pin_credentials FOR INSERT TO gym_public_executor WITH CHECK (CURRENT_USER = 'gym_public_executor'::name);
GRANT SELECT (requested_at) ON TABLE private.pin_enrollment_global_rate_limit_events TO gym_public_executor;
CREATE POLICY gf_public_select ON private.pin_enrollment_global_rate_limit_events FOR SELECT TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name);
GRANT INSERT (requested_at) ON TABLE private.pin_enrollment_global_rate_limit_events TO gym_public_executor;
CREATE POLICY gf_public_insert ON private.pin_enrollment_global_rate_limit_events FOR INSERT TO gym_public_executor WITH CHECK (CURRENT_USER = 'gym_public_executor'::name);
GRANT DELETE ON TABLE private.pin_enrollment_global_rate_limit_events TO gym_public_executor;
CREATE POLICY gf_public_delete ON private.pin_enrollment_global_rate_limit_events FOR DELETE TO gym_public_executor USING (CURRENT_USER = 'gym_public_executor'::name);

-- All nine private helpers become/remain invoker functions. Only the sixteen
-- server-only API entrypoints retain SD, owned by bounded NOLOGIN executors.
ALTER FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) OWNER TO gym_owner_executor;
ALTER FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) SECURITY DEFINER;
ALTER FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) TO gym_owner_executor, service_role, gym_public_executor;
ALTER FUNCTION api.is_active_owner_for_user(uuid) OWNER TO gym_owner_executor;
ALTER FUNCTION api.is_active_owner_for_user(uuid) SECURITY DEFINER;
ALTER FUNCTION api.is_active_owner_for_user(uuid) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.is_active_owner_for_user(uuid) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.is_active_owner_for_user(uuid) TO gym_owner_executor, service_role;
ALTER FUNCTION api.member_enroll_pin(text, text) OWNER TO gym_public_executor;
ALTER FUNCTION api.member_enroll_pin(text, text) SECURITY DEFINER;
ALTER FUNCTION api.member_enroll_pin(text, text) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.member_enroll_pin(text, text) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.member_enroll_pin(text, text) TO gym_public_executor, service_role;
ALTER FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) SECURITY DEFINER;
ALTER FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) SECURITY DEFINER;
ALTER FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) SECURITY DEFINER;
ALTER FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_list_members(uuid, text, text, integer, integer) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_list_members(uuid, text, text, integer, integer) SECURITY DEFINER;
ALTER FUNCTION api.owner_list_members(uuid, text, text, integer, integer) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_list_members(uuid, text, text, integer, integer) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_members(uuid, text, text, integer, integer) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) SECURITY DEFINER;
ALTER FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_list_membership_plans(uuid) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_list_membership_plans(uuid) SECURITY DEFINER;
ALTER FUNCTION api.owner_list_membership_plans(uuid) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_list_membership_plans(uuid) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_plans(uuid) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) SECURITY DEFINER;
ALTER FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) SECURITY DEFINER;
ALTER FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_register_member(uuid, text, bytea, bytea) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_register_member(uuid, text, bytea, bytea) SECURITY DEFINER;
ALTER FUNCTION api.owner_register_member(uuid, text, bytea, bytea) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_register_member(uuid, text, bytea, bytea) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_register_member(uuid, text, bytea, bytea) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) SECURITY DEFINER;
ALTER FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) TO gym_owner_executor, service_role;
ALTER FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) OWNER TO gym_owner_executor;
ALTER FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) SECURITY DEFINER;
ALTER FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) TO gym_owner_executor, service_role;
ALTER FUNCTION api.reserve_pin_enrollment_request() OWNER TO gym_public_executor;
ALTER FUNCTION api.reserve_pin_enrollment_request() SECURITY DEFINER;
ALTER FUNCTION api.reserve_pin_enrollment_request() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.reserve_pin_enrollment_request() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.reserve_pin_enrollment_request() TO gym_public_executor, service_role;
ALTER FUNCTION api.verify_audit_stream(text) OWNER TO gym_owner_executor;
ALTER FUNCTION api.verify_audit_stream(text) SECURITY DEFINER;
ALTER FUNCTION api.verify_audit_stream(text) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION api.verify_audit_stream(text) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION api.verify_audit_stream(text) TO gym_owner_executor, service_role;
ALTER FUNCTION private.audit_events_chain_insert() OWNER TO gym_data_owner;
ALTER FUNCTION private.audit_events_chain_insert() SECURITY INVOKER;
ALTER FUNCTION private.audit_events_chain_insert() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.audit_events_chain_insert() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.audit_events_chain_insert() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) OWNER TO gym_data_owner;
ALTER FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) SECURITY INVOKER;
ALTER FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.guard_membership_payment_allocation() OWNER TO gym_data_owner;
ALTER FUNCTION private.guard_membership_payment_allocation() SECURITY INVOKER;
ALTER FUNCTION private.guard_membership_payment_allocation() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.guard_membership_payment_allocation() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_membership_payment_allocation() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.guard_membership_payment_record_insert() OWNER TO gym_data_owner;
ALTER FUNCTION private.guard_membership_payment_record_insert() SECURITY INVOKER;
ALTER FUNCTION private.guard_membership_payment_record_insert() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.guard_membership_payment_record_insert() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_membership_payment_record_insert() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.guard_membership_payment_record_update() OWNER TO gym_data_owner;
ALTER FUNCTION private.guard_membership_payment_record_update() SECURITY INVOKER;
ALTER FUNCTION private.guard_membership_payment_record_update() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.guard_membership_payment_record_update() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_membership_payment_record_update() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.guard_purchase_pending_activation() OWNER TO gym_data_owner;
ALTER FUNCTION private.guard_purchase_pending_activation() SECURITY INVOKER;
ALTER FUNCTION private.guard_purchase_pending_activation() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.guard_purchase_pending_activation() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.guard_purchase_pending_activation() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.is_active_owner() OWNER TO gym_data_owner;
ALTER FUNCTION private.is_active_owner() SECURITY INVOKER;
ALTER FUNCTION private.is_active_owner() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.is_active_owner() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.is_active_owner() TO gym_data_owner;
ALTER FUNCTION private.prevent_audit_event_mutation() OWNER TO gym_data_owner;
ALTER FUNCTION private.prevent_audit_event_mutation() SECURITY INVOKER;
ALTER FUNCTION private.prevent_audit_event_mutation() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.prevent_audit_event_mutation() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.prevent_audit_event_mutation() TO gym_data_owner, gym_owner_executor;
ALTER FUNCTION private.prevent_payment_history_mutation() OWNER TO gym_data_owner;
ALTER FUNCTION private.prevent_payment_history_mutation() SECURITY INVOKER;
ALTER FUNCTION private.prevent_payment_history_mutation() SET search_path='';
REVOKE ALL PRIVILEGES ON FUNCTION private.prevent_payment_history_mutation() FROM PUBLIC, anon, authenticated, service_role, gym_owner_executor, gym_public_executor;
GRANT EXECUTE ON FUNCTION private.prevent_payment_history_mutation() TO gym_data_owner, gym_owner_executor;


-- Scope future EXECUTE defaults only to the three application-created NOLOGIN
-- roles. Do not alter provider/postgres creator defaults across the database.
ALTER DEFAULT PRIVILEGES FOR ROLE gym_data_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_owner_executor REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_public_executor REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

SET LOCAL gymforce.assertion_profile='proposed_owner_executor';
DO $portable_metadata$
DECLARE r record;
BEGIN
    -- A matching body is insufficient when its language or execution metadata drift.
    FOR r IN SELECT * FROM (VALUES
        ('api.append_audit_event(text, uuid, text, text, text, jsonb)','plpgsql','v','u',false,false,false,2),
        ('api.is_active_owner_for_user(uuid)','sql','s','u',false,false,false,0),
        ('api.member_enroll_pin(text, text)','plpgsql','v','u',false,false,false,0),
        ('api.owner_confirm_membership_payment(uuid, uuid, boolean)','plpgsql','v','u',false,false,false,0),
        ('api.owner_create_membership_purchase(uuid, uuid, uuid)','plpgsql','v','u',false,false,false,0),
        ('api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','plpgsql','v','u',false,false,false,0),
        ('api.owner_list_members(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_list_membership_payments(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_list_membership_plans(uuid)','plpgsql','v','u',false,false,false,0),
        ('api.owner_list_membership_purchases(uuid, text, text, integer, integer)','plpgsql','v','u',false,false,false,4),
        ('api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','plpgsql','v','u',false,false,false,1),
        ('api.owner_register_member(uuid, text, bytea, bytea)','plpgsql','v','u',false,false,false,0),
        ('api.owner_reject_membership_payment(uuid, uuid, text)','plpgsql','v','u',false,false,false,0),
        ('api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','plpgsql','v','u',false,false,false,0),
        ('api.reserve_pin_enrollment_request()','plpgsql','v','u',false,false,false,0),
        ('api.verify_audit_stream(text)','plpgsql','v','u',false,true,false,0),
        ('private.audit_events_chain_insert()','plpgsql','v','u',false,false,false,0),
        ('private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','sql','i','u',false,false,false,0),
        ('private.guard_membership_payment_allocation()','plpgsql','v','u',false,false,false,0),
        ('private.guard_membership_payment_record_insert()','plpgsql','v','u',false,false,false,0),
        ('private.guard_membership_payment_record_update()','plpgsql','v','u',false,false,false,0),
        ('private.guard_purchase_pending_activation()','plpgsql','v','u',false,false,false,0),
        ('private.is_active_owner()','sql','s','u',false,false,false,0),
        ('private.prevent_audit_event_mutation()','plpgsql','v','u',false,false,false,0),
        ('private.prevent_payment_history_mutation()','plpgsql','v','u',false,false,false,0)
    ) v(signature,language,volatility,parallel,expected_strict,expected_returns_set,expected_leakproof,default_count) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_language l ON l.oid=p.prolang
          WHERE p.oid=pg_catalog.to_regprocedure(r.signature) AND p.prokind='f' AND l.lanname=r.language
            AND p.provolatile::text=r.volatility AND p.proparallel::text=r.parallel
            AND p.proisstrict=r.expected_strict AND p.proretset=r.expected_returns_set AND p.proleakproof=r.expected_leakproof
            AND p.pronargdefaults=r.default_count AND p.prosupport=0 AND p.provariadic=0
            AND p.probin IS NULL AND p.prosqlbody IS NULL) THEN
            RAISE EXCEPTION 'Routine execution metadata drift: %',r.signature;
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) AND NOT t.tgisinternal)<>13 THEN
        RAISE EXCEPTION 'Unexpected/missing application trigger';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_rewrite rw JOIN pg_catalog.pg_class c ON c.oid=rw.ev_class
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) THEN
        RAISE EXCEPTION 'Unexpected application rewrite rule/view';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind='S')<>3 THEN
        RAISE EXCEPTION 'Unexpected/missing application sequence';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='private' AND c.relkind NOT IN ('r','i','S','t')) THEN
        RAISE EXCEPTION 'Unexpected private relation kind';
    END IF;
    -- The sole provider dependency granted here must still be pgcrypto's digest.
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_depend d
        ON d.classid='pg_catalog.pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e'
        JOIN pg_catalog.pg_extension e ON e.oid=d.refobjid
        JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace
        WHERE p.oid=pg_catalog.to_regprocedure('extensions.digest(bytea,text)')
          AND e.extname='pgcrypto' AND n.nspname='extensions' AND NOT p.prosecdef
          AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles role_info
            WHERE role_info.oid=p.proowner AND role_info.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor'))) THEN
        RAISE EXCEPTION 'Unreviewed pgcrypto digest dependency';
    END IF;
END;
$portable_metadata$;

DO $phase_assertions$
DECLARE
    profile text := pg_catalog.current_setting('gymforce.assertion_profile',true);
    target boolean;
    r record; caller text; privilege_name text; v_column text; expected boolean;
    routine_oid oid; relation_oid oid; actual_owner text; actual_columns text;
    expected_expr text; actual_qual text; actual_check text; actual_policy record;
BEGIN
    IF profile IN ('historical_phase1','future_attendance') THEN
        RAISE EXCEPTION 'Profile % is not an executable acceptance profile: historical assumptions are archival; future Attendance is unimplemented', profile;
    END IF;
    IF profile IS NULL OR profile NOT IN ('current_server_only','proposed_owner_executor') THEN
        RAISE EXCEPTION 'Select an explicit current_server_only or proposed_owner_executor assertion profile';
    END IF;
    target := profile='proposed_owner_executor';
    -- Reserved roles remain non-login and cannot bypass RLS or assume others.
    FOREACH caller IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=caller
            AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb
            AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication AND NOT rolbypassrls) THEN
            RAISE EXCEPTION 'Unsafe/missing reserved role %',caller;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members e
        JOIN pg_catalog.pg_roles reserved ON reserved.oid=e.member OR reserved.oid=e.roleid
        WHERE reserved.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')) THEN
        RAISE EXCEPTION 'Reserved-role membership edge exists';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')) AND c.relkind IN ('r','p'))<>22 THEN
        RAISE EXCEPTION 'Application table inventory drift';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='api' AND c.relkind IN ('r','p','v','m','S','f')) THEN
        RAISE EXCEPTION 'API schema unexpectedly contains data relations';
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.attendance_checkins','id:uuid|member_id:uuid|walkin_request_id:uuid|gym_local_date:date|checked_in_at:timestamp with time zone|attendance_status:text'),
        ('private.attendance_validity_resolutions','id:uuid|attendance_id:uuid|prior_status:text|new_status:text|reason:text|resolved_by:uuid|resolved_at:timestamp with time zone'),
        ('private.audit_chain_heads','stream_key:text|last_event_id:bigint|last_event_hash:text|updated_at:timestamp with time zone'),
        ('private.audit_events','id:bigint|actor_user_id:uuid|event_type:text|subject_type:text|subject_id:text|details:jsonb|created_at:timestamp with time zone|stream_key:text|previous_event_hash:text|event_hash:text'),
        ('private.cash_drawer_sessions','id:uuid|opened_at:timestamp with time zone|opened_by:uuid|opening_float_php:numeric(12,2)|session_status:text|closed_at:timestamp with time zone|closed_by:uuid'),
        ('private.cash_reconciliation_adjustments','id:uuid|reconciliation_id:uuid|amount_delta_php:numeric(12,2)|reason:text|evidence_reference:text|recorded_by:uuid|created_at:timestamp with time zone'),
        ('private.cash_reconciliations','id:uuid|drawer_session_id:uuid|expected_cash_php:numeric(12,2)|counted_cash_php:numeric(12,2)|variance_php:numeric(12,2)|reconciled_by:uuid|reconciled_at:timestamp with time zone|notes:text'),
        ('private.member_pin_credentials','member_id:uuid|password_hash:text|credential_version:integer|created_at:timestamp with time zone|updated_at:timestamp with time zone'),
        ('private.member_pin_setup_tokens','id:uuid|member_id:uuid|token_hash:text|token_purpose:text|expires_at:timestamp with time zone|consumed_at:timestamp with time zone|created_at:timestamp with time zone'),
        ('private.members','id:uuid|member_code:text|full_name:text|mobile_lookup_hash:bytea|mobile_encrypted:bytea|status:text|created_at:timestamp with time zone|updated_at:timestamp with time zone|approved_at:timestamp with time zone'),
        ('private.membership_plans','id:uuid|name:text|price_php:numeric(12,2)|is_active:boolean|created_at:timestamp with time zone'),
        ('private.membership_purchases','id:uuid|member_id:uuid|plan_id:uuid|price_php:numeric(12,2)|purchase_status:text|activation_date:date|expiry_date:date|created_at:timestamp with time zone'),
        ('private.owner_access','user_id:uuid|is_active:boolean|created_at:timestamp with time zone|deactivated_at:timestamp with time zone'),
        ('private.payment_allocations','id:uuid|payment_id:uuid|membership_purchase_id:uuid|walkin_request_id:uuid|allocated_by:uuid|allocated_at:timestamp with time zone'),
        ('private.payment_corrections','id:uuid|payment_id:uuid|proposed_amount_php:numeric(12,2)|proposed_payment_method:text|reason:text|evidence_reference:text|correction_status:text|proposed_by:uuid|proposed_at:timestamp with time zone|decided_by:uuid|decided_at:timestamp with time zone|decision_reason:text'),
        ('private.payment_events','id:bigint|payment_id:uuid|event_type:text|reason:text|actor_user_id:uuid|created_at:timestamp with time zone'),
        ('private.payment_records','id:uuid|amount_php:numeric(12,2)|payment_method:text|received_at:timestamp with time zone|verification_status:text|external_reference:text|evidence_reference:text|recorded_by:uuid|created_at:timestamp with time zone|operation_id:uuid|target_membership_purchase_id:uuid'),
        ('private.pin_attempt_buckets','id:uuid|bucket_type:text|identifier_digest:text|window_started_at:timestamp with time zone|failed_attempts:integer|blocked_until:timestamp with time zone|updated_at:timestamp with time zone'),
        ('private.pin_enrollment_global_rate_limit_events','id:bigint|requested_at:timestamp with time zone'),
        ('private.walkin_fee_versions','id:uuid|fee_php:numeric(12,2)|currency:text|effective_from:timestamp with time zone|created_by:uuid|created_at:timestamp with time zone'),
        ('private.walkin_requests','id:uuid|fee_version_id:uuid|fee_php:numeric(12,2)|currency:text|request_status:text|created_at:timestamp with time zone|expires_at:timestamp with time zone|confirmed_by:uuid|confirmed_at:timestamp with time zone'),
        ('public.gym_settings','setting_key:text|setting_value:jsonb|updated_at:timestamp with time zone')
    ) v(name,columns) LOOP
        relation_oid := pg_catalog.to_regclass(r.name);
        IF relation_oid IS NULL THEN RAISE EXCEPTION 'Missing %',r.name; END IF;
        SELECT pg_catalog.string_agg(a.attname||':'||pg_catalog.format_type(a.atttypid,a.atttypmod),'|' ORDER BY a.attnum)
          INTO actual_columns FROM pg_catalog.pg_attribute a
          WHERE a.attrelid=relation_oid AND a.attnum>0 AND NOT a.attisdropped;
        IF actual_columns IS DISTINCT FROM r.columns THEN RAISE EXCEPTION 'Column/type inventory drift: %',r.name; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid=relation_oid AND c.relrowsecurity
             AND c.relowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END)
             AND (NOT target OR c.relforcerowsecurity)) THEN
            RAISE EXCEPTION 'Ownership/RLS mismatch: %',r.name;
        END IF;
        -- No direct browser/service/dormant-login access, including column grants.
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
            IF pg_catalog.has_table_privilege(caller,relation_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
              OR pg_catalog.has_any_column_privilege(caller,relation_oid,'SELECT,INSERT,UPDATE,REFERENCES') THEN
                RAISE EXCEPTION 'Direct protected relation access: % / %',caller,r.name;
            END IF;
        END LOOP;
        FOREACH caller IN ARRAY ARRAY['gym_owner_executor','gym_public_executor'] LOOP
            FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','REFERENCES'] LOOP
                FOR v_column IN SELECT attname FROM pg_catalog.pg_attribute
                    WHERE attrelid=relation_oid AND attnum>0 AND NOT attisdropped LOOP
                    SELECT target AND EXISTS (SELECT 1 FROM (VALUES
                        ('private.owner_access','gym_owner_executor','SELECT','user_id'),
        ('private.owner_access','gym_owner_executor','SELECT','is_active'),
        ('private.owner_access','gym_owner_executor','SELECT','created_at'),
        ('private.owner_access','gym_owner_executor','SELECT','deactivated_at'),
        ('private.members','gym_owner_executor','SELECT','id'),
        ('private.members','gym_owner_executor','SELECT','member_code'),
        ('private.members','gym_owner_executor','SELECT','full_name'),
        ('private.members','gym_owner_executor','SELECT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','SELECT','mobile_encrypted'),
        ('private.members','gym_owner_executor','SELECT','status'),
        ('private.members','gym_owner_executor','SELECT','created_at'),
        ('private.members','gym_owner_executor','SELECT','updated_at'),
        ('private.members','gym_owner_executor','SELECT','approved_at'),
        ('private.members','gym_owner_executor','INSERT','member_code'),
        ('private.members','gym_owner_executor','INSERT','full_name'),
        ('private.members','gym_owner_executor','INSERT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','INSERT','mobile_encrypted'),
        ('private.members','gym_owner_executor','INSERT','status'),
        ('private.members','gym_owner_executor','UPDATE','updated_at'),
        ('private.membership_plans','gym_owner_executor','SELECT','id'),
        ('private.membership_plans','gym_owner_executor','SELECT','name'),
        ('private.membership_plans','gym_owner_executor','SELECT','price_php'),
        ('private.membership_plans','gym_owner_executor','SELECT','is_active'),
        ('private.membership_plans','gym_owner_executor','SELECT','created_at'),
        ('private.membership_plans','gym_owner_executor','INSERT','name'),
        ('private.membership_plans','gym_owner_executor','INSERT','price_php'),
        ('private.membership_plans','gym_owner_executor','INSERT','is_active'),
        ('private.membership_plans','gym_owner_executor','UPDATE','name'),
        ('private.membership_plans','gym_owner_executor','UPDATE','price_php'),
        ('private.membership_plans','gym_owner_executor','UPDATE','is_active'),
        ('private.membership_purchases','gym_owner_executor','SELECT','id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','member_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','price_php'),
        ('private.membership_purchases','gym_owner_executor','SELECT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','SELECT','activation_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','expiry_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','created_at'),
        ('private.membership_purchases','gym_owner_executor','INSERT','member_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','price_php'),
        ('private.membership_purchases','gym_owner_executor','INSERT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','purchase_status'),
        ('private.payment_records','gym_owner_executor','SELECT','id'),
        ('private.payment_records','gym_owner_executor','SELECT','amount_php'),
        ('private.payment_records','gym_owner_executor','SELECT','payment_method'),
        ('private.payment_records','gym_owner_executor','SELECT','received_at'),
        ('private.payment_records','gym_owner_executor','SELECT','verification_status'),
        ('private.payment_records','gym_owner_executor','SELECT','external_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','evidence_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','recorded_by'),
        ('private.payment_records','gym_owner_executor','SELECT','created_at'),
        ('private.payment_records','gym_owner_executor','SELECT','operation_id'),
        ('private.payment_records','gym_owner_executor','SELECT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','INSERT','amount_php'),
        ('private.payment_records','gym_owner_executor','INSERT','payment_method'),
        ('private.payment_records','gym_owner_executor','INSERT','verification_status'),
        ('private.payment_records','gym_owner_executor','INSERT','external_reference'),
        ('private.payment_records','gym_owner_executor','INSERT','recorded_by'),
        ('private.payment_records','gym_owner_executor','INSERT','operation_id'),
        ('private.payment_records','gym_owner_executor','INSERT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','UPDATE','verification_status'),
        ('private.payment_allocations','gym_owner_executor','SELECT','id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','walkin_request_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_by'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_at'),
        ('private.payment_allocations','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','allocated_by'),
        ('private.payment_events','gym_owner_executor','SELECT','id'),
        ('private.payment_events','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_events','gym_owner_executor','SELECT','event_type'),
        ('private.payment_events','gym_owner_executor','SELECT','reason'),
        ('private.payment_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.payment_events','gym_owner_executor','SELECT','created_at'),
        ('private.payment_events','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_events','gym_owner_executor','INSERT','event_type'),
        ('private.payment_events','gym_owner_executor','INSERT','reason'),
        ('private.payment_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','id'),
        ('private.audit_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','event_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_id'),
        ('private.audit_events','gym_owner_executor','SELECT','details'),
        ('private.audit_events','gym_owner_executor','SELECT','created_at'),
        ('private.audit_events','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_events','gym_owner_executor','SELECT','previous_event_hash'),
        ('private.audit_events','gym_owner_executor','SELECT','event_hash'),
        ('private.audit_events','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','INSERT','event_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_id'),
        ('private.audit_events','gym_owner_executor','INSERT','details'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','updated_at'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','created_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','consumed_at'),
        ('private.members','gym_public_executor','SELECT','id'),
        ('private.members','gym_public_executor','SELECT','status'),
        ('private.members','gym_public_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','consumed_at'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','password_hash'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','credential_version'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','created_at'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','updated_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','requested_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','requested_at')
                    ) g(table_name,role_name,command,column_name)
                    WHERE g.table_name=r.name AND g.role_name=caller
                      AND g.command=privilege_name AND g.column_name=v_column)
                    INTO expected;
                    IF pg_catalog.has_column_privilege(caller,relation_oid,v_column,privilege_name) IS DISTINCT FROM expected THEN
                        RAISE EXCEPTION 'Column ACL mismatch: %.% / % / %',r.name,v_column,caller,privilege_name;
                    END IF;
                END LOOP;
            END LOOP;
            IF pg_catalog.has_table_privilege(caller,relation_oid,'TRUNCATE,REFERENCES,TRIGGER')
               OR pg_catalog.has_table_privilege(caller,relation_oid,'DELETE') IS DISTINCT FROM
                 (target AND caller='gym_public_executor' AND r.name='private.pin_enrollment_global_rate_limit_events') THEN
                RAISE EXCEPTION 'Unexpected table-wide destructive privilege: % / %',caller,r.name;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c,
            LATERAL pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault('r',c.relowner))) a
            WHERE c.oid=relation_oid AND a.grantee<>c.relowner
            AND NOT (target AND r.name='private.pin_enrollment_global_rate_limit_events'
                     AND a.grantee=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gym_public_executor')
                     AND a.privilege_type='DELETE' AND NOT a.is_grantable)) THEN
            RAISE EXCEPTION 'Unreviewed relation ACL principal/grant: %',r.name;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_attribute col,
            LATERAL pg_catalog.aclexplode(col.attacl) a
            WHERE col.attrelid=relation_oid AND col.attnum>0
              AND a.grantee<>(SELECT relowner FROM pg_catalog.pg_class WHERE oid=relation_oid)
              AND (a.is_grantable OR NOT (target AND EXISTS (SELECT 1 FROM (VALUES
                  ('private.owner_access','gym_owner_executor','SELECT','user_id'),
        ('private.owner_access','gym_owner_executor','SELECT','is_active'),
        ('private.owner_access','gym_owner_executor','SELECT','created_at'),
        ('private.owner_access','gym_owner_executor','SELECT','deactivated_at'),
        ('private.members','gym_owner_executor','SELECT','id'),
        ('private.members','gym_owner_executor','SELECT','member_code'),
        ('private.members','gym_owner_executor','SELECT','full_name'),
        ('private.members','gym_owner_executor','SELECT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','SELECT','mobile_encrypted'),
        ('private.members','gym_owner_executor','SELECT','status'),
        ('private.members','gym_owner_executor','SELECT','created_at'),
        ('private.members','gym_owner_executor','SELECT','updated_at'),
        ('private.members','gym_owner_executor','SELECT','approved_at'),
        ('private.members','gym_owner_executor','INSERT','member_code'),
        ('private.members','gym_owner_executor','INSERT','full_name'),
        ('private.members','gym_owner_executor','INSERT','mobile_lookup_hash'),
        ('private.members','gym_owner_executor','INSERT','mobile_encrypted'),
        ('private.members','gym_owner_executor','INSERT','status'),
        ('private.members','gym_owner_executor','UPDATE','updated_at'),
        ('private.membership_plans','gym_owner_executor','SELECT','id'),
        ('private.membership_plans','gym_owner_executor','SELECT','name'),
        ('private.membership_plans','gym_owner_executor','SELECT','price_php'),
        ('private.membership_plans','gym_owner_executor','SELECT','is_active'),
        ('private.membership_plans','gym_owner_executor','SELECT','created_at'),
        ('private.membership_plans','gym_owner_executor','INSERT','name'),
        ('private.membership_plans','gym_owner_executor','INSERT','price_php'),
        ('private.membership_plans','gym_owner_executor','INSERT','is_active'),
        ('private.membership_plans','gym_owner_executor','UPDATE','name'),
        ('private.membership_plans','gym_owner_executor','UPDATE','price_php'),
        ('private.membership_plans','gym_owner_executor','UPDATE','is_active'),
        ('private.membership_purchases','gym_owner_executor','SELECT','id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','member_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','SELECT','price_php'),
        ('private.membership_purchases','gym_owner_executor','SELECT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','SELECT','activation_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','expiry_date'),
        ('private.membership_purchases','gym_owner_executor','SELECT','created_at'),
        ('private.membership_purchases','gym_owner_executor','INSERT','member_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','plan_id'),
        ('private.membership_purchases','gym_owner_executor','INSERT','price_php'),
        ('private.membership_purchases','gym_owner_executor','INSERT','purchase_status'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','purchase_status'),
        ('private.payment_records','gym_owner_executor','SELECT','id'),
        ('private.payment_records','gym_owner_executor','SELECT','amount_php'),
        ('private.payment_records','gym_owner_executor','SELECT','payment_method'),
        ('private.payment_records','gym_owner_executor','SELECT','received_at'),
        ('private.payment_records','gym_owner_executor','SELECT','verification_status'),
        ('private.payment_records','gym_owner_executor','SELECT','external_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','evidence_reference'),
        ('private.payment_records','gym_owner_executor','SELECT','recorded_by'),
        ('private.payment_records','gym_owner_executor','SELECT','created_at'),
        ('private.payment_records','gym_owner_executor','SELECT','operation_id'),
        ('private.payment_records','gym_owner_executor','SELECT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','INSERT','amount_php'),
        ('private.payment_records','gym_owner_executor','INSERT','payment_method'),
        ('private.payment_records','gym_owner_executor','INSERT','verification_status'),
        ('private.payment_records','gym_owner_executor','INSERT','external_reference'),
        ('private.payment_records','gym_owner_executor','INSERT','recorded_by'),
        ('private.payment_records','gym_owner_executor','INSERT','operation_id'),
        ('private.payment_records','gym_owner_executor','INSERT','target_membership_purchase_id'),
        ('private.payment_records','gym_owner_executor','UPDATE','verification_status'),
        ('private.payment_allocations','gym_owner_executor','SELECT','id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','walkin_request_id'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_by'),
        ('private.payment_allocations','gym_owner_executor','SELECT','allocated_at'),
        ('private.payment_allocations','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','membership_purchase_id'),
        ('private.payment_allocations','gym_owner_executor','INSERT','allocated_by'),
        ('private.payment_events','gym_owner_executor','SELECT','id'),
        ('private.payment_events','gym_owner_executor','SELECT','payment_id'),
        ('private.payment_events','gym_owner_executor','SELECT','event_type'),
        ('private.payment_events','gym_owner_executor','SELECT','reason'),
        ('private.payment_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.payment_events','gym_owner_executor','SELECT','created_at'),
        ('private.payment_events','gym_owner_executor','INSERT','payment_id'),
        ('private.payment_events','gym_owner_executor','INSERT','event_type'),
        ('private.payment_events','gym_owner_executor','INSERT','reason'),
        ('private.payment_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','id'),
        ('private.audit_events','gym_owner_executor','SELECT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','SELECT','event_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_type'),
        ('private.audit_events','gym_owner_executor','SELECT','subject_id'),
        ('private.audit_events','gym_owner_executor','SELECT','details'),
        ('private.audit_events','gym_owner_executor','SELECT','created_at'),
        ('private.audit_events','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_events','gym_owner_executor','SELECT','previous_event_hash'),
        ('private.audit_events','gym_owner_executor','SELECT','event_hash'),
        ('private.audit_events','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_events','gym_owner_executor','INSERT','actor_user_id'),
        ('private.audit_events','gym_owner_executor','INSERT','event_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_type'),
        ('private.audit_events','gym_owner_executor','INSERT','subject_id'),
        ('private.audit_events','gym_owner_executor','INSERT','details'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','updated_at'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','stream_key'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_id'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','last_event_hash'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','created_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','member_id'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_hash'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','expires_at'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','consumed_at'),
        ('private.members','gym_public_executor','SELECT','id'),
        ('private.members','gym_public_executor','SELECT','status'),
        ('private.members','gym_public_executor','UPDATE','updated_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_hash'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','token_purpose'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','expires_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','consumed_at'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','consumed_at'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','member_id'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','password_hash'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','credential_version'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','created_at'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','updated_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','requested_at'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','requested_at')
              ) g(table_name,role_name,command,column_name)
              JOIN pg_catalog.pg_roles rr ON rr.rolname=g.role_name
              WHERE g.table_name=r.name AND g.column_name=col.attname
                AND rr.oid=a.grantee AND g.command=a.privilege_type)))) THEN
            RAISE EXCEPTION 'Unreviewed column ACL principal/grant: %',r.name;
        END IF;
    END LOOP;
    IF NOT target AND EXISTS (SELECT 1 FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings'))) THEN
        RAISE EXCEPTION 'Current profile policy inventory changed';
    END IF;
    IF target THEN
        IF (SELECT count(*) FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
            JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings')))<>34 THEN
            RAISE EXCEPTION 'Policy count drift';
        END IF;
        FOR r IN SELECT * FROM (VALUES
            ('private.owner_access','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.members','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.members','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.members','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.membership_plans','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.membership_plans','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.membership_plans','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.membership_purchases','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.membership_purchases','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.membership_purchases','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.payment_records','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_records','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.payment_records','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.payment_allocations','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_allocations','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.payment_events','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.payment_events','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_events','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.audit_events','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_chain_heads','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.audit_chain_heads','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.audit_chain_heads','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.member_pin_setup_tokens','gym_owner_executor','SELECT','gf_owner_select'),
        ('private.member_pin_setup_tokens','gym_owner_executor','INSERT','gf_owner_insert'),
        ('private.member_pin_setup_tokens','gym_owner_executor','UPDATE','gf_owner_update'),
        ('private.members','gym_public_executor','SELECT','gf_public_select'),
        ('private.members','gym_public_executor','UPDATE','gf_public_update'),
        ('private.member_pin_setup_tokens','gym_public_executor','SELECT','gf_public_select'),
        ('private.member_pin_setup_tokens','gym_public_executor','UPDATE','gf_public_update'),
        ('private.member_pin_credentials','gym_public_executor','SELECT','gf_public_select'),
        ('private.member_pin_credentials','gym_public_executor','INSERT','gf_public_insert'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','SELECT','gf_public_select'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','INSERT','gf_public_insert'),
        ('private.pin_enrollment_global_rate_limit_events','gym_public_executor','DELETE','gf_public_delete')
        ) v(table_name,role_name,command,policy_name) LOOP
            SELECT * INTO actual_policy FROM pg_catalog.pg_policy
              WHERE polrelid=pg_catalog.to_regclass(r.table_name) AND polname=r.policy_name;
            IF NOT FOUND OR NOT actual_policy.polpermissive
               OR actual_policy.polroles IS DISTINCT FROM ARRAY[(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=r.role_name)]
               OR actual_policy.polcmd::text IS DISTINCT FROM (CASE r.command WHEN 'SELECT' THEN 'r' WHEN 'INSERT' THEN 'a' WHEN 'UPDATE' THEN 'w' WHEN 'DELETE' THEN 'd' END) THEN
                RAISE EXCEPTION 'Role/command policy mismatch: % / %',r.table_name,r.policy_name;
            END IF;
            expected_expr := 'current_user='||quote_literal(r.role_name)||'::name';
            actual_qual := lower(regexp_replace(pg_catalog.pg_get_expr(actual_policy.polqual,actual_policy.polrelid),'[[:space:]()]','','g'));
            actual_check := lower(regexp_replace(pg_catalog.pg_get_expr(actual_policy.polwithcheck,actual_policy.polrelid),'[[:space:]()]','','g'));
            IF (r.command IN ('SELECT','UPDATE','DELETE') AND actual_qual IS DISTINCT FROM expected_expr)
               OR (r.command='INSERT' AND actual_qual IS NOT NULL)
               OR (r.command IN ('INSERT','UPDATE') AND actual_check IS DISTINCT FROM expected_expr)
               OR (r.command IN ('SELECT','DELETE') AND actual_check IS NOT NULL) THEN
                RAISE EXCEPTION 'Policy predicate mismatch: % / %',r.table_name,r.policy_name;
            END IF;
        END LOOP;
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.audit_events_id_seq','gym_owner_executor'),
        ('private.payment_events_id_seq','gym_owner_executor'),
        ('private.pin_enrollment_global_rate_limit_events_id_seq','gym_public_executor')
    ) v(name,executor) LOOP
        relation_oid := pg_catalog.to_regclass(r.name);
        IF relation_oid IS NULL OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
            WHERE c.oid=relation_oid AND c.relkind='S' AND c.relowner=(SELECT oid FROM pg_catalog.pg_roles
            WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END)) THEN
            RAISE EXCEPTION 'Sequence ownership mismatch: %',r.name;
        END IF;
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
            IF pg_catalog.has_sequence_privilege(caller,relation_oid,'SELECT,UPDATE')
               OR pg_catalog.has_sequence_privilege(caller,relation_oid,'USAGE') THEN
                RAISE EXCEPTION 'Sequence ACL mismatch: % / %',r.name,caller;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c,
            LATERAL pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault('S',c.relowner))) a
            WHERE c.oid=relation_oid AND a.grantee<>c.relowner) THEN
            RAISE EXCEPTION 'Unreviewed sequence ACL: %',r.name;
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname IN ('private','api'))<>25 THEN RAISE EXCEPTION 'Routine inventory drift'; END IF;
    FOR r IN SELECT * FROM (VALUES
        ('api.append_audit_event(text, uuid, text, text, text, jsonb)','7a05ca54592137c75b9adda7023516a8','gym_owner_executor','true','true','service_role,gym_public_executor'),
        ('api.is_active_owner_for_user(uuid)','830f29066e37d9f2593c3cd99878ae93','gym_owner_executor','true','true','service_role'),
        ('api.member_enroll_pin(text, text)','6bf1d4a963b2b853ba9cdc7cb582c342','gym_public_executor','true','true','service_role'),
        ('api.owner_confirm_membership_payment(uuid, uuid, boolean)','ce58f4473d75469ef2676f232794dce0','gym_owner_executor','true','true','service_role'),
        ('api.owner_create_membership_purchase(uuid, uuid, uuid)','f8f310bd5576274401706c5213c6746d','gym_owner_executor','true','true','service_role'),
        ('api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','7a226978d83e191643a436c829f9dd07','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_members(uuid, text, text, integer, integer)','342dd9a2131e068c1a849694b053ebdf','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_payments(uuid, text, text, integer, integer)','6ac0d61dfc24c15123812ec788294197','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_plans(uuid)','fc3ed2be2834b6458f2835bfc18d9b4e','gym_owner_executor','true','true','service_role'),
        ('api.owner_list_membership_purchases(uuid, text, text, integer, integer)','d6fd6f1ba099afe317dcf1606d49d64f','gym_owner_executor','true','true','service_role'),
        ('api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','c21766acb601a8b92dc26d59f73be2a3','gym_owner_executor','true','true','service_role'),
        ('api.owner_register_member(uuid, text, bytea, bytea)','e56b20e809c8dfcebd782d4e8aa5fbb5','gym_owner_executor','true','true','service_role'),
        ('api.owner_reject_membership_payment(uuid, uuid, text)','b55e7879cbae6d9074264826ed75eac0','gym_owner_executor','true','true','service_role'),
        ('api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','c128144cda372362b26ec91dc64fd6fa','gym_owner_executor','true','true','service_role'),
        ('api.reserve_pin_enrollment_request()','ed1a67d4a3cd30fed31a0ee36222eb5b','gym_public_executor','true','true','service_role'),
        ('api.verify_audit_stream(text)','f7c5cdb53ec4cf2d845e38f404df5fb9','gym_owner_executor','true','true','service_role'),
        ('private.audit_events_chain_insert()','6fa6a434395de93250213752513ffb34','gym_data_owner','false','true','gym_owner_executor'),
        ('private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','a0635caf0c329b24571bd68df684f69f','gym_data_owner','false','false','gym_owner_executor'),
        ('private.guard_membership_payment_allocation()','4836529309d8c518d42d24b9d191d6d5','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_membership_payment_record_insert()','edaae9f3a89330d4e55ce37d7d16d074','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_membership_payment_record_update()','9386192bae0b7aec6e34fce2e2aadbda','gym_data_owner','false','true','gym_owner_executor'),
        ('private.guard_purchase_pending_activation()','c3467a65c399cf75243d4e3e9e31b36c','gym_data_owner','false','true','gym_owner_executor'),
        ('private.is_active_owner()','76af3203b0fe03c30e1eb6d8264a04e6','gym_data_owner','false','false',''),
        ('private.prevent_audit_event_mutation()','d835b9b2db211d2439e03ec9d8a6337d','gym_data_owner','false','true','gym_owner_executor'),
        ('private.prevent_payment_history_mutation()','0ad4feeac81403c334c6665ff018485e','gym_data_owner','false','true','gym_owner_executor')
    ) v(signature,body_md5,target_owner,target_definer,baseline_definer,callers) LOOP
        routine_oid := pg_catalog.to_regprocedure(r.signature);
        IF routine_oid IS NULL OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
            WHERE p.oid=routine_oid AND md5(p.prosrc)=r.body_md5
              AND p.proowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN r.target_owner ELSE 'postgres' END)
              AND p.prosecdef=CASE WHEN target THEN r.target_definer::boolean ELSE r.baseline_definer::boolean END
              AND p.proconfig=ARRAY['search_path=""']::text[]) THEN
            RAISE EXCEPTION 'Routine body/owner/execution/config mismatch: %',r.signature;
        END IF;
        FOREACH caller IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
            expected := CASE WHEN target THEN caller=r.target_owner OR caller=ANY(string_to_array(r.callers,','))
                             ELSE caller='service_role' AND r.signature LIKE 'api.%' END;
            IF pg_catalog.has_function_privilege(caller,routine_oid,'EXECUTE') IS DISTINCT FROM expected THEN
                RAISE EXCEPTION 'Routine execute mismatch: % / %',r.signature,caller;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p,
            LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
            WHERE p.oid=routine_oid AND (a.is_grantable AND a.grantee<>p.proowner OR
              a.grantee<>p.proowner AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles rr
                WHERE rr.oid=a.grantee AND rr.rolname=ANY(CASE WHEN target THEN string_to_array(r.callers,',')
                ELSE CASE WHEN r.signature LIKE 'api.%' THEN ARRAY['service_role'] ELSE ARRAY[]::text[] END END)))) THEN
            RAISE EXCEPTION 'PUBLIC/unreviewed routine grantee: %',r.signature;
        END IF;
    END LOOP;
    FOREACH caller IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF pg_catalog.has_schema_privilege(caller,'private','USAGE,CREATE')
           OR pg_catalog.has_schema_privilege(caller,'api','USAGE,CREATE') THEN
            RAISE EXCEPTION 'Browser/dormant schema exposure: %',caller;
        END IF;
    END LOOP;
    IF pg_catalog.has_schema_privilege('service_role','private','USAGE,CREATE')
       OR NOT pg_catalog.has_schema_privilege('service_role','api','USAGE')
       OR pg_catalog.has_schema_privilege('service_role','api','CREATE') THEN
        RAISE EXCEPTION 'Service-role schema boundary mismatch';
    END IF;
    FOREACH caller IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF pg_catalog.has_schema_privilege(caller,'private','CREATE')
           OR pg_catalog.has_schema_privilege(caller,'api','CREATE')
           OR pg_catalog.has_schema_privilege(caller,'public','CREATE') THEN
            RAISE EXCEPTION 'Reserved role has schema CREATE: %',caller;
        END IF;
        IF pg_catalog.has_schema_privilege(caller,'private','USAGE') IS DISTINCT FROM target THEN
            RAISE EXCEPTION 'Reserved private schema USAGE mismatch: %',caller;
        END IF;
        IF pg_catalog.has_schema_privilege(caller,'api','USAGE') IS DISTINCT FROM
           (target AND caller IN ('gym_owner_executor','gym_public_executor')) THEN
            RAISE EXCEPTION 'Reserved API schema USAGE mismatch: %',caller;
        END IF;
    END LOOP;
    IF target AND (NOT pg_catalog.has_schema_privilege('gym_owner_executor','extensions','USAGE')
       OR NOT pg_catalog.has_function_privilege('gym_owner_executor','extensions.digest(bytea,text)','EXECUTE')) THEN
        RAISE EXCEPTION 'Audit digest dependency unavailable to Owner executor';
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('private.audit_events','audit_events_chain_insert_trigger','CREATE TRIGGER audit_events_chain_insert_trigger BEFORE INSERT ON private.audit_events FOR EACH ROW EXECUTE FUNCTION private.audit_events_chain_insert()'),
        ('private.audit_events','audit_events_no_truncate','CREATE TRIGGER audit_events_no_truncate BEFORE TRUNCATE ON private.audit_events FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_audit_event_mutation()'),
        ('private.audit_events','audit_events_no_update_delete','CREATE TRIGGER audit_events_no_update_delete BEFORE DELETE OR UPDATE ON private.audit_events FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_event_mutation()'),
        ('private.membership_purchases','membership_purchase_requires_confirmed_payment','CREATE TRIGGER membership_purchase_requires_confirmed_payment BEFORE INSERT OR UPDATE ON private.membership_purchases FOR EACH ROW EXECUTE FUNCTION private.guard_purchase_pending_activation()'),
        ('private.payment_allocations','payment_allocations_no_truncate','CREATE TRIGGER payment_allocations_no_truncate BEFORE TRUNCATE ON private.payment_allocations FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_allocations','payment_allocations_no_update_delete','CREATE TRIGGER payment_allocations_no_update_delete BEFORE DELETE OR UPDATE ON private.payment_allocations FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_allocations','payment_allocations_validate_membership','CREATE TRIGGER payment_allocations_validate_membership BEFORE INSERT ON private.payment_allocations FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_allocation()'),
        ('private.payment_events','payment_events_no_truncate','CREATE TRIGGER payment_events_no_truncate BEFORE TRUNCATE ON private.payment_events FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_events','payment_events_no_update_delete','CREATE TRIGGER payment_events_no_update_delete BEFORE DELETE OR UPDATE ON private.payment_events FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_guard_update','CREATE TRIGGER payment_records_guard_update BEFORE UPDATE ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_record_update()'),
        ('private.payment_records','payment_records_no_delete','CREATE TRIGGER payment_records_no_delete BEFORE DELETE ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_no_truncate','CREATE TRIGGER payment_records_no_truncate BEFORE TRUNCATE ON private.payment_records FOR EACH STATEMENT EXECUTE FUNCTION private.prevent_payment_history_mutation()'),
        ('private.payment_records','payment_records_validate_membership_insert','CREATE TRIGGER payment_records_validate_membership_insert BEFORE INSERT ON private.payment_records FOR EACH ROW EXECUTE FUNCTION private.guard_membership_payment_record_insert()')
    ) v(table_name,name,definition) LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger t WHERE t.tgrelid=pg_catalog.to_regclass(r.table_name)
            AND t.tgname=r.name AND t.tgenabled='O' AND pg_catalog.pg_get_triggerdef(t.oid)=r.definition) THEN
            RAISE EXCEPTION 'Trigger definition/state drift: %.%',r.table_name,r.name;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS profile %: catalog checks only; executor mutation/concurrency acceptance remains a separate required gate',profile;
    IF NOT target THEN
        RAISE WARNING 'Ownership/executor hardening remains unsatisfied in current_server_only profile';
    END IF;
END;
$phase_assertions$;
DO $dependency_assertions$
DECLARE r record; target boolean := current_setting('gymforce.assertion_profile')='proposed_owner_executor'; expected_owner oid;
BEGIN
    SELECT oid INTO expected_owner FROM pg_catalog.pg_roles WHERE rolname=CASE WHEN target THEN 'gym_data_owner' ELSE 'postgres' END;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.audit_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.audit_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.audit_events_id_seq'; END IF;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.payment_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.payment_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.payment_events_id_seq'; END IF;
    IF pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('private.pin_enrollment_global_rate_limit_events','id')) IS DISTINCT FROM pg_catalog.to_regclass('private.pin_enrollment_global_rate_limit_events_id_seq') THEN RAISE EXCEPTION 'Identity sequence binding drift: private.pin_enrollment_global_rate_limit_events_id_seq'; END IF;
    FOR r IN SELECT * FROM (VALUES
        ('index','private.attendance_checkins_pkey','private.attendance_checkins'),
        ('index','private.attendance_date_idx','private.attendance_checkins'),
        ('index','private.attendance_member_date_idx','private.attendance_checkins'),
        ('index','private.attendance_one_checkin_per_walkin','private.attendance_checkins'),
        ('index','private.attendance_one_member_valid_checkin_per_day','private.attendance_checkins'),
        ('index','private.attendance_validity_resolutions_pkey','private.attendance_validity_resolutions'),
        ('index','private.audit_chain_heads_pkey','private.audit_chain_heads'),
        ('index','private.audit_events_actor_created_idx','private.audit_events'),
        ('index','private.audit_events_created_at_idx','private.audit_events'),
        ('index','private.audit_events_pkey','private.audit_events'),
        ('index','private.audit_events_stream_created_idx','private.audit_events'),
        ('index','private.cash_adjustments_reconciliation_idx','private.cash_reconciliation_adjustments'),
        ('index','private.cash_drawer_only_one_open_session','private.cash_drawer_sessions'),
        ('index','private.cash_drawer_sessions_pkey','private.cash_drawer_sessions'),
        ('index','private.cash_reconciliation_adjustments_pkey','private.cash_reconciliation_adjustments'),
        ('index','private.cash_reconciliations_date_idx','private.cash_reconciliations'),
        ('index','private.cash_reconciliations_drawer_session_id_key','private.cash_reconciliations'),
        ('index','private.cash_reconciliations_pkey','private.cash_reconciliations'),
        ('index','private.member_pin_credentials_pkey','private.member_pin_credentials'),
        ('index','private.member_pin_setup_tokens_active_enrollment_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_expiry_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_member_idx','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_pkey','private.member_pin_setup_tokens'),
        ('index','private.member_pin_setup_tokens_token_hash_key','private.member_pin_setup_tokens'),
        ('index','private.members_member_code_key','private.members'),
        ('index','private.members_mobile_lookup_hash_key','private.members'),
        ('index','private.members_pkey','private.members'),
        ('index','private.members_status_idx','private.members'),
        ('index','private.membership_plans_normalized_name_uidx','private.membership_plans'),
        ('index','private.membership_plans_pkey','private.membership_plans'),
        ('index','private.membership_purchases_member_idx','private.membership_purchases'),
        ('index','private.membership_purchases_no_overlapping_periods','private.membership_purchases'),
        ('index','private.membership_purchases_pkey','private.membership_purchases'),
        ('index','private.membership_purchases_plan_idx','private.membership_purchases'),
        ('index','private.owner_access_pkey','private.owner_access'),
        ('index','private.payment_allocations_membership_idx','private.payment_allocations'),
        ('index','private.payment_allocations_membership_purchase_uidx','private.payment_allocations'),
        ('index','private.payment_allocations_payment_id_key','private.payment_allocations'),
        ('index','private.payment_allocations_pkey','private.payment_allocations'),
        ('index','private.payment_allocations_walkin_idx','private.payment_allocations'),
        ('index','private.payment_corrections_payment_idx','private.payment_corrections'),
        ('index','private.payment_corrections_pkey','private.payment_corrections'),
        ('index','private.payment_events_payment_created_idx','private.payment_events'),
        ('index','private.payment_events_pkey','private.payment_events'),
        ('index','private.payment_records_membership_external_reference_uidx','private.payment_records'),
        ('index','private.payment_records_membership_idx','private.payment_records'),
        ('index','private.payment_records_operation_id_uidx','private.payment_records'),
        ('index','private.payment_records_pending_membership_uidx','private.payment_records'),
        ('index','private.payment_records_pkey','private.payment_records'),
        ('index','private.pin_attempt_buckets_blocked_idx','private.pin_attempt_buckets'),
        ('index','private.pin_attempt_buckets_pkey','private.pin_attempt_buckets'),
        ('index','private.pin_bucket_unique_window','private.pin_attempt_buckets'),
        ('index','private.pin_enrollment_global_rate_limit_events_pkey','private.pin_enrollment_global_rate_limit_events'),
        ('index','private.pin_enrollment_global_rate_limit_events_requested_at_idx','private.pin_enrollment_global_rate_limit_events'),
        ('index','private.walkin_fee_versions_pkey','private.walkin_fee_versions'),
        ('index','private.walkin_requests_pkey','private.walkin_requests'),
        ('index','public.gym_settings_pkey','public.gym_settings'),
        ('type','private._attendance_checkins','private.attendance_checkins'),
        ('type','private._attendance_validity_resolutions','private.attendance_validity_resolutions'),
        ('type','private._audit_chain_heads','private.audit_chain_heads'),
        ('type','private._audit_events','private.audit_events'),
        ('type','private._cash_drawer_sessions','private.cash_drawer_sessions'),
        ('type','private._cash_reconciliation_adjustments','private.cash_reconciliation_adjustments'),
        ('type','private._cash_reconciliations','private.cash_reconciliations'),
        ('type','private._member_pin_credentials','private.member_pin_credentials'),
        ('type','private._member_pin_setup_tokens','private.member_pin_setup_tokens'),
        ('type','private._members','private.members'),
        ('type','private._membership_plans','private.membership_plans'),
        ('type','private._membership_purchases','private.membership_purchases'),
        ('type','private._owner_access','private.owner_access'),
        ('type','private._payment_allocations','private.payment_allocations'),
        ('type','private._payment_corrections','private.payment_corrections'),
        ('type','private._payment_events','private.payment_events'),
        ('type','private._payment_records','private.payment_records'),
        ('type','private._pin_attempt_buckets','private.pin_attempt_buckets'),
        ('type','private._pin_enrollment_global_rate_limit_events','private.pin_enrollment_global_rate_limit_events'),
        ('type','private._walkin_fee_versions','private.walkin_fee_versions'),
        ('type','private._walkin_requests','private.walkin_requests'),
        ('type','private.attendance_checkins','private.attendance_checkins'),
        ('type','private.attendance_validity_resolutions','private.attendance_validity_resolutions'),
        ('type','private.audit_chain_heads','private.audit_chain_heads'),
        ('type','private.audit_events','private.audit_events'),
        ('type','private.cash_drawer_sessions','private.cash_drawer_sessions'),
        ('type','private.cash_reconciliation_adjustments','private.cash_reconciliation_adjustments'),
        ('type','private.cash_reconciliations','private.cash_reconciliations'),
        ('type','private.member_pin_credentials','private.member_pin_credentials'),
        ('type','private.member_pin_setup_tokens','private.member_pin_setup_tokens'),
        ('type','private.members','private.members'),
        ('type','private.membership_plans','private.membership_plans'),
        ('type','private.membership_purchases','private.membership_purchases'),
        ('type','private.owner_access','private.owner_access'),
        ('type','private.payment_allocations','private.payment_allocations'),
        ('type','private.payment_corrections','private.payment_corrections'),
        ('type','private.payment_events','private.payment_events'),
        ('type','private.payment_records','private.payment_records'),
        ('type','private.pin_attempt_buckets','private.pin_attempt_buckets'),
        ('type','private.pin_enrollment_global_rate_limit_events','private.pin_enrollment_global_rate_limit_events'),
        ('type','private.walkin_fee_versions','private.walkin_fee_versions'),
        ('type','private.walkin_requests','private.walkin_requests'),
        ('type','public._gym_settings','public.gym_settings'),
        ('type','public.gym_settings','public.gym_settings')
    ) v(kind,name,parent) LOOP
        IF r.kind='index' AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_index i ON i.indexrelid=c.oid WHERE c.oid=pg_catalog.to_regclass(r.name)
              AND i.indrelid=pg_catalog.to_regclass(r.parent) AND c.relowner=expected_owner
              AND i.indisvalid AND i.indisready) THEN
            RAISE EXCEPTION 'Dependent index owner/binding/validity mismatch: %',r.name;
        ELSIF r.kind='type' AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type t
            JOIN pg_catalog.pg_class c ON c.oid=pg_catalog.to_regclass(r.parent)
            JOIN pg_catalog.pg_type base ON base.oid=c.reltype
            WHERE t.oid=pg_catalog.to_regtype(r.name) AND (t.oid=base.oid OR t.oid=base.typarray)
              AND t.typowner=expected_owner) THEN
            RAISE EXCEPTION 'Dependent type owner/binding mismatch: %',r.name;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_namespace n ON n.oid=c.connamespace
       WHERE (n.nspname='private' OR c.conrelid=pg_catalog.to_regclass('public.gym_settings')) AND NOT c.convalidated) THEN
        RAISE EXCEPTION 'Unvalidated application constraint';
    END IF;
END;
$dependency_assertions$;

DO $portable_boundaries$
DECLARE r record; role_name text; obj oid;
BEGIN
    -- Catalog ACL checks are intentionally independent of names in provider schemas.
    FOR r IN SELECT n.nspname,n.nspowner,a.grantee,a.privilege_type,a.is_grantable
        FROM pg_catalog.pg_namespace n, LATERAL pg_catalog.aclexplode(
          COALESCE(n.nspacl,pg_catalog.acldefault('n',n.nspowner))) a
        WHERE n.nspname IN ('private','api') AND a.grantee<>n.nspowner LOOP
        IF r.is_grantable OR r.privilege_type<>'USAGE' OR NOT EXISTS (
            SELECT 1 FROM pg_catalog.pg_roles allowed WHERE allowed.oid=r.grantee AND (
              (r.nspname='private' AND allowed.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')) OR
              (r.nspname='api' AND allowed.rolname IN ('service_role','gym_owner_executor','gym_public_executor')))) THEN
            RAISE EXCEPTION 'Unexpected application schema privilege: %',r.nspname;
        END IF;
    END LOOP;
    FOREACH role_name IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
        IF pg_catalog.has_schema_privilege(role_name,'public','CREATE')
          OR pg_catalog.has_schema_privilege(role_name,'extensions','CREATE') THEN
            RAISE EXCEPTION 'Unsafe schema CREATE inherited by reserved role %',role_name;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_default_acl d, LATERAL pg_catalog.aclexplode(d.defaclacl) a
          WHERE d.defaclrole=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=role_name)
          AND d.defaclobjtype='f' AND a.grantee<>d.defaclrole) OR EXISTS (
          SELECT 1 FROM pg_catalog.aclexplode(COALESCE((SELECT d.defaclacl FROM pg_catalog.pg_default_acl d
            WHERE d.defaclrole=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=role_name)
              AND d.defaclobjtype='f' AND d.defaclnamespace=0),
            pg_catalog.acldefault('f',(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=role_name)))) a
          WHERE a.grantee<>(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=role_name)) THEN
            RAISE EXCEPTION 'Unsafe future function defaults for reserved role %',role_name;
        END IF;
    END LOOP;
    -- This legacy native testing role is optional. Never create or activate it.
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='gym_registration_login') THEN
        FOR r IN SELECT c.oid FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname='private' OR c.oid=pg_catalog.to_regclass('public.gym_settings') LOOP
            IF EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid=r.oid AND relkind IN ('r','p')) THEN
                IF pg_catalog.has_table_privilege('gym_registration_login',r.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
                  OR pg_catalog.has_any_column_privilege('gym_registration_login',r.oid,'SELECT,INSERT,UPDATE,REFERENCES') THEN
                    RAISE EXCEPTION 'Dormant legacy role has direct application access';
                END IF;
            ELSIF EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid=r.oid AND relkind='S') THEN
                IF pg_catalog.has_sequence_privilege('gym_registration_login',r.oid,'SELECT,USAGE,UPDATE') THEN
                    RAISE EXCEPTION 'Dormant legacy role has sequence access';
                END IF;
            END IF;
        END LOOP;
        FOR obj IN SELECT p.oid FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname IN ('private','api') LOOP
            IF pg_catalog.has_function_privilege('gym_registration_login',obj,'EXECUTE') THEN
                RAISE EXCEPTION 'Dormant legacy role has function access';
            END IF;
        END LOOP;
        IF pg_catalog.has_schema_privilege('gym_registration_login','private','USAGE,CREATE')
          OR pg_catalog.has_schema_privilege('gym_registration_login','api','USAGE,CREATE') THEN
            RAISE EXCEPTION 'Dormant legacy role has application schema access';
        END IF;
    END IF;
END;
$portable_boundaries$;

COMMIT;
