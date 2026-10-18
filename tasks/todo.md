# JFAM release task tracker

Use this as the execution order. A task is complete only with its acceptance criteria, verification evidence, and review recorded in its pull request/commit.

## Now — no live database changes

- [ ] **T0.1** Confirm company-controlled owners for Supabase, Razorpay, GitHub, Play Console, DNS, and signing material.  
  **Accept:** two active company administrators per critical service.  
  **Verify:** dashboard access review; credentials are not copied into source or chat.

- [ ] **T0.2** Export Supabase schema/data and document restoration owner/process.  
  **Accept:** dated recovery package stored outside the app repository.  
  **Verify:** restoration rehearsal in a non-production project, or a documented blocker.

- [ ] **T0.3** Create a company-owned private GitHub repository and staging Supabase/Razorpay-test environment.  
  **Accept:** staging and production credentials/data are separate.  
  **Verify:** staging build configuration cannot target production by accident.

- [ ] **T1.1** Capture the live Supabase baseline as versioned migrations.  
  **Accept:** a fresh staging project can be recreated from reviewed migration files.  
  **Verify:** schema/policy/function/grant comparison.

## Security foundation — live change after backup and approval

- [ ] **T1.2** Apply the delivery-partner lockdown migration in staging, then production.  
  **Accept:** no customer can self-create a delivery role or browse unrelated customer data.  
  **Verify:** customer/partner/admin RLS test matrix.

- [ ] **T1.3** Implement admin-only partner assignment and server-controlled delivery updates.  
  **Accept:** partners see only explicitly assigned work.  
  **Verify:** RLS matrix plus UI path test.

- [ ] **T1.4** Resolve Security Advisor findings for public function grants, security-definer views/search paths, legacy login lookup, and realtime.  
  **Accept:** remaining exceptions are documented and approved.  
  **Verify:** Advisor and SQL permission suite.

## Authoritative orders and wallet

- [ ] **T2.1** Add additive schema for price snapshots, occurrences, checkout idempotency, payment events, and audit records.  
  **Accept:** order history remains immutable and failures roll back fully.  
  **Verify:** migration/constraint/rollback tests.

- [ ] **T2.2** Implement append-only server wallet ledger and balance rules.  
  **Accept:** no browser-controlled balance or duplicate/negative debit.  
  **Verify:** concurrency, replay, reversal, and tampering tests.

- [ ] **T2.3** Implement `create_checkout` transaction RPC.  
  **Accept:** server calculates totals, validates ownership, creates every related record atomically, and is idempotent.  
  **Verify:** forced-failure, duplicate-key, address/price tampering, and concurrent checkout tests.

- [ ] **T2.4** Encode state transitions for one-time orders, subscription actions, COD, wallet, online UPI, and refunds.  
  **Accept:** rejected transitions cannot be forced by the client.  
  **Verify:** SQL transition matrix.

## Separate Razorpay workstream

- [ ] **T3.1** Set test Razorpay keys/webhook secret directly in Supabase Edge Function secrets.  
  **Accept:** secrets never appear in Git/client/mobile bundle/logs.  
  **Verify:** secret scan and function configuration review.

- [ ] **T3.2** Implement an authenticated payment-attempt endpoint using only server-calculated checkout data.  
  **Accept:** customer cannot select amount/status/recipient or another user’s attempt.  
  **Verify:** authorization/tampering/idempotency API tests.

- [ ] **T3.3** Implement and deploy raw-body HMAC-validating Razorpay webhook.  
  **Accept:** only verified events or authorized finance action confirm payment.  
  **Verify:** valid/invalid/tampered/replayed/delayed/out-of-order event tests.

- [ ] **T3.4** Implement pending, failed, expired, and refund/reversal operations.  
  **Accept:** a restart or duplicate action cannot cause duplicate charges/orders.  
  **Verify:** pending/resume/retry/refund UAT.

## Client integration and release verification

- [ ] **T4.1** Replace blocked checkout UI with authoritative server-backed state screens.  
  **Accept:** no confirmation before server confirmation.  
  **Verify:** Playwright success/pending/failure/retry/duplicate tests.

- [ ] **T4.2** Wire client checkout to `create_checkout` and payment-attempt endpoint with a per-intent idempotency key.  
  **Accept:** altered local state cannot alter money or order status.  
  **Verify:** DevTools tampering/offline/retry test.

- [ ] **T4.3** Move saved-address persistence/validation to authenticated server rules; retain consented location picker.  
  **Accept:** coordinates and addresses remain private and ownership-checked.  
  **Verify:** cross-account and delivery-radius tests.

- [ ] **T4.4** Configure Android SDK in development/CI and test a signed internal build.  
  **Accept:** app resumes authoritative pending/completed payment after Android lifecycle events.  
  **Verify:** UPI handoff/background/process-death/back-navigation checklist.

- [ ] **T5.1** Add CI checks: JS, SQL/RLS, Playwright, Capacitor sync, Android debug build, and migration review.  
  **Accept:** a clean checkout passes required checks before merge.  
  **Verify:** CI artifacts.

- [ ] **T5.2** Add payment monitoring, reconciliation dashboard/query, and runbooks.  
  **Accept:** staff can resolve stuck test payments without manual database edits.  
  **Verify:** Razorpay-test tabletop drill.

- [ ] **T5.3** Complete staged test-mode UAT, then conduct controlled production cutover.  
  **Accept:** every production payment reconciles to one order/payment attempt.  
  **Verify:** launch checklist and first-live-payment review.
