begin;

-- The API schema is exposed by local/hosted Supabase configuration.
create schema if not exists api;

-- Check a user ID only through a server-side call after the Edge Function
-- has verified the user's access token with Supabase Auth.
create or replace function api.is_active_owner_for_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
    select exists (
        select 1
        from private.owner_access oa
        where oa.user_id = p_user_id
          and oa.is_active = true
    );
$function$;

-- Do not permit browser roles to call this function.
revoke all on schema api from public, anon, authenticated;
revoke all on function api.is_active_owner_for_user(uuid)
    from public, anon, authenticated, service_role;

-- Only the server role can invoke this check.
grant usage on schema api to service_role;
grant execute on function api.is_active_owner_for_user(uuid)
    to service_role;

commit;