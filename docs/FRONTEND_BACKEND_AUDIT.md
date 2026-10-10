# Frontend and backend audit — 2026-10-10

## Evidence

- Source inspected: 2,231-line HTML, 7,147-line CSS, 12,299-line JavaScript.
- `script.js` contains 115 event listeners and 160 browser-storage reads/writes.
- Browser smoke test: home/catalog render; unauthenticated product action correctly sends user to Login.
- Live Supabase review completed previously; current source SQL and function files reread for this audit.

## Frontend

| Priority | Finding | Evidence | Improvement |
| --- | --- | --- | --- |
| P0 | Checkout UI is intentionally disabled, but screens still resemble a working payment flow | COD, UPI and card paths now show blocking messages | Replace payment CTAs with one explicit `Checkout temporarily unavailable` state until server checkout is deployed. Do not show payment success UI from client state. |
| P0 | Local state remains extensive | `localStorage` drives cart, order drafts, subscription drafts, addresses, profile cache and more | Define ownership per state: server owns identity, catalog, addresses, orders, payments, wallet and deliveries; browser owns only in-progress form/cart drafts and UI preferences. |
| P1 | Monolithic JavaScript makes regressions likely | 12,299 lines mix navigation, DOM rendering, authentication, Supabase calls, payments, delivery rules and maps | Split incrementally: `ui/navigation.js`, `features/catalog.js`, `features/auth.js`, `features/cart.js`, `services/supabase.js`, then move one tested feature at a time. No framework rewrite needed. |
| P1 | Duplicate/legacy auth paths | OTP, registration, Google and legacy direct table calls coexist | Keep one email-OTP flow. Remove dead `Users`-table/password-era code after synthetic-account UAT. Remove public login-profile lookup by redesigning registration flow around Auth. |
| P1 | Desktop is mobile shell centered on page | `.mobile-app` max width is 390px except cart | Keep this for app-like web, or add desktop layout at ≥768px: two-column catalog/cart, wider forms, keyboard-friendly header. Do not stretch current cards blindly. |
| P1 | Error/loading/retry states are inconsistent | `alert`, console logging and optimistic local writes exist throughout script | Standardize request state: disabled submit, inline error, retry, timeout message, and idempotent action key. |
| P1 | Payment/saved-card UI is misleading | saved cards were local placeholders; card checkout is unavailable | Hide saved-card/add-money UI until payment tokenization provider exists. Never retain PAN/CVV in browser storage. |
| P2 | Accessibility is improved but incomplete | focus-visible and several labels exist; tabs/buttons often lack selected semantics; product images use generic labels | Use real `aria-selected` tabs, connect labels to all inputs, add live region for toast/errors, set dialog focus/escape, test keyboard route. |
| P2 | Performance/caching | Google Fonts, Leaflet CSS/JS and large all-in-one assets load globally | Load map code only on address screen, pre-size/lazy-load images, self-host/limit font weights, version static assets by build hash. |
| P2 | No automated UI regression suite | no tests/config discovered | Add Playwright only after a stable local test environment; begin with catalog, OTP, cart, denied checkout and responsive navigation. |

### Recommended frontend sequence

1. Make disabled checkout/wallet state obvious.
2. Consolidate authentication paths and remove legacy code after test coverage.
3. Create a small server-client service boundary for catalog, cart, address and checkout.
4. Extract one feature at a time from `script.js`; retain existing visual system.
5. Add browser tests at each extraction.

## Backend

| Priority | Finding | Evidence | Improvement |
| --- | --- | --- | --- |
| P0 | No authoritative checkout, wallet, payment or delivery backend | no deployed Edge Functions; no checkout RPC/ledger | Create transactional `create_checkout` RPC plus append-only wallet tables. Validate products/prices/stock/address on server. Use idempotency key. |
| P0 | Unsafe delivery policies/functions | live audit found public delivery pool/partner creation; source script formerly recreated them | Apply prepared lockdown migration, then create admin assignment + narrowly validated delivery-status RPC. |
| P0 | Payment source of truth missing | Razorpay calls are referenced but no live function and no webhook | Create `razorpay-webhook` Edge Function: verify signature, deduplicate provider event, update payment attempt/order atomically. |
| P0 | Backup/recovery gap | current free project has no scheduled backups/PITR | Export schema/data before every live migration; move production to backup-capable plan or maintain tested external backup routine. |
| P1 | Migration history absent | dashboard reports no migrations; repo SQL is setup scripts, not baseline | Pull current schema into an initial reviewed migration, add `supabase/config.toml`, and require migration review/CI. |
| P1 | `SECURITY DEFINER` risk | two views and public executable functions reported by Advisor | Prefer invoker. If definer is required: fixed search path, ownership check, explicit revoke from `public`, minimum grant, test denial. Use `security_invoker` for admin views where compatible. |
| P1 | Browser accesses business tables directly | script directly reads/writes cart/wishlist/address/profile and formerly orders | Retain only user-scoped low-risk CRUD via RLS. Move money, stock, orders, refunds, delivery assignment and notifications behind trusted APIs. |
| P1 | WhatsApp function previously trusted client payload | source accepted items/customer/total | Local source now accepts `orderId` and RLS-loads stored data. Deploy only after authoritative order creation exists. |
| P1 | Realtime publication overexposes data and scales poorly | old setup publishes orders/items/profiles globally | Use private scoped Broadcast topics; do not publish customer/order tables broadly. |
| P2 | No test database or RLS tests | no `config.toml`, pgTAP tests or seed data | Create disposable local/staging project; add pgTAP for ownership, role, rollback and idempotency. |
| P2 | Observability incomplete | dashboard error rates elevated but no traces/correlation design | Structured Edge Function logs with order/payment attempt ID, error dashboard, alert only on sustained failure. |

### Backend implementation order

1. Backup/export, capture migration baseline, create disposable test database.
2. Apply delivery lockdown migration.
3. Add checkout/payment/wallet schema, constraints, RLS and pgTAP tests.
4. Implement checkout RPC + idempotency and server prices.
5. Implement signed Razorpay webhook; deploy test mode first.
6. Wire frontend to only that RPC; enable checkout only after UAT.
7. Add admin assignment/delivery-status server APIs and private realtime.

## Do not do now

- Do not move to Android Studio-native app solely for architecture reasons; Capacitor is suitable while web flows are stabilized.
- Do not add a service-role key, client payment success switch, public delivery pool, or browser wallet ledger.
- Do not run migrations on current production project before backup/export and live approval.
