BEGIN;

-- Payment attempts are tied to their intended purchase independently of
-- allocation. Only a confirmed payment receives a whole-receipt allocation.
ALTER TABLE private.payment_records
    ADD COLUMN operation_id uuid NOT NULL DEFAULT gen_random_uuid(),
    ADD COLUMN target_membership_purchase_id uuid
        REFERENCES private.membership_purchases(id) ON DELETE RESTRICT;

CREATE UNIQUE INDEX payment_records_operation_id_uidx
    ON private.payment_records (operation_id);

CREATE INDEX payment_records_membership_idx
    ON private.payment_records (target_membership_purchase_id, created_at DESC)
    WHERE target_membership_purchase_id IS NOT NULL;

CREATE UNIQUE INDEX payment_records_membership_external_reference_uidx
    ON private.payment_records (
        payment_method,
        pg_catalog.lower(pg_catalog.btrim(external_reference))
    )
    WHERE target_membership_purchase_id IS NOT NULL
      AND NULLIF(pg_catalog.btrim(external_reference), '') IS NOT NULL;

-- Permit only one unresolved attempt per purchase. Rejected records stay in
-- the ledger, while a corrected/new payment attempt can still be recorded.
CREATE UNIQUE INDEX payment_records_pending_membership_uidx
    ON private.payment_records (target_membership_purchase_id)
    WHERE target_membership_purchase_id IS NOT NULL
      AND verification_status = 'recorded';

-- A purchase may receive at most one allocation, regardless of how many
-- rejected attempts are retained in payment_records.
CREATE UNIQUE INDEX payment_allocations_membership_purchase_uidx
    ON private.payment_allocations (membership_purchase_id)
    WHERE membership_purchase_id IS NOT NULL;

CREATE OR REPLACE FUNCTION private.guard_membership_payment_record_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_purchase_price numeric(12,2);
BEGIN
    IF NEW.target_membership_purchase_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT price_php INTO v_purchase_price
    FROM private.membership_purchases
    WHERE id = NEW.target_membership_purchase_id
    FOR KEY SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'MEMBERSHIP_PURCHASE_NOT_FOUND';
    END IF;

    IF NEW.verification_status = 'recorded'
       AND NEW.amount_php <> v_purchase_price THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'MEMBERSHIP_PAYMENT_MUST_MATCH_FULL_PRICE';
    END IF;

    IF NEW.verification_status = 'confirmed' THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'MEMBERSHIP_PAYMENT_REQUIRES_EXPLICIT_CONFIRMATION';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER payment_records_validate_membership_insert
BEFORE INSERT ON private.payment_records
FOR EACH ROW
EXECUTE FUNCTION private.guard_membership_payment_record_insert();

