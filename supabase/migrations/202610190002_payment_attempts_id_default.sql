-- Ensure legacy payment_attempts rows can be created by the checkout RPC.
-- Some recovered databases had payment_attempts.id as NOT NULL without a UUID default.

begin;

create extension if not exists pgcrypto;

alter table if exists public.payment_attempts
  alter column id set default gen_random_uuid();

notify pgrst, 'reload schema';

commit;
