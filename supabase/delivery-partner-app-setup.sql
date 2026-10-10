-- Secure delivery-partner setup for JFAM.
-- Admins create/activate delivery partners. Partners can read only orders already
-- assigned to them. Status changes must use an audited server-side RPC.

create extension if not exists pgcrypto;

create table if not exists public.delivery_partners (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  email text unique,
  name text not null,
  mobile text,
  phone text,
  zone text,
  route_name text,
  vehicle text,
  vehicle_number text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.delivery_partners enable row level security;

alter table if exists public.orders
  add column if not exists delivery_partner_id uuid references public.delivery_partners(id),
  add column if not exists delivery_status text not null default 'Confirmed',
  add column if not exists assigned_at timestamptz,
  add column if not exists picked_up_at timestamptz,
  add column if not exists out_for_delivery_at timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists failed_at timestamptz,
  add column if not exists failed_reason text;

create index if not exists orders_delivery_partner_id_idx
on public.orders(delivery_partner_id);

create index if not exists orders_delivery_status_idx
on public.orders(delivery_status);

-- Helper functions expose only a boolean for the caller's own assignment.
-- Revoke default public execution before granting authenticated access.
create or replace function public.current_delivery_partner_id()
returns uuid language sql stable security definer set search_path = public as $$
  select dp.id from public.delivery_partners dp
  where dp.user_id = auth.uid() and dp.is_active = true
  limit 1;
$$;

create or replace function public.is_delivery_partner_for_order(p_order_id text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.id = p_order_id
      and o.delivery_partner_id = public.current_delivery_partner_id()
  );
$$;

create or replace function public.is_delivery_partner_for_customer(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.orders o
    where o.user_id = p_user_id
      and o.delivery_partner_id = public.current_delivery_partner_id()
  );
$$;

revoke all on function public.current_delivery_partner_id() from public;
revoke all on function public.is_delivery_partner_for_order(text) from public;
revoke all on function public.is_delivery_partner_for_customer(uuid) from public;
grant execute on function public.current_delivery_partner_id() to authenticated;
grant execute on function public.is_delivery_partner_for_order(text) to authenticated;
grant execute on function public.is_delivery_partner_for_customer(uuid) to authenticated;

-- Partners can read their own record only. Admin policies belong in admin setup.
drop policy if exists "Delivery partners can read own profile" on public.delivery_partners;
create policy "Delivery partners can read own profile"
on public.delivery_partners for select to authenticated
using (user_id = auth.uid());

-- Do not grant direct profile or order mutation: an RLS update policy cannot
-- safely restrict a partner to delivery-status columns alone.
drop policy if exists "Delivery partners can update own profile basics" on public.delivery_partners;
drop policy if exists "Delivery partners can read assigned orders" on public.orders;
create policy "Delivery partners can read assigned orders"
on public.orders for select to authenticated
using (delivery_partner_id = public.current_delivery_partner_id());

drop policy if exists "Delivery partners can read assigned order items" on public.order_items;
create policy "Delivery partners can read assigned order items"
on public.order_items for select to authenticated
using (public.is_delivery_partner_for_order(order_id));

drop policy if exists "Delivery partners can read assigned customer profiles" on public.profiles;
create policy "Delivery partners can read assigned customer profiles"
on public.profiles for select to authenticated
using (public.is_delivery_partner_for_customer(id));

-- Deliberately no realtime publication. Use private, scoped broadcasts only after
-- their Realtime authorization policies and tests are introduced.

-- Admin creates partner after user has logged in once:
-- insert into public.delivery_partners (user_id, email, name, mobile, zone)
-- select id, email, 'Partner Name', '+91 00000 00000', 'North Loop'
-- from auth.users where email = 'partner@example.com';
