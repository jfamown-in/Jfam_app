# Address location improvement

## Delivered

- Address map now offers **Use My Location**.
- Browser uses the standard Geolocation API; Android uses Capacitor Geolocation when installed in the Capacitor runtime.
- Permission is requested only after an explicit button press.
- Current coordinates position a draggable map pin; reverse geocoding proposes address fields.
- Coordinates are not persisted in browser storage or sent to Supabase by this change.
- Locations more than 15 km from Pilani are rejected before an address can be used, preventing false delivery confirmation outside the service area.
- Manual map placement and manual address entry remain available when permission, GPS, or reverse geocoding fails.

## Android integration

- Added `@capacitor/geolocation` version `7.1.8` and coarse/fine location permissions.
- `npm run cap:sync` detects the plugin successfully.
- Android debug build is blocked on this machine because Android SDK location is not configured (`ANDROID_HOME` or ignored `android/local.properties`). No signing settings or developer-machine files were added.

## Future backend step

When authoritative addresses are migrated, add optional `latitude`, `longitude`, `location_accuracy_meters`, and `location_confirmed_at` to the server-owned address record. Apply an explicit privacy notice and retain the coordinates only for active delivery fulfilment.
