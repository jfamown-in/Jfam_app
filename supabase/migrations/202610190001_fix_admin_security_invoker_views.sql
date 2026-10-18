-- Fix Supabase Advisor critical findings for admin dashboard views.
-- Views now run with the caller's permissions/RLS and include an admin guard.

begin;

drop view if exists public.admin_today_sales_by_product;
drop view if exists public.admin_today_orders_summary;

create or replace view public.admin_today_sales_by_product
with (security_invoker = true) as
select
  oi.product_name,
  count(*) as line_count,
  coalesce(sum(nullif(regexp_replace(coalesce(oi.packets::text, '0'), '[^0-9.-]', '', 'g'), '')::numeric), 0) as total_packets,
  coalesce(sum(oi.price * oi.packets), 0) as gross_amount
from public.order_items oi
join public.orders o on o.id = oi.order_id
where
  public.is_admin()
  and (o.ordered_at at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date
  and coalesce(oi.cancelled, false) = false
  and coalesce(o.status, '') not in ('Cancelled', 'Canceled')
group by oi.product_name
order by gross_amount desc;

create or replace view public.admin_today_orders_summary
with (security_invoker = true) as
select
  count(*) as total_orders,
  coalesce(sum(total_amount), 0) as total_sales,
  count(*) filter (where status = 'Confirmed') as confirmed_orders,
  count(*) filter (where status = 'Delivered') as delivered_orders,
  count(*) filter (where status in ('Cancelled', 'Canceled')) as cancelled_orders
from public.orders
where
  public.is_admin()
  and (ordered_at at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date;

revoke all on public.admin_today_sales_by_product from public, anon;
revoke all on public.admin_today_orders_summary from public, anon;
grant select on public.admin_today_sales_by_product to authenticated;
grant select on public.admin_today_orders_summary to authenticated;

notify pgrst, 'reload schema';

commit;
