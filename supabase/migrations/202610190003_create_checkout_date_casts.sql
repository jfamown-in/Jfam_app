-- Keep checkout compatible with recovered schemas where order item dates are typed as date.

begin;

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
      v_packets, nullif(v_item->>'startDate', '')::date, nullif(v_item->>'endDate', '')::date, v_item->>'slot', v_item->>'plan',
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

notify pgrst, 'reload schema';

commit;
