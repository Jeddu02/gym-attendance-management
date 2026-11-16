-- OWNER REVIEW COPY. Generated baseline matrices copied from the FIRST (pre-change)
-- assertion block of 20261110100000_executor_hardening.sql. No DDL or RPC calls.
-- This is a screening subset, not the migration's complete policy/ACL/constraint proof.
-- Run now to inventory gaps; a FAIL against the stage-24 baseline is expected if
-- the four November 3 migrations are genuinely absent. Do not repair or skip them.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;

-- Body/owner/security/config checks emit booleans, never function source or hashes.
WITH expected(signature,body_md5,target_owner,target_definer,baseline_definer,callers) AS (VALUES
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
), resolved AS (SELECT e.*,pg_catalog.to_regprocedure(e.signature) AS oid FROM expected e)
SELECT e.signature,p.oid IS NOT NULL AS exists,
 CASE WHEN p.oid IS NULL THEN 'FAIL'
  WHEN pg_catalog.md5(p.prosrc)=e.body_md5 AND p.proowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
   AND p.prosecdef=e.baseline_definer::boolean AND p.proconfig=ARRAY['search_path=""']::text[] THEN 'PASS'
  ELSE 'FAIL' END AS hardening_input_body_owner_config,
 CASE WHEN p.oid IS NULL THEN NULL ELSE pg_catalog.md5(p.prosrc)=e.body_md5 END AS body_matches_source
FROM resolved e LEFT JOIN pg_catalog.pg_proc p ON p.oid=e.oid ORDER BY e.signature;

WITH expected(signature,language,volatility,parallel,strict,returns_set,leakproof,default_count) AS (VALUES
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
)
SELECT e.signature,CASE WHEN p.oid IS NOT NULL AND p.prokind='f' AND l.lanname=e.language
 AND p.provolatile::text=e.volatility AND p.proparallel::text=e.parallel
 AND p.proisstrict=e.strict AND p.proretset=e.returns_set AND p.proleakproof=e.leakproof
 AND p.pronargdefaults=e.default_count AND p.prosupport=0 AND p.provariadic=0
 AND p.probin IS NULL AND p.prosqlbody IS NULL THEN 'PASS' ELSE 'FAIL' END AS execution_metadata
FROM expected e LEFT JOIN pg_catalog.pg_proc p ON p.oid=pg_catalog.to_regprocedure(e.signature)
LEFT JOIN pg_catalog.pg_language l ON l.oid=p.prolang ORDER BY 1;

WITH expected(name,columns) AS (VALUES
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
)
SELECT e.name AS relation,c.oid IS NOT NULL AS exists,
 CASE WHEN c.oid IS NOT NULL AND (SELECT string_agg(a.attname||':'||pg_catalog.format_type(a.atttypid,a.atttypmod),'|' ORDER BY a.attnum)
  FROM pg_catalog.pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped)=e.columns
  THEN 'PASS' ELSE 'FAIL' END AS ordered_column_types,
 CASE WHEN c.oid IS NOT NULL AND c.relrowsecurity AND c.relowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
  THEN 'PASS' ELSE 'FAIL' END AS baseline_owner_and_rls
FROM expected e LEFT JOIN pg_catalog.pg_class c ON c.oid=pg_catalog.to_regclass(e.name) ORDER BY 1;

-- Source preconditions for reserved roles: absent roles are created by the
-- migration, but that creation path still requires isolated authority testing.
WITH expected(name) AS (VALUES ('gym_data_owner'),('gym_owner_executor'),('gym_public_executor'))
SELECT e.name AS reserved_role,CASE WHEN r.oid IS NULL THEN 'UNKNOWN: absent; creation authority unproved'
 WHEN r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls
  OR EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members a WHERE a.roleid=r.oid OR a.member=r.oid) THEN 'FAIL'
 ELSE 'PASS' END AS role_attributes_and_isolation
FROM expected e LEFT JOIN pg_catalog.pg_roles r ON r.rolname=e.name ORDER BY 1;

SELECT check_name,CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result FROM (VALUES
 ('protected_table_count_22',(SELECT count(*)=22 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind IN ('r','p') AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')))),
 ('private_sequence_count_3',(SELECT count(*)=3 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='private' AND c.relkind='S')),
 ('application_trigger_count_13',(SELECT count(*)=13 FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal
  AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')))),
 ('api_has_no_data_relations',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='api' AND c.relkind IN ('r','p','v','m','S','f'))),
 ('application_has_no_rewrite_rules',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_rewrite rw JOIN pg_catalog.pg_class c ON c.oid=rw.ev_class
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings'))),
 ('private_constraints_validated',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint k JOIN pg_catalog.pg_namespace n ON n.oid=k.connamespace
  WHERE n.nspname='private' AND NOT k.convalidated)),
 ('pgcrypto_digest_dependency',EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_depend d
  ON d.classid='pg_catalog.pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e'
  JOIN pg_catalog.pg_extension e ON e.oid=d.refobjid JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace
  WHERE p.oid=pg_catalog.to_regprocedure('extensions.digest(bytea,text)') AND e.extname='pgcrypto'
  AND n.nspname='extensions' AND NOT p.prosecdef AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles r
   WHERE r.oid=p.proowner AND r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor'))))
) x(check_name,ok);
ROLLBACK;
