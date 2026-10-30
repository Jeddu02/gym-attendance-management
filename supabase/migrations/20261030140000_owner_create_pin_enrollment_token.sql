begin;

create index if not exists member_pin_setup_tokens_active_enrollment_idx
    on private.member_pin_setup_tokens (member_id)
    where token_purpose = 'enrollment'
      and consumed_at is null;

create or replace function api.owner_create_pin_enrollment_token(
    p_actor_user_id uuid,
    p_member_id uuid,
    p_token_hash text,
    p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
    v_member_status text;
    v_token_id uuid;
begin
    -- Require an active owner.
    if p_actor_user_id is null or not exists (
        select 1
        from private.owner_access oa
        where oa.user_id = p_actor_user_id
          and oa.is_active = true
    ) then
        raise exception using
            errcode = '42501',
            message = 'OWNER_ACCESS_REQUIRED';
    end if;

    -- Validate token hash and expiration.
    if p_member_id is null
       or p_token_hash is null
       or p_token_hash !~ '^[0-9a-f]{64}$'
       or p_expires_at is null
       or p_expires_at <= pg_catalog.now()
       or p_expires_at > pg_catalog.now() + interval '30 minutes' then
        raise exception using
            errcode = '22023',
            message = 'INVALID_ENROLLMENT_TOKEN';
    end if;

    -- Serialize token creation for this member.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            'pin-enrollment:' || p_member_id::text,
            0
        )
    );

    select m.status
    into v_member_status
    from private.members m
    where m.id = p_member_id
    for update;

    if not found
       or v_member_status not in ('pending', 'active') then
        raise exception using
            errcode = 'P0002',
            message = 'MEMBER_NOT_ELIGIBLE';
    end if;

    -- Invalidate previous unused enrollment tokens.
    update private.member_pin_setup_tokens
    set consumed_at = pg_catalog.now()
    where member_id = p_member_id
      and token_purpose = 'enrollment'
      and consumed_at is null;

    -- Store only the token hash.
    insert into private.member_pin_setup_tokens (
        member_id,
        token_hash,
        token_purpose,
        expires_at
    )
    values (
        p_member_id,
        p_token_hash,
        'enrollment',
        p_expires_at
    )
    returning id into v_token_id;

    -- Record the operation without storing the raw token or its hash.
    perform api.append_audit_event(
        'members',
        p_actor_user_id,
        'member.pin_enrollment_token_created',
        'member',
        p_member_id::text,
        pg_catalog.jsonb_build_object(
            'token_id', v_token_id,
            'purpose', 'enrollment',
            'expires_at', p_expires_at
        )
    );

    return pg_catalog.jsonb_build_object(
        'token_id', v_token_id,
        'expires_at', p_expires_at,
        'purpose', 'enrollment'
    );
end;
$function$;

revoke all on function api.owner_create_pin_enrollment_token(
    uuid, uuid, text, timestamptz
) from public, anon, authenticated;

grant execute on function api.owner_create_pin_enrollment_token(
    uuid, uuid, text, timestamptz
) to service_role;

commit;
