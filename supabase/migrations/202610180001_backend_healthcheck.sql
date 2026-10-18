-- Read-only health RPC for keepalive monitoring.
-- Returns only generic availability metadata. It does not read or write business data.

create or replace function public.backend_healthcheck()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'ok', true,
    'service', 'jfam-backend',
    'checked_at', now()
  );
$$;

revoke all on function public.backend_healthcheck() from public;
grant execute on function public.backend_healthcheck() to anon, authenticated;
