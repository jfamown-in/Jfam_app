-- JFAM payment and checkout foundation.
-- Browser clients can request checkout, but the database resolves prices,
-- wallet debits, orders, order items, and payment attempts atomically.

begin;

create extension if not exists pgcrypto;

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
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

create table if not exists public.product_catalog (
  product_name text primary key,
  category text,
  description text,
  image_url text,
  display_price_text text,
  unit_label text,
  default_price numeric(12,2) not null default 0,
  monthly_price numeric(12,2),
  fifteen_day_price numeric(12,2),
  weekly_price numeric(12,2),
  one_time_price numeric(12,2),
  custom_price numeric(12,2),
  is_available boolean not null default true,
  availability_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.product_catalog enable row level security;

drop policy if exists "Anyone can read product catalog" on public.product_catalog;
create policy "Anyone can read product catalog"
on public.product_catalog for select to anon, authenticated
using (true);

create table if not exists public.saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_id bigint,
  address_key text,
  name text,
  mobile text,
  pin text,
  house text,
  street text,
  town text,
  city text,
  state text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.saved_addresses enable row level security;
create index if not exists saved_addresses_user_id_idx on public.saved_addresses(user_id);

drop policy if exists "Users can read own saved addresses" on public.saved_addresses;
create policy "Users can read own saved addresses"
on public.saved_addresses for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can insert own saved addresses" on public.saved_addresses;
create policy "Users can insert own saved addresses"
on public.saved_addresses for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can update own saved addresses" on public.saved_addresses;
create policy "Users can update own saved addresses"
on public.saved_addresses for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete own saved addresses" on public.saved_addresses;
create policy "Users can delete own saved addresses"
on public.saved_addresses for delete to authenticated
using (user_id = auth.uid());

create table if not exists public.orders (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ordered_at timestamptz not null default now(),
  payment_mode text not null,
  status text not null default 'Pending Payment',
  delivery_status text not null default 'Pending Payment',
  customer_name text,
  customer_phone text,
  customer_email text,
  address text,
  delivery_address text,
  delivery_address_id text,
  customer_type text default 'Customer',
  order_category text default 'Delivery',
  cod_fee numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  wallet_amount numeric(12,2) not null default 0,
  payable_amount numeric(12,2) not null default 0,
  checkout_attempt_id uuid,
  created_by_rpc boolean not null default true
);

alter table public.orders enable row level security;
alter table if exists public.orders
  add column if not exists wallet_amount numeric(12,2) not null default 0,
  add column if not exists payable_amount numeric(12,2) not null default 0,
  add column if not exists checkout_attempt_id uuid,
  add column if not exists created_by_rpc boolean not null default true;

create index if not exists orders_user_id_ordered_at_idx on public.orders(user_id, ordered_at desc);

drop policy if exists "Users can read own orders" on public.orders;
create policy "Users can read own orders"
on public.orders for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders"
on public.orders for select to authenticated
using (public.is_admin());

drop policy if exists "Admins can update all orders" on public.orders;
create policy "Admins can update all orders"
on public.orders for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  item_index integer not null,
  product_name text not null,
  price numeric(12,2) not null default 0,
  image_url text,
  quantity text,
  packets integer not null default 1,
  start_date text,
  end_date text,
  slot text,
  plan text,
  cancelled boolean not null default false,
  cancelled_at timestamptz,
  delivery_controls jsonb not null default '[]'::jsonb,
  delivery_controls_summary text,
  unit_price_snapshot numeric(12,2) not null default 0,
  line_total_snapshot numeric(12,2) not null default 0,
  product_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(order_id, item_index)
);

alter table public.order_items enable row level security;
alter table if exists public.order_items
  add column if not exists order_id text,
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists item_index integer,
  add column if not exists product_name text,
  add column if not exists price numeric(12,2) not null default 0,
  add column if not exists image_url text,
  add column if not exists quantity text,
  add column if not exists packets integer not null default 1,
  add column if not exists start_date text,
  add column if not exists end_date text,
  add column if not exists slot text,
  add column if not exists plan text,
  add column if not exists cancelled boolean not null default false,
  add column if not exists cancelled_at timestamptz,
  add column if not exists delivery_controls jsonb not null default '[]'::jsonb,
  add column if not exists delivery_controls_summary text,
  add column if not exists unit_price_snapshot numeric(12,2) not null default 0,
  add column if not exists line_total_snapshot numeric(12,2) not null default 0,
  add column if not exists product_snapshot jsonb not null default '{}'::jsonb;

