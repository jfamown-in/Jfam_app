# Address location improvement

## Delivered

- Address map now offers **Use My Location**.
- Browser uses the standard Geolocation API; Android uses Capacitor Geolocation when installed in the Capacitor runtime.
- Permission is requested only after an explicit button press.
- Current coordinates position a draggable map pin; reverse geocoding proposes address fields.
- Coordinates are stored on the selected saved address after the customer confirms the map pin, then copied to the order by the secure checkout RPC.
- The admin order card shows the address and a Google Maps link for the exact order pin.
- Locations more than 15 km from Pilani are rejected before an address can be used, preventing false delivery confirmation outside the service area.
- Manual map placement and manual address entry remain available when permission, GPS, or reverse geocoding fails.

## Android integration

- Added `@capacitor/geolocation` version `7.1.8` and coarse/fine location permissions.
- `npm run cap:sync` detects the plugin successfully.
- Android debug build is blocked on this machine because Android SDK location is not configured (`ANDROID_HOME` or ignored `android/local.properties`). No signing settings or developer-machine files were added.

## Backend rollout

- Apply `202611220001_admin_workspace_access.sql` before `202610190005_checkout_numeric_quantity_multiplier.sql` so the coordinate columns exist before the checkout RPC is replaced.
- After the migrations, saved_addresses sync and order checkout both carry the coordinates; the admin dashboard queries them and links to Google Maps.
- This uses Google Maps URLs to display a confirmed point, while the in-app picker remains Leaflet/OpenStreetMap. Embedding Google's map itself requires a configured Maps API key.
