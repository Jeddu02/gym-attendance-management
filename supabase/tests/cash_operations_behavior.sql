\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT DO NOTHING;
SET LOCAL ROLE service_role;
DO $cash$
DECLARE owner_id uuid:='00000000-0000-4000-8000-000000000001'; opened jsonb; replay jsonb; closed jsonb; before_summary jsonb; after_summary jsonb;
BEGIN
 before_summary:=api.owner_dashboard_summary(owner_id);
 PERFORM api.owner_record_actual_receipt(owner_id,'71000000-0000-4000-8000-000000000001',125,'cash','Synthetic unmatched cash verified','CASH-SYNTHETIC',true,NULL);
 PERFORM api.owner_record_actual_receipt(owner_id,'71000000-0000-4000-8000-000000000002',500,'gcash','Synthetic electronic receipt','CASH-SYNTHETIC',true,NULL);
 opened:=api.owner_open_cash_drawer(owner_id,'71000000-0000-4000-8000-000000000003',100,true);
 replay:=api.owner_open_cash_drawer(owner_id,'71000000-0000-4000-8000-000000000003',100,true);
 IF replay->>'id' IS DISTINCT FROM opened->>'id' OR replay->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Opening retry changed session'; END IF;
 PERFORM set_config('gymforce.cash_drawer',opened->>'id',true);
 BEGIN
  PERFORM api.owner_close_cash_drawer(owner_id,(opened->>'id')::uuid,220,'','');
  RAISE EXCEPTION 'Missing variance evidence accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 closed:=api.owner_close_cash_drawer(owner_id,(opened->>'id')::uuid,220,'Synthetic five peso short count','CASH-COUNT-SYNTHETIC');
 -- Earlier committed synthetic concurrency fixtures may include verified cash.
 -- Assert complete basis using a trusted inspection below instead of invented zero baseline.
 IF (closed->>'variancePhp')::numeric<>220-(closed->>'expectedCashPhp')::numeric THEN RAISE EXCEPTION 'Variance was not computed'; END IF;
 replay:=api.owner_close_cash_drawer(owner_id,(opened->>'id')::uuid,220,'Synthetic five peso short count','CASH-COUNT-SYNTHETIC');
 IF replay->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Close retry not idempotent'; END IF;
 BEGIN
  PERFORM api.owner_close_cash_drawer(owner_id,(opened->>'id')::uuid,221,'Synthetic five peso short count','CASH-COUNT-SYNTHETIC');
  RAISE EXCEPTION 'Changed cash close retry accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 after_summary:=api.owner_dashboard_summary(owner_id);
 IF before_summary IS DISTINCT FROM after_summary THEN RAISE EXCEPTION 'Cash close or unallocated receipt changed income/access summary'; END IF;
 BEGIN
  PERFORM api.owner_list_cash_drawers('00000000-0000-4000-8000-000000000002',50,0);
  RAISE EXCEPTION 'Outsider read drawer';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $cash$;
RESET ROLE;
DO $snapshot$
DECLARE actual numeric; recorded numeric; r_id uuid;
BEGIN
 SELECT id,expected_cash_php INTO r_id,recorded FROM private.cash_reconciliations WHERE drawer_session_id=current_setting('gymforce.cash_drawer')::uuid;
 SELECT 100+COALESCE(sum(amount_php),0) INTO actual FROM private.cash_reconciliation_receipts WHERE reconciliation_id=r_id;
 IF actual IS DISTINCT FROM recorded OR EXISTS(SELECT 1 FROM private.cash_reconciliation_receipts r JOIN private.payment_records p ON p.id=r.payment_id WHERE reconciliation_id=r_id AND p.payment_method<>'cash')
 OR NOT EXISTS(SELECT 1 FROM private.cash_reconciliation_receipts r JOIN private.payment_records p ON p.id=r.payment_id WHERE reconciliation_id=r_id AND p.operation_id='71000000-0000-4000-8000-000000000001')
 THEN RAISE EXCEPTION 'Cash receipt snapshot mismatch or unallocated cash omitted'; END IF;
 BEGIN UPDATE private.cash_reconciliations SET counted_cash_php=0 WHERE id=r_id; RAISE EXCEPTION 'Reconciliation mutable'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN DELETE FROM private.cash_drawer_sessions; RAISE EXCEPTION 'Session deleted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $snapshot$;
ROLLBACK;
\echo 'PASS: attested opening, verified unallocated cash, electronic exclusion, immutable close, variance evidence, Owner denial and no income adjustment.'
