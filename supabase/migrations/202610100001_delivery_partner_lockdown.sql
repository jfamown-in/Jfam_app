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

commit;
