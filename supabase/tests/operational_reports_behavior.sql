\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN RAISE EXCEPTION 'Synthetic target required'; END IF; END $guard$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT DO NOTHING;
SET LOCAL ROLE service_role;
DO $reports$
DECLARE actor uuid:='00000000-0000-4000-8000-000000000001'; today date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
 m jsonb; plan jsonb; purchase jsonb; receipt jsonb; before_total numeric; after_total numeric; counter integer;
BEGIN
 SELECT COALESCE(sum((r->>'amountPhp')::numeric),0) INTO before_total FROM jsonb_array_elements(api.owner_income_report(actor,today,today)) r WHERE r->>'source'='membership';
 m:=api.owner_register_member(actor,'Synthetic operational report',decode(repeat('d1',32),'hex'),decode(repeat('d2',32),'hex'));
 PERFORM api.owner_approve_member(actor,(m->>'id')::uuid,'Synthetic report registration approved');
 plan:=api.owner_save_membership_plan(actor,NULL,'Synthetic operational monthly',350,true);
 purchase:=api.owner_create_membership_purchase(actor,(m->>'id')::uuid,(plan->>'id')::uuid);
 receipt:=api.owner_record_membership_payment(actor,gen_random_uuid(),(purchase->>'id')::uuid,350,'cash',NULL);
 SELECT COALESCE(sum((r->>'amountPhp')::numeric),0) INTO after_total FROM jsonb_array_elements(api.owner_income_report(actor,today,today)) r WHERE r->>'source'='membership';
 IF after_total<>before_total THEN RAISE EXCEPTION 'Pending receipt in income'; END IF;
 PERFORM api.owner_confirm_membership_payment(actor,(receipt->>'id')::uuid,true);
 PERFORM api.owner_activate_membership_purchase(actor,(purchase->>'id')::uuid);
 SELECT COALESCE(sum((r->>'amountPhp')::numeric),0) INTO after_total FROM jsonb_array_elements(api.owner_income_report(actor,today,today)) r WHERE r->>'source'='membership';
 IF after_total<>before_total+350 THEN RAISE EXCEPTION 'Confirmed membership income missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_expiry_reminders(actor,31,100,0)) r WHERE r->>'memberCode'=m->>'member_code') THEN RAISE EXCEPTION 'Current unrenewed entitlement missing reminder'; END IF;
 -- A consecutive confirmed renewal suppresses a reminder for the old term.
 purchase:=api.owner_create_membership_purchase(actor,(m->>'id')::uuid,(plan->>'id')::uuid);
 receipt:=api.owner_record_membership_payment(actor,gen_random_uuid(),(purchase->>'id')::uuid,350,'gcash','SYNTHETIC-REPORT-RENEWAL');
 PERFORM api.owner_confirm_membership_payment(actor,(receipt->>'id')::uuid,true);
 PERFORM api.owner_activate_membership_purchase(actor,(purchase->>'id')::uuid);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_expiry_reminders(actor,31,100,0)) r WHERE r->>'memberCode'=m->>'member_code') THEN RAISE EXCEPTION 'Paid consecutive renewal still reminded'; END IF;
 PERFORM api.owner_void_payment_confirmation(actor,(receipt->>'id')::uuid,'Synthetic future renewal confirmation erroneous','SYNTHETIC-REPORT-VOID',true);
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_expiry_reminders(actor,31,100,0)) r WHERE r->>'memberCode'=m->>'member_code') THEN RAISE EXCEPTION 'Voided future renewal still suppresses reminder'; END IF;
 SELECT COALESCE(sum((r->>'amountPhp')::numeric),0) INTO after_total FROM jsonb_array_elements(api.owner_income_report(actor,today,today)) r WHERE r->>'source'='membership';
 IF after_total<>before_total+350 THEN RAISE EXCEPTION 'Voided income retained in report'; END IF;
 BEGIN PERFORM api.owner_income_report(actor,today-366,today); RAISE EXCEPTION 'Unbounded income range allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM api.owner_expiry_reminders(actor,32,50,0); RAISE EXCEPTION 'Invalid reminder window allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM api.owner_income_report('00000000-0000-4000-8000-000000000002',today,today); RAISE EXCEPTION 'Outsider report read'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 FOR counter IN 1..105 LOOP
  PERFORM api.owner_create_membership_purchase(actor,(m->>'id')::uuid,(plan->>'id')::uuid);
 END LOOP;
 IF jsonb_array_length(api.owner_list_payable_purchases(actor,m->>'member_code',10,100))<>5
 THEN RAISE EXCEPTION 'Payable search/pagination cannot reach beyond first 100 records'; END IF;
END $reports$;
RESET ROLE;
ROLLBACK;
\echo 'PASS: confirmed-only exact income, bounded Manila dates, paid current expiry reminders, consecutive renewal suppression, void handling and Owner denial.'
