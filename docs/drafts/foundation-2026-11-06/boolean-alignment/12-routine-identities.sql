-- Structural metadata only. Run separately after protected preflight.
BEGIN READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='15s';
SELECT 1 / CASE WHEN current_database()='gymforce_pg18_test'
 AND inet_server_addr()='127.0.0.1'::inet AND inet_server_port()=55432
 AND current_user='postgres' AND session_user='postgres'
 AND (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
 AND current_setting('gymforce.test_cluster_marker',true)='f497fabb-a12f-4068-b745-8b0729279276'
 AND (pg_control_system()).system_identifier::text='7704603813616068820'
 AND lower(rtrim(replace(current_setting('data_directory'),E'\\','/'),'/'))='c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN 1 ELSE 0 END AS identity_guard \gset
WITH expected(name,signature,result,volatility,parallel,language,arg_names,arg_types,arg_modes,definer,strict,returns_set,input_count,default_count) AS (VALUES
('api.append_audit_event','api.append_audit_event(text, uuid, text, text, text, jsonb)','bigint','v','u','plpgsql',ARRAY['p_stream_key','p_actor_user_id','p_event_type','p_subject_type','p_subject_id','p_details']::text[],ARRAY['text','uuid','text','text','text','jsonb']::text[],ARRAY[]::text[],true,false,false,6,2),
('api.is_active_owner_for_user','api.is_active_owner_for_user(uuid)','boolean','s','u','sql',ARRAY['p_user_id']::text[],ARRAY['uuid']::text[],ARRAY[]::text[],true,false,false,1,0),
('api.member_enroll_pin','api.member_enroll_pin(text, text)','jsonb','v','u','plpgsql',ARRAY['p_token_hash','p_password_hash']::text[],ARRAY['text','text']::text[],ARRAY[]::text[],true,false,false,2,0),
('api.owner_confirm_membership_payment','api.owner_confirm_membership_payment(uuid, uuid, boolean)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_payment_id','p_evidence_reviewed']::text[],ARRAY['uuid','uuid','boolean']::text[],ARRAY[]::text[],true,false,false,3,0),
('api.owner_create_membership_purchase','api.owner_create_membership_purchase(uuid, uuid, uuid)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_member_id','p_plan_id']::text[],ARRAY['uuid','uuid','uuid']::text[],ARRAY[]::text[],true,false,false,3,0),
('api.owner_create_pin_enrollment_token','api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_member_id','p_token_hash','p_expires_at']::text[],ARRAY['uuid','uuid','text','timestamp with time zone']::text[],ARRAY[]::text[],true,false,false,4,0),
('api.owner_list_members','api.owner_list_members(uuid, text, text, integer, integer)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_search','p_status','p_limit','p_offset']::text[],ARRAY['uuid','text','text','integer','integer']::text[],ARRAY[]::text[],true,false,false,5,4),
('api.owner_list_membership_payments','api.owner_list_membership_payments(uuid, text, text, integer, integer)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_search','p_status','p_limit','p_offset']::text[],ARRAY['uuid','text','text','integer','integer']::text[],ARRAY[]::text[],true,false,false,5,4),
('api.owner_list_membership_plans','api.owner_list_membership_plans(uuid)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id']::text[],ARRAY['uuid']::text[],ARRAY[]::text[],true,false,false,1,0),
('api.owner_list_membership_purchases','api.owner_list_membership_purchases(uuid, text, text, integer, integer)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_search','p_status','p_limit','p_offset']::text[],ARRAY['uuid','text','text','integer','integer']::text[],ARRAY[]::text[],true,false,false,5,4),
('api.owner_record_membership_payment','api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_operation_id','p_membership_purchase_id','p_amount_php','p_payment_method','p_external_reference']::text[],ARRAY['uuid','uuid','uuid','numeric','text','text']::text[],ARRAY[]::text[],true,false,false,6,1),
('api.owner_register_member','api.owner_register_member(uuid, text, bytea, bytea)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_full_name','p_mobile_lookup_hash','p_mobile_encrypted']::text[],ARRAY['uuid','text','bytea','bytea']::text[],ARRAY[]::text[],true,false,false,4,0),
('api.owner_reject_membership_payment','api.owner_reject_membership_payment(uuid, uuid, text)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_payment_id','p_reason']::text[],ARRAY['uuid','uuid','text']::text[],ARRAY[]::text[],true,false,false,3,0),
('api.owner_save_membership_plan','api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','jsonb','v','u','plpgsql',ARRAY['p_actor_user_id','p_plan_id','p_name','p_price_php','p_is_active']::text[],ARRAY['uuid','uuid','text','numeric','boolean']::text[],ARRAY[]::text[],true,false,false,5,0),
('api.reserve_pin_enrollment_request','api.reserve_pin_enrollment_request()','jsonb','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('api.verify_audit_stream','api.verify_audit_stream(text)','table ( is_valid boolean , checked_events bigint , failure_event_id bigint , reason text )','v','u','plpgsql',ARRAY['p_stream_key','is_valid','checked_events','failure_event_id','reason']::text[],ARRAY['text','boolean','bigint','bigint','text']::text[],ARRAY['i','t','t','t','t']::text[],true,false,true,1,0),
('private.audit_events_chain_insert','private.audit_events_chain_insert()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.compute_audit_event_hash','private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','text','i','u','sql',ARRAY['p_id','p_stream_key','p_previous_event_hash','p_actor_user_id','p_event_type','p_subject_type','p_subject_id','p_details','p_created_at']::text[],ARRAY['bigint','text','text','uuid','text','text','text','jsonb','timestamp with time zone']::text[],ARRAY[]::text[],false,false,false,9,0),
('private.guard_membership_payment_allocation','private.guard_membership_payment_allocation()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.guard_membership_payment_record_insert','private.guard_membership_payment_record_insert()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.guard_membership_payment_record_update','private.guard_membership_payment_record_update()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.guard_purchase_pending_activation','private.guard_purchase_pending_activation()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.is_active_owner','private.is_active_owner()','boolean','s','u','sql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],false,false,false,0,0),
('private.prevent_audit_event_mutation','private.prevent_audit_event_mutation()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0),
('private.prevent_payment_history_mutation','private.prevent_payment_history_mutation()','trigger','v','u','plpgsql',ARRAY[]::text[],ARRAY[]::text[],ARRAY[]::text[],true,false,false,0,0))
SELECT e.name routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE(p.prokind='f' AND p.pronargs=e.input_count AND p.pronargdefaults=e.default_count,false) identity_shape_matches,
 COALESCE(COALESCE(p.proargnames,ARRAY[]::text[])=e.arg_names,false) argument_names_match,
 COALESCE((SELECT COALESCE(array_agg(format_type(a.type_oid,NULL) ORDER BY a.ord),ARRAY[]::text[])
 FROM unnest(COALESCE(p.proallargtypes,p.proargtypes::oid[])) WITH ORDINALITY a(type_oid,ord))=e.arg_types,false) argument_types_match,
 COALESCE(COALESCE(p.proargmodes::text[],ARRAY[]::text[])=e.arg_modes,false) argument_modes_match,
 COALESCE(regexp_replace(lower(pg_get_function_result(p.oid)),'[[:space:]]','','g')=regexp_replace(lower(e.result),'[[:space:]]','','g'),false) result_matches,
 COALESCE(p.provolatile::text=e.volatility AND p.proparallel::text=e.parallel AND l.lanname=e.language
 AND p.prosecdef=e.definer AND p.proisstrict=e.strict AND p.proretset=e.returns_set AND NOT p.proleakproof,false) security_metadata_matches,
 COALESCE(p.proconfig=ARRAY['search_path=""']::text[],false) search_path_matches
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
 LEFT JOIN pg_language l ON l.oid=p.prolang ORDER BY e.name;
ROLLBACK;
