-- JFAM admin app live backend setup.
-- Run this in Supabase SQL Editor after the existing customer app tables exist.

-- 1) Admin users + admin helper
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


-- 2) Product catalog stock/admin columns
alter table if exists public.product_catalog
  add column if not exists stock_quantity integer not null default 0,
  add column if not exists low_stock_limit integer not null default 5,
  add column if not exists admin_note text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users(id);

alter table if exists public.product_catalog enable row level security;

drop policy if exists "Anyone can read product catalog" on public.product_catalog;
create policy "Anyone can read product catalog"
on public.product_catalog
for select
to anon, authenticated
using (true);

drop policy if exists "Admins can insert product catalog" on public.product_catalog;
create policy "Admins can insert product catalog"
on public.product_catalog
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "Admins can update product catalog" on public.product_catalog;
create policy "Admins can update product catalog"
on public.product_catalog
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete product catalog" on public.product_catalog;
create policy "Admins can delete product catalog"
on public.product_catalog
for delete
to authenticated
using (public.is_admin());


-- 3) Admin access for customer/orders data
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

drop policy if exists "Admins can update all order items" on public.order_items;
create policy "Admins can update all order items"
on public.order_items
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

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


-- 4) Inventory movement log for restock/sale/wastage/manual adjustment
create table if not exists public.inventory_movements (
  id bigserial primary key,
  product_name text not null,
  movement_type text not null check (
    movement_type in ('restock', 'sale', 'manual_adjust', 'wastage', 'return', 'correction')
  ),
  quantity integer not null,
  stock_before integer,
  stock_after integer,
  note text,
  related_order_id text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.inventory_movements enable row level security;

drop policy if exists "Admins can read inventory movements" on public.inventory_movements;
create policy "Admins can read inventory movements"
on public.inventory_movements
for select
to authenticated
using (public.is_admin());

drop policy if exists "Admins can insert inventory movements" on public.inventory_movements;
create policy "Admins can insert inventory movements"
on public.inventory_movements
for insert
to authenticated
with check (public.is_admin());


-- 5) Helper function: admin updates product stock safely
create or replace function public.admin_update_product_stock(
  p_product_name text,
  p_stock_quantity integer,
  p_is_available boolean default null,
  p_availability_message text default null,
  p_note text default null
)
returns public.product_catalog
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before integer;
  v_after integer;
  v_row public.product_catalog;
begin
  if not public.is_admin() then
    raise exception 'Only admins can update stock';
  end if;

  select stock_quantity
  into v_before
  from public.product_catalog
  where lower(product_name) = lower(p_product_name)
  limit 1;

  if v_before is null then
    raise exception 'Product not found: %', p_product_name;
  end if;

  v_after := greatest(coalesce(p_stock_quantity, 0), 0);

  update public.product_catalog
  set
    stock_quantity = v_after,
    is_available = coalesce(p_is_available, v_after > 0),
    availability_message = coalesce(
      p_availability_message,
      case when v_after > 0 then 'Available' else 'Out of stock' end
    ),
    admin_note = p_note,
    updated_at = now(),
    updated_by = auth.uid()
  where lower(product_name) = lower(p_product_name)
  returning *
  into v_row;

  insert into public.inventory_movements (
    product_name,
    movement_type,
    quantity,
    stock_before,
    stock_after,
    note,
    created_by
  )
  values (
    v_row.product_name,
    'manual_adjust',
    v_after - v_before,
    v_before,
    v_after,
    p_note,
    auth.uid()
  );

  return v_row;
end;
$$;

grant execute on function public.admin_update_product_stock(text, integer, boolean, text, text)
to authenticated;


-- 6) Sales views for admin dashboard
create or replace view public.admin_today_sales_by_product as
select
  oi.product_name,
  count(*) as line_count,
  coalesce(sum(nullif(regexp_replace(coalesce(oi.packets::text, '0'), '[^0-9.-]', '', 'g'), '')::numeric), 0) as total_packets,
  coalesce(sum(oi.price * oi.packets), 0) as gross_amount
from public.order_items oi
join public.orders o on o.id = oi.order_id
where
  (o.ordered_at at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date
  and coalesce(oi.cancelled, false) = false
  and coalesce(o.status, '') not in ('Cancelled', 'Canceled')
group by oi.product_name
order by gross_amount desc;

create or replace view public.admin_today_orders_summary as
select
  count(*) as total_orders,
  coalesce(sum(total_amount), 0) as total_sales,
  count(*) filter (where status = 'Confirmed') as confirmed_orders,
  count(*) filter (where status = 'Delivered') as delivered_orders,
  count(*) filter (where status in ('Cancelled', 'Canceled')) as cancelled_orders
from public.orders
where (ordered_at at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date;

grant select on public.admin_today_sales_by_product to authenticated;
grant select on public.admin_today_orders_summary to authenticated;


-- 7) Realtime setup
alter table if exists public.orders replica identity full;
alter table if exists public.order_items replica identity full;
alter table if exists public.product_catalog replica identity full;
alter table if exists public.profiles replica identity full;
alter table if exists public.inventory_movements replica identity full;
alter table if exists public.delivery_partners replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.orders;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.order_items;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.product_catalog;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.profiles;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.inventory_movements;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.delivery_partners;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;
end $$;


-- 8) Run this separately after the admin email has signed in once:
-- insert into public.admin_users (user_id, email)
-- select id, email
-- from auth.users
-- where lower(email) = lower('ADMIN_EMAIL_HERE')
-- on conflict (user_id) do nothing;
