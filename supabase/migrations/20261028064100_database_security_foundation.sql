
begin;

-- Prepare the private API schema.
create schema if not exists api;

-- Keep API schema inaccessible to browser-facing roles.
revoke all on schema api
    from public, anon, authenticated;

-- Allow only the server-side role to access the API schema.
grant usage on schema api to service_role;

commit;
