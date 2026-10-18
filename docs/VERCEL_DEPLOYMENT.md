# Vercel deployment

Use Vercel's GitHub integration for this static customer app.

## Project settings

- Repository: `jfamown-in/Jfam_app`
- Framework preset: Other
- Install command: `npm ci`
- Build command: `npm run build`
- Output directory: `www`
- Production branch: `main`

These settings are also recorded in `vercel.json` so imports are reproducible.

## Required environment variables

None are required for the current frontend build. The browser app reads the public Supabase URL and anon key from `Supabase.js`.

Do not add service-role keys, Razorpay secrets, webhook secrets, Android signing material, or private tokens to Vercel or GitHub for this frontend build.

## Deployment flow

1. Import `jfamown-in/Jfam_app` in Vercel.
2. Keep preview deployments enabled for pull requests.
3. Keep production deployments tied to `main`.
4. Test preview URLs before merging.
5. Promote only after the mobile viewport checks pass.

## Current limitation

Payment and backend-hardening work still depends on Supabase migrations and Razorpay verification services. A successful Vercel deployment proves the frontend build is available; it does not make checkout production-ready by itself.
