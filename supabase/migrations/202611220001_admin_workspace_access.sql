-- Admin workspace access for operational data. The browser uses the anon key;
-- all privileged reads and writes remain protected by auth.uid() + is_admin().

begin;

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

alter table public.orders
  add column if not exists delivery_partner_id uuid references public.delivery_partners(id),
  add column if not exists assigned_at timestamptz,
  add column if not exists picked_up_at timestamptz,
  add column if not exists out_for_delivery_at timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists failed_at timestamptz,
  add column if not exists failed_reason text;

-- Preserve the customer-confirmed delivery pin on the saved address and order.
alter table public.saved_addresses
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;
alter table public.orders
  add column if not exists delivery_latitude double precision,
  add column if not exists delivery_longitude double precision;

alter table public.product_catalog
  add column if not exists stock_quantity integer not null default 0,
  add column if not exists low_stock_limit integer not null default 5,
  add column if not exists admin_note text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users(id);

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
  related_order_id text references public.orders(id) on delete set null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.inventory_movements enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders" on public.orders
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can update all orders" on public.orders;
create policy "Admins can update all orders" on public.orders
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins can read all order items" on public.order_items;
create policy "Admins can read all order items" on public.order_items
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can update all order items" on public.order_items;
create policy "Admins can update all order items" on public.order_items
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins can read customer profiles" on public.profiles;
create policy "Admins can read customer profiles" on public.profiles
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can read saved addresses" on public.saved_addresses;
create policy "Admins can read saved addresses" on public.saved_addresses
  for select to authenticated using (public.is_admin());

drop policy if exists "Admins can insert product catalog" on public.product_catalog;
create policy "Admins can insert product catalog" on public.product_catalog
  for insert to authenticated with check (public.is_admin());
drop policy if exists "Admins can update product catalog" on public.product_catalog;
create policy "Admins can update product catalog" on public.product_catalog
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins can delete product catalog" on public.product_catalog;
create policy "Admins can delete product catalog" on public.product_catalog
  for delete to authenticated using (public.is_admin());

drop policy if exists "Admins can read delivery partners" on public.delivery_partners;
create policy "Admins can read delivery partners" on public.delivery_partners
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can insert delivery partners" on public.delivery_partners;
create policy "Admins can insert delivery partners" on public.delivery_partners
  for insert to authenticated with check (public.is_admin());
drop policy if exists "Admins can update delivery partners" on public.delivery_partners;
create policy "Admins can update delivery partners" on public.delivery_partners
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins can delete delivery partners" on public.delivery_partners;
create policy "Admins can delete delivery partners" on public.delivery_partners
  for delete to authenticated using (public.is_admin());

drop policy if exists "Admins can read inventory movements" on public.inventory_movements;
create policy "Admins can read inventory movements" on public.inventory_movements
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can insert inventory movements" on public.inventory_movements;
create policy "Admins can insert inventory movements" on public.inventory_movements
  for insert to authenticated with check (public.is_admin());

drop policy if exists "Admins can read all wallet transactions" on public.wallet_transactions;
create policy "Admins can read all wallet transactions" on public.wallet_transactions
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can read all payment attempts" on public.payment_attempts;
create policy "Admins can read all payment attempts" on public.payment_attempts
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can read all checkout attempts" on public.checkout_attempts;
create policy "Admins can read all checkout attempts" on public.checkout_attempts
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins can read payment events" on public.payment_events;
create policy "Admins can read payment events" on public.payment_events
  for select to authenticated using (public.is_admin());

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
  v_after integer := greatest(coalesce(p_stock_quantity, 0), 0);
  v_row public.product_catalog%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only admins can update stock';
  end if;

  select stock_quantity into v_before
  from public.product_catalog
  where lower(product_name) = lower(trim(p_product_name))
  for update;

  if not found then
    raise exception 'Product not found: %', p_product_name;
  end if;

  update public.product_catalog
  set stock_quantity = v_after,
      is_available = coalesce(p_is_available, v_after > 0),
      availability_message = coalesce(
        p_availability_message,
        case when v_after > 0 then 'Available' else 'Out of stock' end
      ),
      admin_note = nullif(trim(coalesce(p_note, '')), ''),
      updated_at = now(),
      updated_by = auth.uid()
  where lower(product_name) = lower(trim(p_product_name))
  returning * into v_row;

  insert into public.inventory_movements (
    product_name, movement_type, quantity, stock_before, stock_after, note, created_by
  ) values (
    v_row.product_name, 'manual_adjust', v_after - v_before,
    v_before, v_after, nullif(trim(coalesce(p_note, '')), ''), auth.uid()
  );

  return v_row;
end;
$$;

create or replace function public.admin_adjust_wallet(
  p_user_id uuid,
  p_amount numeric,
  p_note text,
  p_reference text
)
returns public.wallet_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.wallet_transactions%rowtype;
  v_row public.wallet_transactions%rowtype;
  v_note text := trim(coalesce(p_note, ''));
  v_reference text := trim(coalesce(p_reference, ''));
begin
  if not public.is_admin() then
    raise exception 'Only admins can adjust customer wallets';
  end if;
  if p_user_id is null or p_amount is null or p_amount = 0 or abs(p_amount) > 100000 then
    raise exception 'A non-zero wallet adjustment up to 100000 is required';
  end if;
  if length(v_note) < 3 or length(v_reference) < 8 then
    raise exception 'A note and idempotency reference are required';
  end if;

  select * into v_existing
  from public.wallet_transactions
  where user_id = p_user_id and reference = v_reference;

  if found then
    if v_existing.amount <> round(p_amount, 2)
      or coalesce(v_existing.metadata->>'note', '') <> v_note then
      raise exception 'Reference already used with a different adjustment';
    end if;
    return v_existing;
  end if;

  insert into public.wallet_transactions (
    user_id, operation, amount, reference, metadata
  ) values (
    p_user_id, 'adjustment', round(p_amount, 2), v_reference,
    jsonb_build_object('note', v_note, 'admin_user_id', auth.uid(), 'source', 'admin_workspace')
  ) returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.admin_update_product_stock(text, integer, boolean, text, text) from public;
revoke all on function public.admin_adjust_wallet(uuid, numeric, text, text) from public;
grant execute on function public.admin_update_product_stock(text, integer, boolean, text, text) to authenticated;
grant execute on function public.admin_adjust_wallet(uuid, numeric, text, text) to authenticated;

grant select on public.admin_users, public.orders, public.order_items, public.profiles,
  public.saved_addresses, public.product_catalog, public.delivery_partners,
  public.inventory_movements, public.wallet_transactions, public.payment_attempts,
  public.payment_events, public.checkout_attempts to authenticated;
grant update on public.orders, public.order_items, public.product_catalog,
  public.delivery_partners to authenticated;
grant insert, delete on public.product_catalog, public.delivery_partners to authenticated;

create index if not exists orders_delivery_partner_id_idx on public.orders(delivery_partner_id);
create index if not exists inventory_movements_created_at_idx on public.inventory_movements(created_at desc);

notify pgrst, 'reload schema';

commit;
