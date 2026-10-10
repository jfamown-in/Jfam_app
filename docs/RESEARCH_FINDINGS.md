# Research findings

Research performed 2026-10-10. Links are evidence, not copied architecture.

| Source | Pattern supported | JFAM action |
| --- | --- | --- |
| [Supabase user-management example](https://github.com/supabase/supabase/tree/master/examples/user-management/nextjs-user-management) | Versioned migrations, Auth-triggered profiles, RLS, local config | Capture a baseline migration and config before further live changes. |
| [Supabase database-function guidance](https://supabase.com/docs/guides/database/functions) | Prefer invoker; definer functions need fixed search path, ownership checks, explicit grants | Replace public-definer checkout/admin helpers. |
| [Supabase secure-data guide](https://supabase.com/docs/guides/database/secure-data) | Publishable key is safe only with RLS; service role stays server-only | Keep current client key; never add service key to JS. |
| [Supabase RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security) | RLS plus least-privilege grants and policy testing | Add denial tests for customer/admin/delivery roles. |
| [Supabase Stripe webhook example](https://github.com/supabase/supabase/tree/master/examples/edge-functions/supabase/functions/stripe-webhooks) | Payment state comes from a signed server webhook | Use same boundary for Razorpay; no client success claim. |
| [Supabase Edge Functions guide](https://supabase.com/docs/guides/functions) | Secrets in project secrets; short, idempotent functions | Deploy webhook/notification functions only after tests. |
| [Supabase CLI testing guide](https://supabase.com/docs/guides/local-development/cli/testing-and-linting) | pgTAP and CLI lint for disposable local DB | Add local config + pgTAP after baseline pull. |
| [Supabase Realtime guidance](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes) | Private Broadcast + scoped topics preferred for production | Avoid broad row publications for orders/profiles. |
| [RLS integration demo](https://github.com/ConnorMeador/supabase-rls-auth-demo) | Explicit grants and CI-backed cross-role denial tests | Make grants/policies explicit in migrations. |
| [Production payment-kit example](https://github.com/suleymansurucu/stripe-supabase-subscription-kit) | Webhook-driven billing state, not client cache | Treat payment provider/webhook as payment authority. |

## Comparative matrix

| Dimension | JFAM now | Research-backed pattern | Gap | Action |
| --- | --- | --- | --- | --- |
| Database | Dashboard-managed, incomplete SQL files | Versioned baseline + incremental migrations | No reproducible schema | Pull/commit baseline before next feature |
| Checkout | Browser-derived total/order | Transactional RPC + idempotency | No source of truth | Build RPC and immutable snapshots |
| Payments | Client polling/manual confirmation | Signed webhook changes state | Forged success possible before lockdown | Deploy Razorpay webhook |
| Wallet | Local storage ledger | Append-only server ledger | Browser can be edited | Add wallet tables/transaction RPC |
| RLS | Enabled but overbroad partner policies | Role/ownership-only policies + denial tests | Cross-user exposure | Apply prepared lockdown then test |
| Functions | Source-only WhatsApp | Deployed, authenticated functions with secrets | No deploy/config | Deploy after secret/config review |
| Realtime | Broad publications in setup script | Private scoped broadcasts | Scale/privacy risk | Limit to scoped notifications |
| Testing | Build only | Local Supabase + pgTAP + browser E2E | No backend verification | Establish disposable test project |
