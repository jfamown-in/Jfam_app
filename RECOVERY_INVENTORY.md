# JFAM recovery inventory

This repository was rebuilt from the supplied source archive on 2026-10-10.

Included:

- Customer web app source and Capacitor Android wrapper.
- Supabase SQL and Edge Function source for review only.
- 24 recovered image assets: 10 labelled product images, logo, delivery scooter, and 12 backgrounds.

Excluded:

- Corrupt historical `.git` data.
- `node_modules` and generated `www` output.
- Android signing key, keystore configuration, and `local.properties`.
- Android IDE and Gradle cache files.

The recovered images are mapped in `product-images.js`. Background, logo, and scooter images are retained but are not automatically placed in the UI because their intended screen locations were not encoded in the source.
