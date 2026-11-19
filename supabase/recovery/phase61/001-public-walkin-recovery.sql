-- ADDITIVE LOCAL REVIEW ARTIFACT. Not registered in historical migrations.
-- Hosted execution/ownership authority and release remain separately gated.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='30s';
SET LOCAL search_path=pg_catalog;

CREATE TABLE private.walkin_creation_operations (
 contract_version pg_catalog.int4 NOT NULL CHECK(contract_version=1),
 capability_digest pg_catalog.bytea NOT NULL CHECK(pg_catalog.octet_length(capability_digest)=32),
 payment_method pg_catalog.text NOT NULL CHECK(payment_method IN ('cash','gcash','bank_transfer')),
 payload_fingerprint pg_catalog.bytea NOT NULL CHECK(pg_catalog.octet_length(payload_fingerprint)=32),
 request_id pg_catalog.uuid NOT NULL UNIQUE REFERENCES private.walkin_requests(id) ON DELETE RESTRICT,
 created_at pg_catalog.timestamptz NOT NULL,
 PRIMARY KEY(contract_version,capability_digest)
);
ALTER TABLE private.walkin_creation_operations OWNER TO gym_data_owner;
ALTER TABLE private.walkin_creation_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.walkin_creation_operations FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.walkin_creation_operations FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
GRANT SELECT(contract_version,capability_digest,payment_method,payload_fingerprint,request_id,created_at),
 INSERT(contract_version,capability_digest,payment_method,payload_fingerprint,request_id,created_at)
 ON private.walkin_creation_operations TO gym_public_executor;
GRANT SELECT(fee_php,currency,requested_payment_method,created_at,expires_at,request_status)
 ON private.walkin_requests TO gym_public_executor;
CREATE POLICY gf_public_select ON private.walkin_creation_operations FOR SELECT TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::pg_catalog.name);
CREATE POLICY gf_public_insert ON private.walkin_creation_operations FOR INSERT TO gym_public_executor WITH CHECK(CURRENT_USER='gym_public_executor'::pg_catalog.name);

CREATE FUNCTION private.recover_walkin_operation(p_digest pg_catalog.bytea,p_method pg_catalog.text,p_limit pg_catalog.int4)
RETURNS pg_catalog.jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path='' AS $body$
DECLARE op private.walkin_creation_operations%ROWTYPE; request RECORD;
 fingerprint pg_catalog.bytea; snapshot pg_catalog.jsonb; classification pg_catalog.text;
BEGIN
 IF p_digest IS NULL OR pg_catalog.octet_length(p_digest)<>32
 OR (p_method IS NOT NULL AND (p_method NOT IN ('cash','gcash','bank_transfer') OR p_limit IS NULL OR p_limit<1 OR p_limit>100))
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REQUEST'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymforce-walkin-recovery:v1:'||pg_catalog.encode(p_digest,'hex'),0));
 SELECT * INTO op FROM private.walkin_creation_operations WHERE contract_version=1 AND capability_digest=p_digest;
 IF p_method IS NOT NULL THEN
  fingerprint:=pg_catalog.sha256(pg_catalog.convert_to('gymforce:walkin-create:v1'||pg_catalog.chr(10)||'paymentMethod='||p_method||pg_catalog.chr(10),'UTF8'));
 END IF;
 IF FOUND THEN
  IF p_method IS NOT NULL AND (op.payment_method IS DISTINCT FROM p_method OR op.payload_fingerprint IS DISTINCT FROM fingerprint)
  THEN RETURN pg_catalog.jsonb_build_object('classification','OPERATION_CONFLICT'); END IF;
  SELECT id,fee_php,currency,requested_payment_method,created_at,expires_at,request_status
  INTO STRICT request FROM private.walkin_requests WHERE id=op.request_id;
  IF request.requested_payment_method IS DISTINCT FROM op.payment_method OR request.created_at IS DISTINCT FROM op.created_at
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='RECOVERY_BINDING_INVALID'; END IF;
  IF request.expires_at<=pg_catalog.clock_timestamp() OR request.request_status<>'pending'
  THEN RETURN pg_catalog.jsonb_build_object('classification','RECOVERY_CLOSED'); END IF;
  snapshot:=pg_catalog.jsonb_build_object('id',request.id,'feePhp',request.fee_php::pg_catalog.text,'currency',request.currency,
   'paymentMethod',request.requested_payment_method,'createdAt',request.created_at,'expiresAt',request.expires_at);
  classification:='PROVISIONAL_RECOVERED';
 ELSE
  IF p_method IS NULL THEN RETURN pg_catalog.jsonb_build_object('classification','NO_RECOVERABLE_OUTCOME'); END IF;
  -- Existing server fee/rate/snapshot rules remain authoritative in this transaction.
  snapshot:=api.public_create_walkin_request(p_method,p_limit);
  INSERT INTO private.walkin_creation_operations(contract_version,capability_digest,payment_method,payload_fingerprint,request_id,created_at)
  VALUES(1,p_digest,p_method,fingerprint,(snapshot->>'id')::pg_catalog.uuid,(snapshot->>'createdAt')::pg_catalog.timestamptz);
  snapshot:=pg_catalog.jsonb_set(snapshot,'{feePhp}',pg_catalog.to_jsonb(snapshot->>'feePhp'));
  classification:='PROVISIONAL_CREATED';
 END IF;
 RETURN pg_catalog.jsonb_build_object('classification',classification,'request',snapshot);
END;
$body$;
ALTER FUNCTION private.recover_walkin_operation(bytea,text,integer) OWNER TO gym_data_owner;
REVOKE ALL ON FUNCTION private.recover_walkin_operation(bytea,text,integer) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.recover_walkin_operation(bytea,text,integer) TO gym_public_executor;

CREATE FUNCTION api.public_create_walkin_request_v2(p_capability_digest pg_catalog.bytea,p_payment_method pg_catalog.text,p_request_limit pg_catalog.int4)
RETURNS pg_catalog.jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $body$
BEGIN
 IF p_payment_method IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REQUEST'; END IF;
 RETURN private.recover_walkin_operation(p_capability_digest,p_payment_method,p_request_limit);
END;
$body$;
CREATE FUNCTION api.public_lookup_walkin_request(p_capability_digest pg_catalog.bytea)
RETURNS pg_catalog.jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $body$
BEGIN RETURN private.recover_walkin_operation(p_capability_digest,NULL,NULL); END;
$body$;
ALTER FUNCTION api.public_create_walkin_request_v2(bytea,text,integer) OWNER TO gym_public_executor;
ALTER FUNCTION api.public_lookup_walkin_request(bytea) OWNER TO gym_public_executor;
REVOKE ALL ON FUNCTION api.public_create_walkin_request_v2(bytea,text,integer),api.public_lookup_walkin_request(bytea)
 FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION api.public_create_walkin_request_v2(bytea,text,integer),api.public_lookup_walkin_request(bytea) TO service_role;
-- Close the unkeyed transport path at this additive stage. The public executor
-- still owns the original routine and calls it internally within the keyed RPC.
-- Historical source, signature and business guards remain unchanged.
REVOKE EXECUTE ON FUNCTION api.public_create_walkin_request(text,integer) FROM service_role;
COMMIT;
