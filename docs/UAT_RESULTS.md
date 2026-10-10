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