create index if not exists order_items_user_id_idx on public.order_items(user_id) where user_id is not null;
create index if not exists order_items_order_id_idx on public.order_items(order_id) where order_id is not null;

drop policy if exists "Users can read own order items" on public.order_items;
create policy "Users can read own order items"
on public.order_items for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can read all order items" on public.order_items;
create policy "Admins can read all order items"
on public.order_items for select to authenticated
using (public.is_admin());

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in ('credit', 'debit', 'refund', 'reversal', 'adjustment')),
  amount numeric(12,2) not null check (amount <> 0),
  reference text not null,
  related_order_id text references public.orders(id) on delete set null,
  related_payment_attempt_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, reference)
);

alter table public.wallet_transactions enable row level security;
create index if not exists wallet_transactions_user_created_idx on public.wallet_transactions(user_id, created_at desc);

drop policy if exists "Users can read own wallet transactions" on public.wallet_transactions;
create policy "Users can read own wallet transactions"
on public.wallet_transactions for select to authenticated
using (user_id = auth.uid());

create or replace function public.prevent_wallet_transaction_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'wallet transactions are append-only';
end;
$$;

drop trigger if exists wallet_transactions_append_only on public.wallet_transactions;
create trigger wallet_transactions_append_only
before update or delete on public.wallet_transactions
for each row execute function public.prevent_wallet_transaction_mutation();

create table if not exists public.checkout_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null,
  status text not null default 'started' check (status in ('started', 'order_created', 'failed')),
  order_id text,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, idempotency_key)
);

alter table public.checkout_attempts enable row level security;
create index if not exists checkout_attempts_user_created_idx on public.checkout_attempts(user_id, created_at desc);

drop policy if exists "Users can read own checkout attempts" on public.checkout_attempts;
create policy "Users can read own checkout attempts"
on public.checkout_attempts for select to authenticated
using (user_id = auth.uid());

create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  checkout_attempt_id uuid references public.checkout_attempts(id) on delete set null,
  order_id text references public.orders(id) on delete cascade,
  provider text not null default 'razorpay',
  payment_method text not null check (payment_method in ('cod', 'upi', 'card', 'wallet')),
  status text not null default 'pending' check (status in ('pending', 'requires_action', 'paid', 'captured', 'failed', 'expired', 'closed', 'cancelled')),
  amount numeric(12,2) not null default 0,
  amount_paise integer not null default 0,
  currency text not null default 'INR',
  provider_order_id text,
  provider_qr_id text,
  provider_payment_id text,
  qr_image_url text,
  qr_short_url text,
  expires_at timestamptz,
  provider_payload jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payment_attempts enable row level security;
create index if not exists payment_attempts_user_created_idx on public.payment_attempts(user_id, created_at desc);
create index if not exists payment_attempts_order_id_idx on public.payment_attempts(order_id);
create index if not exists payment_attempts_provider_qr_id_idx on public.payment_attempts(provider_qr_id);
create index if not exists payment_attempts_provider_payment_id_idx on public.payment_attempts(provider_payment_id);

drop policy if exists "Users can read own payment attempts" on public.payment_attempts;
create policy "Users can read own payment attempts"
on public.payment_attempts for select to authenticated
using (user_id = auth.uid());

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_attempt_id uuid references public.payment_attempts(id) on delete set null,
  provider text not null default 'razorpay',
  provider_event_id text,
  event_type text not null,
  provider_payment_id text,
  provider_qr_id text,
  status text,
  amount_paise integer,
  raw_payload jsonb not null,
  received_at timestamptz not null default now(),
  unique(provider, provider_event_id)
);

alter table public.payment_events enable row level security;
create index if not exists payment_events_attempt_idx on public.payment_events(payment_attempt_id, received_at desc);

drop policy if exists "Admins can read payment events" on public.payment_events;
create policy "Admins can read payment events"
on public.payment_events for select to authenticated
using (public.is_admin());

-- Browser users may read their own rows through RLS, but may not create
-- financial/order rows directly. The security-definer RPC owns creation.
drop policy if exists "Users can insert own orders" on public.orders;
drop policy if exists "Users can create own orders" on public.orders;
drop policy if exists "Users can insert own order items" on public.order_items;
drop policy if exists "Users can create own order items" on public.order_items;

