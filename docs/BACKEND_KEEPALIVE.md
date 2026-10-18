# JFAM backend keepalive and health monitor

This monitor creates safe, read-only backend activity and alerts when the Supabase project or required public interfaces stop responding. It is the strongest safe Free-plan keepalive we can run without writing fake production data. Supabase still controls Free-plan pause policy, so this is best-effort engineering rather than a contractual guarantee.

## What it checks

- DNS for the configured Supabase project host.
- Auth settings endpoint with the public anon key.
- REST gateway and one read-only table probe.
- `backend_healthcheck()` RPC.
- Optional Edge Functions when names are added to `JFAM_EDGE_FUNCTIONS`.

The monitor never creates users, orders, payments, refunds, wallet entries, delivery records, or other production data.

## First Supabase SQL to run

Run `supabase/migrations/202610180001_backend_healthcheck.sql` in the Supabase SQL editor. It creates a read-only `backend_healthcheck()` RPC that returns generic service status only.

## GitHub Actions setup

The workflow is `.github/workflows/backend-health.yml` and runs hourly plus manual dispatch.

Recommended repository settings:

- `JFAM_SUPABASE_URL` as a GitHub Actions repository variable.
- `JFAM_SUPABASE_ANON_KEY` as a GitHub Actions secret.

If those are not set, the script falls back to the public values already used by the frontend in `Supabase.js`.

## Local check

```bash
npm run health:backend
```

If local Node is broken, use the bundled Node executable from Codex workspace dependencies to run `scripts/backend-healthcheck.mjs` directly.

## Later additions

After Razorpay Edge Functions are deployed, replace `JFAM_EDGE_FUNCTIONS: '-'` in the workflow with a comma-separated list of deployed function names so the monitor checks them too.


## Phase 1 launch stance

For Phase 1, this is intentionally read-only. We want real backend activity through Auth, REST, and RPC without creating fake business records. If the project ever pauses anyway, the workflow should fail loudly so we can resume the project and investigate.