CREATE OR REPLACE FUNCTION private.guard_membership_payment_record_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF OLD.verification_status <> 'recorded'
       OR NEW.verification_status NOT IN ('confirmed', 'rejected') THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'PAYMENT_RECORD_IMMUTABLE';
    END IF;

    IF ROW(
        NEW.id, NEW.amount_php, NEW.payment_method, NEW.received_at,
        NEW.external_reference, NEW.evidence_reference, NEW.recorded_by,
        NEW.created_at, NEW.operation_id, NEW.target_membership_purchase_id
    ) IS DISTINCT FROM ROW(
        OLD.id, OLD.amount_php, OLD.payment_method, OLD.received_at,
        OLD.external_reference, OLD.evidence_reference, OLD.recorded_by,
        OLD.created_at, OLD.operation_id, OLD.target_membership_purchase_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'PAYMENT_RECEIPT_FACTS_IMMUTABLE';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER payment_records_guard_update
BEFORE UPDATE ON private.payment_records
FOR EACH ROW
EXECUTE FUNCTION private.guard_membership_payment_record_update();

CREATE OR REPLACE FUNCTION private.guard_membership_payment_allocation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_payment private.payment_records%ROWTYPE;
    v_purchase private.membership_purchases%ROWTYPE;
BEGIN
    IF NEW.membership_purchase_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_payment
    FROM private.payment_records
    WHERE id = NEW.payment_id
    FOR KEY SHARE;

    SELECT * INTO v_purchase
    FROM private.membership_purchases
    WHERE id = NEW.membership_purchase_id
    FOR KEY SHARE;

    IF NOT FOUND
       OR v_payment.target_membership_purchase_id IS DISTINCT FROM v_purchase.id
       OR v_payment.verification_status <> 'confirmed'
       OR v_payment.amount_php <> v_purchase.price_php THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'MEMBERSHIP_PAYMENT_ALLOCATION_INVALID';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER payment_allocations_validate_membership
BEFORE INSERT ON private.payment_allocations
FOR EACH ROW
EXECUTE FUNCTION private.guard_membership_payment_allocation();

CREATE OR REPLACE FUNCTION private.prevent_payment_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'PAYMENT_HISTORY_APPEND_ONLY';
END;
$function$;

CREATE TRIGGER payment_events_no_update_delete
BEFORE UPDATE OR DELETE ON private.payment_events
FOR EACH ROW
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE TRIGGER payment_events_no_truncate
BEFORE TRUNCATE ON private.payment_events
FOR EACH STATEMENT
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE TRIGGER payment_records_no_delete
BEFORE DELETE ON private.payment_records
FOR EACH ROW
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE TRIGGER payment_records_no_truncate
BEFORE TRUNCATE ON private.payment_records
FOR EACH STATEMENT
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE TRIGGER payment_allocations_no_update_delete
BEFORE UPDATE OR DELETE ON private.payment_allocations
FOR EACH ROW
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE TRIGGER payment_allocations_no_truncate
BEFORE TRUNCATE ON private.payment_allocations
FOR EACH STATEMENT
EXECUTE FUNCTION private.prevent_payment_history_mutation();

CREATE OR REPLACE FUNCTION private.guard_purchase_pending_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_entering_pending_activation boolean;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_entering_pending_activation := NEW.purchase_status = 'pending_activation';
    ELSE
        v_entering_pending_activation := NEW.purchase_status = 'pending_activation'
            AND OLD.purchase_status IS DISTINCT FROM NEW.purchase_status;
    END IF;

    IF v_entering_pending_activation AND NOT EXISTS (
           SELECT 1
           FROM private.payment_allocations allocation
           JOIN private.payment_records payment
             ON payment.id = allocation.payment_id
           WHERE allocation.membership_purchase_id = NEW.id
             AND payment.target_membership_purchase_id = NEW.id
             AND payment.verification_status = 'confirmed'
             AND payment.amount_php = NEW.price_php
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'PURCHASE_REQUIRES_CONFIRMED_FULL_PAYMENT';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER membership_purchase_requires_confirmed_payment
BEFORE INSERT OR UPDATE ON private.membership_purchases
FOR EACH ROW
EXECUTE FUNCTION private.guard_purchase_pending_activation();

CREATE OR REPLACE FUNCTION api.owner_record_membership_payment(
    p_actor_user_id uuid,
    p_operation_id uuid,
    p_membership_purchase_id uuid,
    p_amount_php numeric,
    p_payment_method text,
    p_external_reference text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_existing private.payment_records%ROWTYPE;
    v_purchase private.membership_purchases%ROWTYPE;
    v_payment private.payment_records%ROWTYPE;
    v_external_reference text := NULLIF(pg_catalog.btrim(p_external_reference), '');
    v_reason text;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;

    IF p_operation_id IS NULL
       OR p_membership_purchase_id IS NULL
       OR p_amount_php IS NULL
       OR p_amount_php <= 0
       OR p_amount_php > 9999999999.99
       OR p_amount_php <> pg_catalog.round(p_amount_php, 2)
       OR p_payment_method IS NULL
       OR p_payment_method NOT IN ('cash', 'gcash', 'bank_transfer')
       OR pg_catalog.char_length(COALESCE(p_external_reference, '')) > 120
       THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_MEMBERSHIP_PAYMENT';
    END IF;

    SELECT * INTO v_existing
    FROM private.payment_records
    WHERE operation_id = p_operation_id
    FOR UPDATE;

    IF FOUND THEN
        IF v_existing.target_membership_purchase_id IS DISTINCT FROM p_membership_purchase_id
           OR v_existing.amount_php <> p_amount_php
           OR v_existing.payment_method <> p_payment_method
           OR v_existing.external_reference IS DISTINCT FROM v_external_reference
           OR v_existing.recorded_by IS DISTINCT FROM p_actor_user_id THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'PAYMENT_OPERATION_ID_REUSED';
        END IF;
        RETURN pg_catalog.jsonb_build_object(
            'id', v_existing.id,
            'purchaseId', v_existing.target_membership_purchase_id,
            'amountPhp', v_existing.amount_php,
            'paymentMethod', v_existing.payment_method,
            'verificationStatus', v_existing.verification_status,
            'createdAt', v_existing.created_at,
            'replayed', true
        );
    END IF;

    SELECT * INTO v_purchase
    FROM private.membership_purchases
    WHERE id = p_membership_purchase_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'MEMBERSHIP_PURCHASE_NOT_FOUND';
    END IF;

    IF v_purchase.purchase_status <> 'pending_payment'
       OR EXISTS (
           SELECT 1 FROM private.payment_allocations a
           WHERE a.membership_purchase_id = v_purchase.id
       ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'PURCHASE_NOT_AWAITING_PAYMENT';
    END IF;

    IF EXISTS (
        SELECT 1 FROM private.payment_records p
        WHERE p.target_membership_purchase_id = v_purchase.id
          AND p.verification_status = 'recorded'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'PAYMENT_AWAITING_DECISION';
    END IF;

    IF p_amount_php <> v_purchase.price_php THEN
        v_reason := 'Payment amount must exactly equal the purchase price.';
        INSERT INTO private.payment_records (
            amount_php, payment_method, verification_status,
            external_reference, recorded_by, operation_id,
            target_membership_purchase_id
        ) VALUES (
            p_amount_php, p_payment_method, 'rejected',
            v_external_reference, p_actor_user_id, p_operation_id,
            v_purchase.id
        ) RETURNING * INTO v_payment;

        INSERT INTO private.payment_events(payment_id, event_type, reason, actor_user_id)
        VALUES (v_payment.id, 'payment.rejected', v_reason, p_actor_user_id);

        PERFORM api.append_audit_event(
            'payments', p_actor_user_id, 'payment.rejected', 'payment',
            v_payment.id::text,
            pg_catalog.jsonb_build_object(
                'purchase_id', v_purchase.id,
                'amount_php', v_payment.amount_php,
                'expected_amount_php', v_purchase.price_php,
                'payment_method', v_payment.payment_method,
                'reason', 'amount_mismatch'
            )
        );
    ELSE
        INSERT INTO private.payment_records (
            amount_php, payment_method, verification_status,
            external_reference, recorded_by, operation_id,
            target_membership_purchase_id
        ) VALUES (
            p_amount_php, p_payment_method, 'recorded',
            v_external_reference, p_actor_user_id, p_operation_id,
            v_purchase.id
        ) RETURNING * INTO v_payment;

        INSERT INTO private.payment_events(payment_id, event_type, actor_user_id)
        VALUES (v_payment.id, 'payment.recorded', p_actor_user_id);

        PERFORM api.append_audit_event(
            'payments', p_actor_user_id, 'payment.recorded', 'payment',
            v_payment.id::text,
            pg_catalog.jsonb_build_object(
                'purchase_id', v_purchase.id,
                'amount_php', v_payment.amount_php,
                'payment_method', v_payment.payment_method,
                'verification_status', v_payment.verification_status
            )
        );
    END IF;

    RETURN pg_catalog.jsonb_build_object(
        'id', v_payment.id,
        'purchaseId', v_purchase.id,
        'amountPhp', v_payment.amount_php,
        'paymentMethod', v_payment.payment_method,
        'verificationStatus', v_payment.verification_status,
        'createdAt', v_payment.created_at,
        'replayed', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION api.owner_confirm_membership_payment(
    p_actor_user_id uuid,
    p_payment_id uuid,
    p_evidence_reviewed boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_payment private.payment_records%ROWTYPE;
    v_purchase private.membership_purchases%ROWTYPE;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_payment_id IS NULL OR p_evidence_reviewed IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_PAYMENT_CONFIRMATION';
    END IF;

    SELECT * INTO v_payment
    FROM private.payment_records
    WHERE id = p_payment_id AND target_membership_purchase_id IS NOT NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'PAYMENT_NOT_FOUND';
    END IF;
    IF v_payment.verification_status <> 'recorded' THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'PAYMENT_NOT_AWAITING_DECISION';
    END IF;
    IF v_payment.payment_method IN ('gcash', 'bank_transfer')
       AND p_evidence_reviewed IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'PAYMENT_EVIDENCE_REVIEW_REQUIRED';
    END IF;

    SELECT * INTO v_purchase
    FROM private.membership_purchases
    WHERE id = v_payment.target_membership_purchase_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'MEMBERSHIP_PURCHASE_NOT_FOUND';
    END IF;
    IF v_purchase.purchase_status <> 'pending_payment'
       OR v_payment.amount_php <> v_purchase.price_php
       OR EXISTS (
           SELECT 1 FROM private.payment_allocations a
           WHERE a.membership_purchase_id = v_purchase.id
       ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'PURCHASE_PAYMENT_CONFLICT';
    END IF;

    UPDATE private.payment_records
    SET verification_status = 'confirmed'
    WHERE id = v_payment.id;

    INSERT INTO private.payment_allocations(
        payment_id, membership_purchase_id, allocated_by
    ) VALUES (v_payment.id, v_purchase.id, p_actor_user_id);

    UPDATE private.membership_purchases
    SET purchase_status = 'pending_activation'
    WHERE id = v_purchase.id;

    INSERT INTO private.payment_events(payment_id, event_type, reason, actor_user_id)
    VALUES (
        v_payment.id,
        'payment.confirmed',
        CASE WHEN v_payment.payment_method = 'cash'
             THEN 'Owner confirmed cash receipt.'
             ELSE 'Owner reviewed actual receipt/evidence and confirmed receipt.'
        END,
        p_actor_user_id
    );

    PERFORM api.append_audit_event(
        'payments', p_actor_user_id, 'payment.confirmed', 'payment',
        v_payment.id::text,
        pg_catalog.jsonb_build_object(
            'purchase_id', v_purchase.id,
            'amount_php', v_payment.amount_php,
            'payment_method', v_payment.payment_method,
            'evidence_reviewed', p_evidence_reviewed,
            'purchase_status', 'pending_activation'
        )
    );

    RETURN pg_catalog.jsonb_build_object(
        'paymentId', v_payment.id,
        'purchaseId', v_purchase.id,
        'verificationStatus', 'confirmed',
        'purchaseStatus', 'pending_activation'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION api.owner_reject_membership_payment(
    p_actor_user_id uuid,
    p_payment_id uuid,
    p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_payment private.payment_records%ROWTYPE;
    v_reason text := pg_catalog.btrim(COALESCE(p_reason, ''));
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF p_payment_id IS NULL OR pg_catalog.char_length(v_reason) < 5
       OR pg_catalog.char_length(v_reason) > 500 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_PAYMENT_REJECTION';
    END IF;

    SELECT * INTO v_payment
    FROM private.payment_records
    WHERE id = p_payment_id AND target_membership_purchase_id IS NOT NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'PAYMENT_NOT_FOUND';
    END IF;
    IF v_payment.verification_status <> 'recorded' THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'PAYMENT_NOT_AWAITING_DECISION';
    END IF;

    UPDATE private.payment_records
    SET verification_status = 'rejected'
    WHERE id = v_payment.id;

    INSERT INTO private.payment_events(payment_id, event_type, reason, actor_user_id)
    VALUES (v_payment.id, 'payment.rejected', v_reason, p_actor_user_id);

    PERFORM api.append_audit_event(
        'payments', p_actor_user_id, 'payment.rejected', 'payment',
        v_payment.id::text,
        pg_catalog.jsonb_build_object(
            'purchase_id', v_payment.target_membership_purchase_id,
            'amount_php', v_payment.amount_php,
            'payment_method', v_payment.payment_method,
            'reason', v_reason
        )
    );

    RETURN pg_catalog.jsonb_build_object(
        'paymentId', v_payment.id,
        'verificationStatus', 'rejected'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION api.owner_list_membership_payments(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_search text := NULLIF(pg_catalog.btrim(p_search), '');
    v_status text := COALESCE(NULLIF(pg_catalog.btrim(p_status), ''), 'all');
    v_payments jsonb;
    v_purchases jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF (v_search IS NOT NULL AND pg_catalog.char_length(v_search) > 80)
       OR v_status NOT IN ('all', 'recorded', 'confirmed', 'rejected')
       OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_PAYMENT_LIST_FILTER';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.payment_id,
                'purchaseId', page.purchase_id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'purchasePricePhp', page.purchase_price_php,
                'amountPhp', page.amount_php,
                'paymentMethod', page.payment_method,
                'verificationStatus', page.verification_status,
                'externalReference', page.external_reference,
                'createdAt', page.created_at,
                'receivedAt', page.received_at,
                'decisionReason', page.decision_reason
            ) ORDER BY page.created_at DESC, page.payment_id
        ),
        '[]'::jsonb
    ) INTO v_payments
    FROM (
        SELECT
            payment.id AS payment_id,
            purchase.id AS purchase_id,
            member.full_name AS member_name,
            member.member_code,
            plan.name AS plan_name,
            purchase.price_php AS purchase_price_php,
            payment.amount_php,
            payment.payment_method,
            payment.verification_status,
            payment.external_reference,
            payment.created_at,
            payment.received_at,
            latest_event.reason AS decision_reason
        FROM private.payment_records payment
        JOIN private.membership_purchases purchase
          ON purchase.id = payment.target_membership_purchase_id
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        LEFT JOIN LATERAL (
            SELECT event.reason
            FROM private.payment_events event
            WHERE event.payment_id = payment.id
              AND event.event_type IN ('payment.confirmed', 'payment.rejected')
            ORDER BY event.created_at DESC, event.id DESC
            LIMIT 1
        ) latest_event ON true
        WHERE (v_status = 'all' OR payment.verification_status = v_status)
          AND (
              v_search IS NULL
              OR pg_catalog.strpos(pg_catalog.lower(payment.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(purchase.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.full_name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.member_code), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(plan.name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(COALESCE(payment.external_reference, '')), pg_catalog.lower(v_search)) > 0
          )
        ORDER BY payment.created_at DESC, payment.id
        LIMIT p_limit OFFSET p_offset
    ) page;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.purchase_id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'pricePhp', page.price_php
            ) ORDER BY page.created_at DESC, page.purchase_id
        ),
        '[]'::jsonb
    ) INTO v_purchases
    FROM (
        SELECT purchase.id AS purchase_id, member.full_name AS member_name,
               member.member_code, plan.name AS plan_name,
               purchase.price_php, purchase.created_at
        FROM private.membership_purchases purchase
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        WHERE purchase.purchase_status = 'pending_payment'
          AND NOT EXISTS (
              SELECT 1 FROM private.payment_records payment
              WHERE payment.target_membership_purchase_id = purchase.id
                AND payment.verification_status = 'recorded'
          )
          AND NOT EXISTS (
              SELECT 1 FROM private.payment_allocations allocation
              WHERE allocation.membership_purchase_id = purchase.id
          )
        ORDER BY purchase.created_at DESC, purchase.id
        LIMIT 100
    ) page;

    RETURN pg_catalog.jsonb_build_object(
        'payments', v_payments,
        'payablePurchases', v_purchases
    );
END;
$function$;

-- Add the latest attempt status to purchase history without exposing ledger
-- tables to browser roles.
CREATE OR REPLACE FUNCTION api.owner_list_membership_purchases(
    p_actor_user_id uuid,
    p_search text DEFAULT NULL,
    p_status text DEFAULT 'all',
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_search text := NULLIF(pg_catalog.btrim(p_search), '');
    v_status text := COALESCE(NULLIF(pg_catalog.btrim(p_status), ''), 'all');
    v_purchases jsonb;
BEGIN
    IF p_actor_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM private.owner_access oa
        WHERE oa.user_id = p_actor_user_id AND oa.is_active = true
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'OWNER_ACCESS_REQUIRED';
    END IF;
    IF (v_search IS NOT NULL AND pg_catalog.char_length(v_search) > 80)
       OR v_status NOT IN ('all', 'pending_payment', 'pending_activation', 'active', 'expired', 'payment_review')
       OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100
       OR p_offset IS NULL OR p_offset < 0 OR p_offset > 100000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'INVALID_MEMBERSHIP_PURCHASE_FILTER';
    END IF;

    SELECT COALESCE(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', page.id,
                'memberName', page.member_name,
                'memberCode', page.member_code,
                'planName', page.plan_name,
                'pricePhp', page.price_php,
                'purchaseStatus', page.purchase_status,
                'activationDate', page.activation_date,
                'expiryDate', page.expiry_date,
                'createdAt', page.created_at,
                'paymentStatus', page.payment_status,
                'paymentMethod', page.payment_method
            ) ORDER BY page.created_at DESC, page.id
        ),
        '[]'::jsonb
    ) INTO v_purchases
    FROM (
        SELECT purchase.id, member.full_name AS member_name,
               member.member_code, plan.name AS plan_name,
               purchase.price_php, purchase.purchase_status,
               purchase.activation_date, purchase.expiry_date,
               purchase.created_at, latest_payment.verification_status AS payment_status,
               latest_payment.payment_method
        FROM private.membership_purchases purchase
        JOIN private.members member ON member.id = purchase.member_id
        JOIN private.membership_plans plan ON plan.id = purchase.plan_id
        LEFT JOIN LATERAL (
            SELECT payment.verification_status, payment.payment_method
            FROM private.payment_records payment
            WHERE payment.target_membership_purchase_id = purchase.id
            ORDER BY payment.created_at DESC, payment.id DESC
            LIMIT 1
        ) latest_payment ON true
        WHERE (v_status = 'all' OR purchase.purchase_status = v_status)
          AND (
              v_search IS NULL
              OR pg_catalog.strpos(pg_catalog.lower(purchase.id::text), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.full_name), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(member.member_code), pg_catalog.lower(v_search)) > 0
              OR pg_catalog.strpos(pg_catalog.lower(plan.name), pg_catalog.lower(v_search)) > 0
          )
        ORDER BY purchase.created_at DESC, purchase.id
        LIMIT p_limit OFFSET p_offset
    ) page;
    RETURN v_purchases;
END;
$function$;

REVOKE ALL ON FUNCTION api.owner_record_membership_payment(
    uuid, uuid, uuid, numeric, text, text
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.owner_reject_membership_payment(uuid, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.guard_membership_payment_record_update()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.guard_membership_payment_record_insert()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.guard_membership_payment_allocation()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.prevent_payment_history_mutation()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.guard_purchase_pending_activation()
    FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA api TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_record_membership_payment(
    uuid, uuid, uuid, numeric, text, text
) TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean)
    TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_reject_membership_payment(uuid, uuid, text)
    TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer)
    TO service_role;
GRANT EXECUTE ON FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer)
    TO service_role;

REVOKE ALL ON private.payment_records, private.payment_allocations, private.payment_events
    FROM PUBLIC, anon, authenticated;

COMMIT;