revoke insert, delete on public.orders from anon, authenticated;
revoke insert, delete on public.order_items from anon, authenticated;
revoke insert, update, delete on public.checkout_attempts from anon, authenticated;
revoke insert, update, delete on public.payment_attempts from anon, authenticated;
revoke insert, update, delete on public.payment_events from anon, authenticated;
revoke insert, update, delete on public.wallet_transactions from anon, authenticated;

create or replace function public.get_wallet_balance()
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(sum(amount), 0)
  from public.wallet_transactions
  where user_id = auth.uid();
$$;

create or replace function public.jfam_plan_price(
  p_monthly numeric,
  p_fifteen numeric,
  p_weekly numeric,
  p_one_time numeric,
  p_custom numeric,
  p_default numeric,
  p_plan text
)
returns numeric
language sql
immutable
as $$
  select greatest(0, coalesce(
    case
      when lower(coalesce(p_plan, '')) like '%monthly%' then p_monthly
      when lower(coalesce(p_plan, '')) like '%15%' or lower(coalesce(p_plan, '')) like '%fifteen%' then p_fifteen
      when lower(coalesce(p_plan, '')) like '%weekly%' then p_weekly
      when lower(coalesce(p_plan, '')) like '%one time%' then p_one_time
      when lower(coalesce(p_plan, '')) like '%custom%' then p_custom
      else null
    end,
    p_default,
    p_one_time,
    p_weekly,
    p_fifteen,
    p_monthly,
    0
  ));
$$;

