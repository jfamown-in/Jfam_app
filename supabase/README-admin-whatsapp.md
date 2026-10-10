# JFAM Admin Panel + WhatsApp Notifications

This setup keeps the customer app as-is, adds a browser admin panel, and sends a WhatsApp message to the admin whenever a customer places an order.

## 1. Admin Panel

Open `admin.html` in the browser after hosting the app or running a local server.

The panel:

- signs in admin by email OTP
- loads orders from `orders` and `order_items`
- listens for Supabase Realtime changes
- lets admin update order status
- can play a sound/browser notification when a new order arrives

## 2. Supabase SQL

Run `supabase/admin-setup.sql` in the Supabase SQL editor.

Then sign in once from `admin.html` with the admin email. After that, run the final insert from the SQL file with the real admin email:

```sql
insert into public.admin_users (user_id, email)
select id, email
from auth.users
where lower(email) = lower('ADMIN_EMAIL_HERE')
on conflict (user_id) do nothing;
```

If the admin panel says orders cannot load, check:

- admin email exists in `auth.users`
- admin user exists in `public.admin_users`
- Realtime is enabled for `orders` and `order_items`
- RLS policies from `admin-setup.sql` were created

## 3. WhatsApp Cloud API

Create a Meta WhatsApp Cloud API app and collect:

- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- admin phone number in international format, for example `919812345678`

Set Supabase Edge Function secrets:

```powershell
supabase secrets set WHATSAPP_ACCESS_TOKEN="YOUR_TOKEN"
supabase secrets set WHATSAPP_PHONE_NUMBER_ID="YOUR_PHONE_NUMBER_ID"
supabase secrets set ADMIN_WHATSAPP_PHONE="91XXXXXXXXXX"
```

Deploy the function:

```powershell
supabase functions deploy send-order-whatsapp
```

The customer app calls this function after `completeSelectedCartOrder()` creates a new order. If WhatsApp fails, checkout still completes and the error is logged in the console.

## 4. Recommended Hosting

For production, host these files on HTTPS:

- customer app: `index.html`
- admin panel: `admin.html`

Do not put any service-role key in frontend files. The WhatsApp access token must stay only in Supabase Edge Function secrets.
