# Decisions and assumptions

## Decisions

- Keep plain JavaScript, Capacitor, Supabase and Razorpay. No framework rewrite.
- Do not re-enable checkout until authoritative backend checkout/payment/wallet paths exist.
- Treat all pre-existing browser orders and MilkCash as unverified drafts, never financial truth.
- Use migrations for all database changes; never apply them against production without a backup/export and explicit approval.
- Keep public anon key in client. No service-role key was found or will be added to client code.

## Verified blockers

- No local Supabase configuration/baseline schema or safe synthetic seed data.
- No production backup/PITR on current plan.
- No deployed Edge Functions.
- Local network cannot resolve Deno dependency hosts, blocking function type-check dependency download.
- No dedicated test Auth accounts or separate staging project were provided.

## Assumptions to validate

- Product catalog uses stable IDs suitable for checkout, rather than display names.
- Existing `orders`/`order_items` schema can accept immutable snapshots or requires new tables.
- Razorpay webhook secret and account ownership are available to an organization owner.
