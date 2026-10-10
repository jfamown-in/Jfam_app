# JFAM engineering work log

## 2026-10-10 — Phase 1 started

- Recovered source inspected. App is a static HTML/CSS/JavaScript customer dairy-ordering interface packaged for Android with Capacitor.
- Backend is remote Supabase project `eohyhutadbpghjvbwecv`; local Supabase configuration, migrations history, and test suite were absent.
- Baseline: bundled Node syntax check and `npm run build` pass.
- Existing live review: all 13 public tables have RLS enabled, but delivery-partner policies/functions expose unrelated order/customer data. No Edge Functions are deployed. Free plan has no scheduled backups.
- Client-created orders, browser wallet mutations, manual UPI confirmation, and local delivery changes were blocked in commit `3b8b366`.
- Next: source audit, research record, browser smoke test, and a migration design for an authoritative checkout/wallet.

- Frontend/backend audit added: monolithic client and non-authoritative backend are the primary structural risks.
