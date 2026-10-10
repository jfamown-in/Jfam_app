# Project understanding

## Verified purpose

JFAM is a customer-facing dairy ordering and recurring-delivery app for milk and related dairy products. Customers browse a catalog, maintain a cart/wishlist and addresses, choose delivery timing, authenticate by email OTP, and view orders/subscriptions. Administrators and delivery partners are represented in the Supabase schema/scripts.

## Architecture

- Frontend: static `index.html`, `dairy-app.css`, and a single `script.js` browser application.
- Mobile: Capacitor Android wrapper (`com.jfam.customer`) copies the web bundle to `www/`.
- Backend: hosted Supabase Auth, Postgres/Data API, Realtime, and intended Edge Functions.
- Current client key: public Supabase anon/publishable key, acceptable only with correct RLS. No service-role key was found in tracked source.

## Verified workflows

| Workflow | UI | Current backend state | Status |
| --- | --- | --- | --- |
| Catalog | Product screens + static seed | `product_catalog` reads/realtime | Partially verified |
| Auth | Email OTP | Supabase Auth + profiles | Needs end-to-end test account |
| Cart/wishlist/address | Browser UI | Direct user-scoped Supabase tables | Needs RLS integration test |
| Checkout | Payment screens | No authoritative checkout RPC/function | Safely blocked |
| Wallet | MilkCash screens | No server ledger | Safely blocked |
| Delivery controls | Subscription controls | No transactional backend rules | Safely blocked |
| WhatsApp | Source-only Edge Function | No live function deployed | Blocked |

## Local run

```sh
npm run build
python -m http.server 4173
```

`www/` is generated. No local Supabase stack can start yet because this repository lacks `supabase/config.toml`, a complete baseline schema migration, and test seed data.
