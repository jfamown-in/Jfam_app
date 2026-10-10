-- Delivery partner app setup for JFAM / Morning Drop
-- Run this in Supabase SQL Editor after the admin/customer setup.

create extension if not exists pgcrypto;

-- 1) Delivery partner profiles
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

-- 2) Delivery fields on orders
alter table if exists public.orders
  add column if not exists delivery_partner_id uuid references public.delivery_partners(id),
  add column if not exists delivery_status text not null default 'Confirmed',
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists customer_email text,
  add column if not exists address text,
  add column if not exists delivery_address text,
  add column if not exists delivery_address_id text,
  add column if not exists customer_type text,
  add column if not exists order_category text,
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

alter table if exists public.orders
  alter column delivery_status set default 'Confirmed';

-- 3) Helper for RLS
create or replace function public.current_delivery_partner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select dp.id
  from public.delivery_partners dp
  where (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
    and dp.is_active = true
  limit 1;
$$;

create or replace function public.is_active_delivery_partner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_delivery_partner_id() is not null;
$$;

create or replace function public.ensure_delivery_partner_profile()
returns public.delivery_partners
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(auth.jwt() ->> 'email');
  v_name text := nullif(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), '');
  v_partner public.delivery_partners;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.delivery_partners
  set user_id = auth.uid(),
      email = coalesce(email, v_email),
      name = coalesce(nullif(name, ''), v_name, 'Delivery partner'),
      is_active = coalesce(is_active, true),
      updated_at = now()
  where user_id = auth.uid()
     or lower(email) = v_email
  returning * into v_partner;

  if v_partner.id is not null then
    return v_partner;
  end if;

  insert into public.delivery_partners (user_id, email, name, zone, is_active)
  values (auth.uid(), v_email, coalesce(v_name, 'Delivery partner'), 'All areas', true)
  returning * into v_partner;

  return v_partner;
end;
$$;

