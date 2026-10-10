-- Run this in Supabase SQL editor after your existing app tables are created.
-- It lets selected admin users read/update every order while normal customers
-- can still only see their own data through your existing policies.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

drop policy if exists "Admins can read admin list" on public.admin_users;
create policy "Admins can read admin list"
on public.admin_users
for select
to authenticated
using (public.is_admin());

alter table if exists public.orders
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists customer_email text,
  add column if not exists address text,
  add column if not exists delivery_address text,
  add column if not exists delivery_address_id text,
  add column if not exists customer_type text,
  add column if not exists order_category text,
  add column if not exists delivery_status text not null default 'Confirmed';

drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders"
on public.orders
for select
to authenticated
using (public.is_admin());

drop policy if exists "Admins can update all orders" on public.orders;
create policy "Admins can update all orders"
on public.orders
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can read all order items" on public.order_items;
create policy "Admins can read all order items"
on public.order_items
for select
to authenticated
using (public.is_admin());

drop policy if exists "Admins can read customer profiles" on public.profiles;
create policy "Admins can read customer profiles"
on public.profiles
for select
to authenticated
using (public.is_admin());

alter table if exists public.delivery_partners enable row level security;

drop policy if exists "Admins can read delivery partners" on public.delivery_partners;
create policy "Admins can read delivery partners"
on public.delivery_partners
for select
to authenticated
using (public.is_admin());

drop policy if exists "Admins can insert delivery partners" on public.delivery_partners;
create policy "Admins can insert delivery partners"
on public.delivery_partners
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "Admins can update delivery partners" on public.delivery_partners;
create policy "Admins can update delivery partners"
on public.delivery_partners
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete delivery partners" on public.delivery_partners;
create policy "Admins can delete delivery partners"
on public.delivery_partners
for delete
to authenticated
using (public.is_admin());

-- After the admin email signs in once, run this with the real email:
--
-- insert into public.admin_users (user_id, email)
-- select id, email
-- from auth.users
-- where lower(email) = lower('ADMIN_EMAIL_HERE')
-- on conflict (user_id) do nothing;
