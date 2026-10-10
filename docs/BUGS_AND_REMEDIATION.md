# Bugs and remediation

| ID | Severity | Root cause/evidence | Status | Fix / next test |
| --- | --- | --- | --- | --- |
| SEC-001 | Critical | Browser completed UPI/COD/card flows and wrote local orders | Fixed locally in `3b8b366` | Browser checkout denial test after login |
| SEC-002 | Critical | MilkCash was browser `localStorage` | Fixed locally in `3b8b366` | Server-ledger integration tests required |
| SEC-003 | Critical | Delivery setup allowed partner self-creation and shared order/customer visibility | Migration prepared, live blocked pending approval | Apply migration; run multi-user RLS denial tests |
| SEC-004 | High | WhatsApp function trusted browser totals/customer payload | Fixed in working tree | Deno type check blocked by DNS; function integration test pending local stack |
| SEC-005 | High | No deployed Edge Functions for payment/notification | Open | Deploy only tested functions with project secrets |
| SEC-006 | High | No backups or migration record | Open | Export/back up then capture baseline migration |
| SEC-007 | High | Public security-definer functions/views in live advisor | Open | Replace/revoke by explicit migration after dependency audit |
| REL-001 | Medium | No automated tests/local stack | Open | Add Supabase config, pgTAP, browser tests after baseline capture |
| REL-002 | Medium | Overlapping legacy login handlers/direct `Users` table references | Open | Consolidate OTP path after synthetic-auth UAT |
| OPS-001 | Medium | Dashboard shows elevated API/Realtime/Postgres/Storage errors | Open | Use logs/metrics with owner access; correlate endpoints before change |