create or replace function public.create_checkout(
  p_items jsonb,
  p_delivery_address_id text,
  p_payment_method text,
  p_milkcash_requested numeric,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_method text := lower(trim(coalesce(p_payment_method, '')));
  v_items jsonb := coalesce(p_items, '[]'::jsonb);
  v_checkout public.checkout_attempts%rowtype;
  v_existing_order public.orders%rowtype;
  v_payment public.payment_attempts%rowtype;
  v_address public.saved_addresses%rowtype;
  v_order_id text;
  v_item jsonb;
  v_product public.product_catalog%rowtype;
  v_index integer := 0;
  v_unit_price numeric(12,2);
  v_packets integer;
  v_line_total numeric(12,2);
  v_order_total numeric(12,2) := 0;
  v_cod_fee numeric(12,2) := 0;
  v_wallet_requested numeric(12,2) := greatest(0, coalesce(p_milkcash_requested, 0));
  v_wallet_balance numeric(12,2) := 0;
  v_wallet_used numeric(12,2) := 0;
  v_payable numeric(12,2) := 0;
  v_order_category text := 'Delivery';
  v_response jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  if v_method not in ('cod', 'upi') then
    raise exception 'unsupported payment method';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'valid idempotency key required';
  end if;

  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 then
    raise exception 'checkout requires at least one item';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  insert into public.checkout_attempts (user_id, idempotency_key, request_payload)
  values (
    v_user_id,
    trim(p_idempotency_key),
    jsonb_build_object(
      'items', v_items,
      'delivery_address_id', p_delivery_address_id,
      'payment_method', v_method,
      'milkcash_requested', v_wallet_requested
    )
  )
  on conflict (user_id, idempotency_key) do nothing;

  select * into v_checkout
  from public.checkout_attempts
  where user_id = v_user_id and idempotency_key = trim(p_idempotency_key)
  for update;

  if v_checkout.order_id is not null then
    select * into v_existing_order from public.orders where id = v_checkout.order_id;
    select * into v_payment from public.payment_attempts where checkout_attempt_id = v_checkout.id order by created_at desc limit 1;
    return jsonb_build_object(
      'idempotent', true,
      'orderId', v_existing_order.id,
      'status', v_existing_order.status,
      'paymentAttemptId', v_payment.id,
      'paymentState', v_payment.status,
      'paymentMethod', v_payment.payment_method,
      'totalAmount', v_existing_order.total_amount,
      'walletUsed', v_existing_order.wallet_amount,
      'payableAmount', v_existing_order.payable_amount,
      'walletBalance', public.get_wallet_balance()
    );
  end if;

  select * into v_address
  from public.saved_addresses
  where user_id = v_user_id and local_id::text = coalesce(p_delivery_address_id, '')
  order by updated_at desc
  limit 1;

  if not found then
    select * into v_address
    from public.saved_addresses
    where user_id = v_user_id
    order by created_at asc
    limit 1;
  end if;

  if v_address.id is null then
    raise exception 'delivery address required';
  end if;

  v_order_id := 'JFAM-' || to_char(now(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  for v_item in select * from jsonb_array_elements(v_items) loop
    v_index := v_index + 1;

    select * into v_product
    from public.product_catalog
    where lower(product_name) = lower(trim(coalesce(v_item->>'productName', v_item->>'name')))
    limit 1;

    if v_product.product_name is null then
      raise exception 'product not found: %', coalesce(v_item->>'productName', v_item->>'name');
    end if;

    if coalesce(v_product.is_available, true) is not true then
      raise exception 'product unavailable: %', v_product.product_name;
    end if;

    v_packets := greatest(1, coalesce(nullif(v_item->>'packets', '')::integer, 1));
    v_unit_price := public.jfam_plan_price(
      v_product.monthly_price,
      v_product.fifteen_day_price,
      v_product.weekly_price,
      v_product.one_time_price,
      v_product.custom_price,
      v_product.default_price,
      v_item->>'plan'
    );
    v_line_total := round(v_unit_price * v_packets, 2);
    v_order_total := v_order_total + v_line_total;

    if lower(coalesce(v_item->>'plan', '')) not like '%one time%' then
      v_order_category := 'Subscription';
    end if;
  end loop;

  if v_order_total <= 0 then
    raise exception 'checkout total must be greater than zero';
  end if;

  if v_method = 'cod' then
    v_cod_fee := 10;
  end if;

  select coalesce(sum(amount), 0) into v_wallet_balance
  from public.wallet_transactions
  where user_id = v_user_id;

  v_wallet_used := least(v_wallet_requested, v_wallet_balance, v_order_total + v_cod_fee);
  v_payable := round(v_order_total + v_cod_fee - v_wallet_used, 2);

  insert into public.orders (
    id, user_id, ordered_at, payment_mode, status, delivery_status,
    customer_name, customer_phone, customer_email, address, delivery_address,
    delivery_address_id, customer_type, order_category, cod_fee, total_amount,
    wallet_amount, payable_amount, checkout_attempt_id, created_by_rpc
  ) values (
    v_order_id, v_user_id, now(),
    case when v_method = 'cod' then 'Cash On Delivery' else 'UPI' end,
    case when v_method = 'cod' and v_payable > 0 then 'COD Pending' when v_payable = 0 then 'Confirmed' else 'PENDING_PAYMENT_VERIFICATION' end,
    case when v_method = 'cod' and v_payable > 0 then 'Confirmed' when v_payable = 0 then 'Confirmed' else 'PENDING_PAYMENT_VERIFICATION' end,
    coalesce(v_address.name, 'Customer'),
    v_address.mobile,
    (select email from auth.users where id = v_user_id),
    concat_ws(', ', nullif(v_address.house, ''), nullif(v_address.street, ''), nullif(v_address.town, ''), nullif(v_address.city, ''), nullif(v_address.state, ''), nullif(v_address.pin, '')),
    concat_ws(', ', nullif(v_address.house, ''), nullif(v_address.street, ''), nullif(v_address.town, ''), nullif(v_address.city, ''), nullif(v_address.state, ''), nullif(v_address.pin, '')),
    v_address.local_id::text,
    'Customer', v_order_category, v_cod_fee, round(v_order_total + v_cod_fee, 2),
    v_wallet_used, v_payable, v_checkout.id, true
  );

  v_index := 0;
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_index := v_index + 1;

    select * into v_product
    from public.product_catalog
    where lower(product_name) = lower(trim(coalesce(v_item->>'productName', v_item->>'name')))
    limit 1;

    v_packets := greatest(1, coalesce(nullif(v_item->>'packets', '')::integer, 1));
    v_unit_price := public.jfam_plan_price(
      v_product.monthly_price,
      v_product.fifteen_day_price,
      v_product.weekly_price,
      v_product.one_time_price,
      v_product.custom_price,
      v_product.default_price,
      v_item->>'plan'
    );
    v_line_total := round(v_unit_price * v_packets, 2);

    insert into public.order_items (
      order_id, user_id, item_index, product_name, price, image_url, quantity,
      packets, start_date, end_date, slot, plan, unit_price_snapshot,
      line_total_snapshot, product_snapshot
    ) values (
      v_order_id, v_user_id, v_index, v_product.product_name, v_line_total,
      v_product.image_url, coalesce(v_item->>'quantity', v_product.unit_label),
      v_packets, v_item->>'startDate', v_item->>'endDate', v_item->>'slot', v_item->>'plan',
      v_unit_price, v_line_total,
      jsonb_build_object(
        'product_name', v_product.product_name,
        'category', v_product.category,
        'image_url', v_product.image_url,
        'unit_label', v_product.unit_label,
        'default_price', v_product.default_price,
        'selected_plan', v_item->>'plan'
      )
    );
  end loop;

  if v_wallet_used > 0 then
    insert into public.wallet_transactions (
      user_id, operation, amount, reference, related_order_id, metadata
    ) values (
      v_user_id, 'debit', -v_wallet_used, 'checkout:' || v_checkout.id::text, v_order_id,
      jsonb_build_object('checkout_attempt_id', v_checkout.id, 'order_id', v_order_id)
    );
  end if;

  insert into public.payment_attempts (
    user_id, checkout_attempt_id, order_id, provider, payment_method, status,
    amount, amount_paise, currency
  ) values (
    v_user_id, v_checkout.id, v_order_id, 'razorpay', v_method,
    case when v_payable = 0 then 'paid' when v_method = 'cod' then 'pending' else 'requires_action' end,
    v_payable, greatest(0, round(v_payable * 100)::integer), 'INR'
  ) returning * into v_payment;

  v_response := jsonb_build_object(
    'idempotent', false,
    'orderId', v_order_id,
    'status', (select status from public.orders where id = v_order_id),
    'paymentAttemptId', v_payment.id,
    'paymentState', v_payment.status,
    'paymentMethod', v_payment.payment_method,
    'totalAmount', round(v_order_total + v_cod_fee, 2),
    'walletUsed', v_wallet_used,
    'payableAmount', v_payable,
    'walletBalance', v_wallet_balance - v_wallet_used
  );

  update public.checkout_attempts
  set status = 'order_created', order_id = v_order_id, response_payload = v_response, updated_at = now()
  where id = v_checkout.id;

  return v_response;
exception
  when others then
    update public.checkout_attempts
    set status = 'failed', error_message = sqlerrm, updated_at = now()
    where user_id = v_user_id and idempotency_key = trim(coalesce(p_idempotency_key, ''));
    raise;
end;
$$;

create or replace function public.mark_razorpay_qr_created(
  p_payment_attempt_id uuid,
  p_provider_qr_id text,
  p_image_url text,
  p_short_url text,
  p_expires_at timestamptz,
  p_provider_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt public.payment_attempts%rowtype;
begin
  select * into v_attempt
  from public.payment_attempts
  where id = p_payment_attempt_id
  for update;

  if v_attempt.id is null then
    raise exception 'payment attempt not found';
  end if;

  if v_attempt.status not in ('requires_action', 'pending') then
    return jsonb_build_object('paymentAttemptId', v_attempt.id, 'status', v_attempt.status);
  end if;

  update public.payment_attempts
  set provider_qr_id = coalesce(provider_qr_id, p_provider_qr_id),
      qr_image_url = coalesce(qr_image_url, p_image_url),
      qr_short_url = coalesce(qr_short_url, p_short_url),
      expires_at = coalesce(expires_at, p_expires_at),
      provider_payload = coalesce(nullif(provider_payload, '{}'::jsonb), coalesce(p_provider_payload, '{}'::jsonb)),
      updated_at = now()
  where id = p_payment_attempt_id
  returning * into v_attempt;

  return jsonb_build_object(
    'paymentAttemptId', v_attempt.id,
    'status', v_attempt.status,
    'qrId', v_attempt.provider_qr_id,
    'imageUrl', v_attempt.qr_image_url,
    'shortUrl', v_attempt.qr_short_url,
    'expiresAt', v_attempt.expires_at
  );
end;
$$;

create or replace function public.get_payment_attempt_status(p_payment_attempt_id uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_attempt public.payment_attempts%rowtype;
begin
  select * into v_attempt
  from public.payment_attempts
  where id = p_payment_attempt_id and user_id = auth.uid();

  if v_attempt.id is null then
    raise exception 'payment attempt not found';
  end if;

  return jsonb_build_object(
    'attemptId', v_attempt.id,
    'orderId', v_attempt.order_id,
    'status', v_attempt.status,
    'amount', v_attempt.amount,
    'paymentMethod', v_attempt.payment_method,
    'qrId', v_attempt.provider_qr_id,
    'imageUrl', v_attempt.qr_image_url,
    'shortUrl', v_attempt.qr_short_url,
    'expiresAt', v_attempt.expires_at
  );
end;
$$;

create or replace function public.record_razorpay_payment_event(
  p_payment_attempt_id uuid,
  p_provider_event_id text,
  p_event_type text,
  p_provider_payment_id text,
  p_provider_qr_id text,
  p_status text,
  p_amount_paise integer,
  p_raw_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt public.payment_attempts%rowtype;
  v_normal_status text := lower(coalesce(p_status, ''));
begin
  insert into public.payment_events (
    payment_attempt_id, provider, provider_event_id, event_type,
    provider_payment_id, provider_qr_id, status, amount_paise, raw_payload
  ) values (
    p_payment_attempt_id, 'razorpay', coalesce(p_provider_event_id, p_event_type || ':' || coalesce(p_provider_payment_id, p_provider_qr_id, gen_random_uuid()::text)),
    p_event_type, p_provider_payment_id, p_provider_qr_id, p_status, p_amount_paise, coalesce(p_raw_payload, '{}'::jsonb)
  ) on conflict (provider, provider_event_id) do nothing;

  select * into v_attempt
  from public.payment_attempts
  where id = p_payment_attempt_id
  for update;

  if v_attempt.id is null then
    raise exception 'payment attempt not found';
  end if;

  if p_amount_paise is not null and p_amount_paise <> v_attempt.amount_paise then
    raise exception 'payment amount mismatch';
  end if;

  if v_normal_status in ('captured', 'paid', 'authorized') or p_event_type in ('payment.captured', 'payment.authorized', 'qr_code.credited') then
    update public.payment_attempts
    set status = case when v_normal_status = 'captured' or p_event_type = 'payment.captured' then 'captured' else 'paid' end,
        provider_payment_id = coalesce(provider_payment_id, p_provider_payment_id),
        provider_qr_id = coalesce(provider_qr_id, p_provider_qr_id),
        verified_at = coalesce(verified_at, now()),
        updated_at = now()
    where id = v_attempt.id
    returning * into v_attempt;

    update public.orders
    set status = 'Confirmed', delivery_status = 'Confirmed'
    where id = v_attempt.order_id;
  elsif v_normal_status in ('failed', 'expired', 'closed', 'cancelled') then
    update public.payment_attempts
    set status = v_normal_status,
        provider_payment_id = coalesce(provider_payment_id, p_provider_payment_id),
        provider_qr_id = coalesce(provider_qr_id, p_provider_qr_id),
        updated_at = now()
    where id = v_attempt.id
    returning * into v_attempt;

    update public.orders
    set status = upper(v_normal_status), delivery_status = upper(v_normal_status)
    where id = v_attempt.order_id and status = 'PENDING_PAYMENT_VERIFICATION';
  end if;

  return jsonb_build_object(
    'paymentAttemptId', v_attempt.id,
    'orderId', v_attempt.order_id,
    'status', v_attempt.status
  );
end;
$$;

revoke all on function public.get_wallet_balance() from public;
revoke all on function public.create_checkout(jsonb, text, text, numeric, text) from public;
revoke all on function public.mark_razorpay_qr_created(uuid, text, text, text, timestamptz, jsonb) from public;
revoke all on function public.get_payment_attempt_status(uuid) from public;
revoke all on function public.record_razorpay_payment_event(uuid, text, text, text, text, text, integer, jsonb) from public;

grant execute on function public.get_wallet_balance() to authenticated;
grant execute on function public.create_checkout(jsonb, text, text, numeric, text) to authenticated;
grant execute on function public.get_payment_attempt_status(uuid) to authenticated;
grant execute on function public.mark_razorpay_qr_created(uuid, text, text, text, timestamptz, jsonb) to service_role;
grant execute on function public.record_razorpay_payment_event(uuid, text, text, text, text, text, integer, jsonb) to service_role;

notify pgrst, 'reload schema';

commit;
