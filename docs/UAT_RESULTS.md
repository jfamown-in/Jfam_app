# UAT results — 2026-10-10

## Execution summary

| Metric | Count |
| --- | ---: |
| Planned | 9 |
| Executed | 1 |
| Passed | 1 |
| Failed | 0 |
| Blocked | 8 |
| Not run | 0 |
| Pass rate among executed | 100% |

## Executed

- **UAT-001 PASS** — Built `www/` with `npm run build`; loaded `http://localhost:4173/` in Codex in-app browser. Home screen, product category navigation and labelled product images rendered. Selecting a protected product action redirected unauthenticated user to Login. Evidence: browser accessible tree captured during session.

## Checks

- `node --check script.js` with bundled Node: PASS.
- `npm run build`: PASS.
- `git diff --check`: PASS.
- `deno check supabase/functions/send-order-whatsapp/index.ts`: BLOCKED. Deno could not resolve dependency hosts from this environment; no code failure concluded.

## Blockers

No local Supabase config/schema baseline, test project, synthetic accounts, deployed checkout RPC, webhook secrets, or Android emulator were available. No production customer data was written or used for tests.

## Release recommendation

**Do not release checkout, wallet, delivery controls, WhatsApp or payment flows.** Catalog-only browsing is verified. Production readiness requires backup, baseline migrations, authoritative checkout/wallet, RLS tests, webhook verification, and full UAT.

## Location feature verification — 2026-10-10

- `node --check script.js`: PASS.
- `npm run cap:sync`: PASS; Capacitor detected `@capacitor/geolocation@7.1.8`.
- Android `assembleDebug`: BLOCKED; Android SDK location is not configured on this machine. This is an environment blocker, not a verified compilation failure.

## Order-flow UI verification — 2026-10-10

- **PASS (frontend journey):** Product selection, one-time plan, delivery slot/date, cart, address selection, price breakdown, and payment-method screen all rendered in the local in-app browser.
- **PASS (security regression):** Selecting Cash on Delivery reached the secure checkout block and displayed `Secure checkout is being activated. No order has been created.` No order, payment, wallet transaction, or external payment request was created.
- **NOT RUN:** UPI creation/payment confirmation, webhook verification, server checkout RPC, wallet debit and delivery occurrence creation remain unavailable by design until the backend implementation exists.
