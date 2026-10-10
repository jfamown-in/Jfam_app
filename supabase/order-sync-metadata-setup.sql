-- Keeps customer app, admin app, delivery app, and Supabase order rows aligned.
-- Run once in the Supabase SQL editor for the project.

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

alter table if exists public.orders
  alter column delivery_status set default 'Confirmed';

create index if not exists orders_delivery_status_idx
on public.orders(delivery_status);
