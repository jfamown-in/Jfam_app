# JFAM backend phase 1 payment foundation

This phase makes checkout server-owned while keeping the current customer app usable.

## What changed

- `create_checkout` is the only order writer for customer checkout.
- The database resolves product prices from `product_catalog`; browser totals are not trusted.
- `payment_attempts` tracks COD and Razorpay UPI attempts.
- `wallet_transactions` is append-only and debited inside the checkout transaction.
- Razorpay QR creation accepts only a server-created `paymentAttemptId`, never a browser amount.
- Razorpay webhooks verify the raw request body signature before changing payment/order state.
- Manual UPI confirmation remains blocked in the browser.

## Supabase secrets required for Edge Functions

Set these in Supabase project function secrets, not in frontend code:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

## Deploy order

1. Back up production data.
2. Run `supabase/migrations/202610180002_payment_checkout_foundation.sql` in Supabase SQL Editor.
3. Deploy these Edge Functions:
   - `razorpay-create-qr`
   - `razorpay-payment-status`
   - `razorpay-webhook`
4. Configure the Razorpay webhook URL to the deployed `razorpay-webhook` function.
5. Set GitHub Actions variables/secrets for `backend-health.yml`:
   - repository variable `JFAM_SUPABASE_URL`
   - repository secret `JFAM_SUPABASE_ANON_KEY`
6. After functions are deployed, update `JFAM_EDGE_FUNCTIONS` in `.github/workflows/backend-health.yml` from `-` to `razorpay-create-qr,razorpay-payment-status,razorpay-webhook`.

## Rollback

- Disable Razorpay UPI in the frontend by reverting the `script.js` checkout wiring.
- Keep the SQL tables; they are additive and preserve audit/payment records.
- If the migration itself must be rolled back before live use, drop the new RPCs/functions first, then drop `payment_events`, `payment_attempts`, `checkout_attempts`, and `wallet_transactions` after exporting data.

## Limits still not finished

- Full subscription occurrence rows and delivery-control RPCs are not part of this slice.
- Admin refund/reversal UI is not part of this slice.
- Android UPI handoff testing still needs an emulator or device build.
