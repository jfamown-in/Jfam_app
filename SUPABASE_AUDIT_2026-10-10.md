# JFAM Supabase audit — 2026-10-10

Read-only review of project `eohyhutadbpghjvbwecv`.

## Confirmed live state

- Project: **JFAM app**, region `ap-southeast-2`, Nano compute, dashboard status healthy.
- Auth: 12 user accounts exist. No phone numbers are stored for the visible accounts.
- Database: 13 public tables; RLS is enabled on all of them.
- Edge Functions: none are deployed.
- Migrations: dashboard has no recorded migrations.
- GitHub: no repository is connected.
- Backups: the Free plan has no scheduled backups or point-in-time recovery.
- Dashboard observability shows elevated API, Realtime, Postgres, and Storage errors in the last hour.

## Security findings

- Security Advisor reports 2 critical findings: `public.admin_today_sales_by_product` and `public.admin_today_orders_summary` are `SECURITY DEFINER` views.
- It reports 22 warnings. The confirmed high-risk ones include public execution of `admin_update_product_stock`, `ensure_delivery_partner_profile`, and delivery-partner helper functions.
- Unsafe delivery-pool policies are currently active. They expose active partner names, unassigned/claimed order visibility, order items, and customer profiles.
- `find_profile_for_login` is a public `SECURITY DEFINER` function. It needs a separate login redesign because the browser presently calls it before authentication.
- The browser can create and synchronize local orders and wallet movements. This has been blocked in `script.js`; no local order or wallet value can now be treated as authoritative.

## Required live changes

1. Back up/export the current schema and data before any migration.
2. Apply `supabase/migrations/202610100001_delivery_partner_lockdown.sql`.
3. Replace public security-definer functions with least-privilege, authenticated RPCs.
4. Deploy server-side checkout, wallet, Razorpay webhook, and WhatsApp functions before reenabling checkout.
5. Configure an organization-owned GitHub repository and repeatable migrations.
6. Upgrade or create an independent backup/export routine before production changes.

## DNS note

The Supabase dashboard resolves the project and reports it healthy. The local terminal resolver could not resolve the project hostname, so the terminal failure is not evidence that the project is offline.