create or replace function public.is_delivery_partner_for_order(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    join public.delivery_partners dp on dp.id = o.delivery_partner_id
    where o.id = p_order_id
      and (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
      and dp.is_active = true
  );
$$;

create or replace function public.is_order_available_for_delivery(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    where o.id = p_order_id
      and o.delivery_partner_id is null
      and lower(coalesce(o.delivery_status, o.status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
      and public.is_active_delivery_partner()
  );
$$;

create or replace function public.is_delivery_partner_for_customer(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    join public.delivery_partners dp on dp.id = o.delivery_partner_id
    where o.user_id = p_user_id
      and (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
      and dp.is_active = true
  );
$$;

grant execute on function public.current_delivery_partner_id() to authenticated;
grant execute on function public.is_active_delivery_partner() to authenticated;
grant execute on function public.ensure_delivery_partner_profile() to authenticated;
grant execute on function public.is_delivery_partner_for_order(text) to authenticated;
grant execute on function public.is_order_available_for_delivery(text) to authenticated;
grant execute on function public.is_delivery_partner_for_customer(uuid) to authenticated;

-- 4) Partner can read their own delivery profile
drop policy if exists "Delivery partners can read own profile" on public.delivery_partners;
create policy "Delivery partners can read own profile"
on public.delivery_partners
for select
to authenticated
using (user_id = auth.uid() or email = (auth.jwt() ->> 'email'));

drop policy if exists "Delivery partners can read active partner names" on public.delivery_partners;
create policy "Delivery partners can read active partner names"
on public.delivery_partners
for select
to authenticated
using (public.is_active_delivery_partner());

drop policy if exists "Delivery partners can update own profile basics" on public.delivery_partners;
create policy "Delivery partners can update own profile basics"
on public.delivery_partners
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- 5) Partner can see own claimed orders and the shared unassigned pool
drop policy if exists "Delivery partners can read assigned orders" on public.orders;
create policy "Delivery partners can read assigned orders"
on public.orders
for select
to authenticated
using (
  exists (
    select 1
    from public.delivery_partners dp
    where dp.id = orders.delivery_partner_id
      and (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
      and dp.is_active = true
  )
);

drop policy if exists "Delivery partners can read unassigned pool orders" on public.orders;
create policy "Delivery partners can read unassigned pool orders"
on public.orders
for select
to authenticated
using (
  delivery_partner_id is null
  and lower(coalesce(delivery_status, status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  and public.is_active_delivery_partner()
);

drop policy if exists "Delivery partners can read active claimed order visibility" on public.orders;
create policy "Delivery partners can read active claimed order visibility"
on public.orders
for select
to authenticated
using (
  delivery_partner_id is not null
  and lower(coalesce(delivery_status, status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  and public.is_active_delivery_partner()
);

drop policy if exists "Delivery partners can claim unassigned pool orders" on public.orders;
create policy "Delivery partners can claim unassigned pool orders"
on public.orders
for update
to authenticated
using (
  delivery_partner_id is null
  and lower(coalesce(delivery_status, status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  and public.is_active_delivery_partner()
)
with check (
  delivery_partner_id = public.current_delivery_partner_id()
);

drop policy if exists "Delivery partners can update assigned order delivery status" on public.orders;
create policy "Delivery partners can update assigned order delivery status"
on public.orders
for update
to authenticated
using (
  exists (
    select 1
    from public.delivery_partners dp
    where dp.id = orders.delivery_partner_id
      and (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
      and dp.is_active = true
  )
)
with check (
  exists (
    select 1
    from public.delivery_partners dp
    where dp.id = orders.delivery_partner_id
      and (dp.user_id = auth.uid() or lower(dp.email) = lower(auth.jwt() ->> 'email'))
      and dp.is_active = true
  )
);

-- 6) Partner can read items for own claimed orders and unassigned pool orders
drop policy if exists "Delivery partners can read assigned order items" on public.order_items;
create policy "Delivery partners can read assigned order items"
on public.order_items
for select
to authenticated
using (public.is_delivery_partner_for_order(order_id));

drop policy if exists "Delivery partners can read unassigned pool order items" on public.order_items;
create policy "Delivery partners can read unassigned pool order items"
on public.order_items
for select
to authenticated
using (public.is_order_available_for_delivery(order_id));

drop policy if exists "Delivery partners can read active claimed order items" on public.order_items;
create policy "Delivery partners can read active claimed order items"
on public.order_items
for select
to authenticated
using (
  public.is_active_delivery_partner()
  and exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.delivery_partner_id is not null
      and lower(coalesce(o.delivery_status, o.status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  )
);

-- 7) Partner can read customer profile for own claimed orders and available pool orders
drop policy if exists "Delivery partners can read assigned customer profiles" on public.profiles;
create policy "Delivery partners can read assigned customer profiles"
on public.profiles
for select
to authenticated
using (public.is_delivery_partner_for_customer(id));

drop policy if exists "Delivery partners can read unassigned pool customer profiles" on public.profiles;
create policy "Delivery partners can read unassigned pool customer profiles"
on public.profiles
for select
to authenticated
using (
  public.is_active_delivery_partner()
  and exists (
    select 1
    from public.orders o
    where o.user_id = profiles.id
      and o.delivery_partner_id is null
      and lower(coalesce(o.delivery_status, o.status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  )
);

drop policy if exists "Delivery partners can read active claimed customer profiles" on public.profiles;
create policy "Delivery partners can read active claimed customer profiles"
on public.profiles
for select
to authenticated
using (
  public.is_active_delivery_partner()
  and exists (
    select 1
    from public.orders o
    where o.user_id = profiles.id
      and o.delivery_partner_id is not null
      and lower(coalesce(o.delivery_status, o.status, '')) not in ('delivered', 'failed', 'cancelled', 'canceled')
  )
);

-- 8) Realtime
alter table if exists public.orders replica identity full;
alter table if exists public.order_items replica identity full;
alter table if exists public.delivery_partners replica identity full;
alter table if exists public.profiles replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.orders;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.order_items;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.delivery_partners;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.profiles;
  exception when duplicate_object then null;
  end;
end $$;

-- 9) Create partner row after the partner has logged in once.
-- Replace email/name/mobile/zone as needed.
--
-- insert into public.delivery_partners (user_id, email, name, mobile, zone, vehicle_number)
-- select id, email, 'Partner Name', '+91 00000 00000', 'North Loop', 'RJ-00-AB-0000'
-- from auth.users
-- where email = 'partner@example.com'
-- on conflict (user_id) do update
-- set email = excluded.email,
--     name = excluded.name,
--     mobile = excluded.mobile,
--     zone = excluded.zone,
--     vehicle_number = excluded.vehicle_number,
--     updated_at = now();

-- 10) Optional manual claim/assignment from SQL/Table Editor:
--
-- update public.orders
-- set delivery_partner_id = '<delivery_partner_id>',
--     delivery_status = 'Assigned',
--     status = 'Assigned',
--     assigned_at = now(),
--     updated_at = now()
-- where id = '<order_id>';
