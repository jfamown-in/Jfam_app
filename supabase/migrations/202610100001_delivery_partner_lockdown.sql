begin;

-- Customers must never be able to make themselves delivery partners.
drop function if exists public.ensure_delivery_partner_profile();

-- Remove shared delivery-pool policies that expose unrelated orders, order
-- items, customer profiles, or other partner records.
drop policy if exists "Delivery partners can read active partner names" on public.delivery_partners;
drop policy if exists "Delivery partners can read unassigned pool orders" on public.orders;
drop policy if exists "Delivery partners can read active claimed order visibility" on public.orders;
drop policy if exists "Delivery partners can claim unassigned pool orders" on public.orders;
drop policy if exists "Delivery partners can read unassigned pool order items" on public.order_items;
drop policy if exists "Delivery partners can read active claimed order items" on public.order_items;
drop policy if exists "Delivery partners can read unassigned pool customer profiles" on public.profiles;
drop policy if exists "Delivery partners can read active claimed customer profiles" on public.profiles;

-- Partners must not be able to alter arbitrary fields on assigned orders.
-- Delivery status transitions will be added through a validated server RPC.
drop policy if exists "Delivery partners can update assigned order delivery status" on public.orders;

-- Remove helpers supporting the public delivery pool and revoke implicit access
-- to the remaining helpers before their explicit grants are established by the
-- secure setup migration.
drop function if exists public.is_order_available_for_delivery(text);
revoke all on function public.current_delivery_partner_id() from public;
revoke all on function public.is_active_delivery_partner() from public;
revoke all on function public.is_delivery_partner_for_order(text) from public;
revoke all on function public.is_delivery_partner_for_customer(uuid) from public;

commit;
