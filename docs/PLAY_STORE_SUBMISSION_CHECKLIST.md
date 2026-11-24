# JFAM Fresh Dairy — Google Play Submission Checklist

## 1. Bundle to Upload
- **File:** `dist/JFAM-Play-Release-2026-11-24.aab`
- **Package ID:** `com.jfam.customer`
- **Version:** `versionCode = 1`, `versionName = "1.0"`
- **SDK Targets:** `minSdkVersion = 24` (passes Play automatic protection), `targetSdkVersion = 36`
- **Signing Key:** `android/jfam-upload-key.jks` (keep `android/jfam-upload-key.jks` and `android/keystore.properties` backed up securely; **never** commit them to Git)
  - **SHA-1:** `F8:EE:E3:13:0E:4F:00:39:85:88:D4:73:F4:BB:08:25:A4:17:F6:AA`
  - **SHA-256:** `BD:75:FD:8D:DB:32:D1:DD:8E:05:3E:FD:09:EF:A3:08:D8:50:33:B3:4F:BE:B6:C8:BE:23:69:DC:85:42:ED:B1`
  - *Note:* Ready for a new Play Console listing. If uploading as an update to an already-published app that used a different upload key, use the original keystore or request an upload key reset in Play Console.

## 2. Supabase Migrations to Apply Before Launch
Apply these SQL migrations in the Supabase SQL Editor (in order) before going live:
1. `supabase/migrations/202610190005_checkout_numeric_quantity_multiplier.sql` — enforces COD-only checkout on the backend.
2. `supabase/migrations/202611240001_account_deletion.sql` — enables the in-app `delete_my_account()` RPC so customers can permanently delete their Supabase Auth account and personal data.

## 3. Public URLs Required in Play Console (deploy latest `www/` to Vercel/web first)
- **Privacy Policy URL:** `https://<your-jfam-domain>/privacy-policy.html`
- **Account Deletion URL (Data Safety form):** `https://<your-jfam-domain>/delete-account.html`

## 4. Play Console → App Content Declarations

### A. App Access (Reviewer Login)
- Select **"All or some functionality is restricted"** (browsing products is open; placing orders and profile management require Email OTP login).
- Provide clear reviewer instructions in Play Console:
  - How to sign in: Tap **Log In** (or **Profile** → **Create Account**), enter an email address, accept Terms & Privacy Policy, tap **Get OTP**, and enter the 6-digit OTP sent to that email.
  - Note that checkout uses **Cash on Delivery (no card/payment gateway required)**, and Pilani pincode `333031` is pre-filled for delivery testing.
  - Provide a dedicated reviewer test email inbox if Google requests fixed credentials.

### B. Data Safety Form
Declare the following collected data (all encrypted in transit via HTTPS; not sold or shared for advertising; users can request deletion in-app and via web URL):
- **Personal info:** Name, Email address, Phone number, Address (collected for App functionality & Account management)
- **Location:** Approximate location and Precise location (optional — collected only when the user taps "Use My Location" on the delivery address map picker; used for delivery fulfillment; no background location)
- **Financial info:** Purchase history (order records / Cash on Delivery status; no credit card or UPI credentials collected)

### C. Permissions
- The app requests only `INTERNET`, `ACCESS_COARSE_LOCATION`, and `ACCESS_FINE_LOCATION` (runtime prompt on the address map screen). No background location, camera, storage, contacts, SMS, or advertising ID permissions are requested.

### D. Content Rating & Target Audience
- Target audience: Adults / Household shoppers (18+, not directed to children under 13).
- Ads: **No, my app does not contain ads.**
- Government / Financial / Health apps: **No.**
