# JFAM Customer App Documentation

## 1. Short Summary

JFAM Customer App ek fresh dairy ordering aur subscription mobile app hai. Iska main purpose customers ko milk, chaach, ghee, dahi, paneer jaise dairy products ghar baithe order karne, regular subscription plan choose karne, delivery address manage karne, payment karne, wallet balance use karne, aur apni delivery/order history track karne ka simple digital experience dena hai.

App ka focus daily-use dairy business par hai, jahan customer one-time order bhi kar sakta hai aur recurring milk delivery ke liye 7 days, 15 days, 30 days ya customised plan bhi select kar sakta hai. Backend Supabase se connected hai, jisme customer data, cart, wishlist, orders, saved addresses, UPI IDs, product catalog, admin access, realtime updates, delivery partner support aur WhatsApp admin notification jaisi capabilities available hain.

## 2. App Ka Core Idea

JFAM app local dairy business ko digital platform me convert karta hai. Traditional dairy delivery me customer usually phone call, WhatsApp, register ya manual subscription system par depend karta hai. Is app ke through customer directly products browse kar sakta hai, quantity aur plan select kar sakta hai, delivery address save kar sakta hai, payment mode choose kar sakta hai aur order place kar sakta hai.

Business ke liye app orders ko structured format me capture karta hai. Supabase backend ke through same data admin panel, delivery partner app aur customer app ke beech sync ho sakta hai. Isse manual confusion kam hota hai, delivery tracking improve hoti hai aur customer ko professional app-like experience milta hai.

## 3. Target Users

- Daily milk aur dairy product buyers.
- Families jo recurring fresh milk delivery chahte hain.
- Customers jo Pilani, Rajasthan area me dairy delivery use karna chahte hain.
- Dairy business/admin team jo customer orders, inventory aur delivery operations ko digital manage karna chahti hai.
- Delivery partners jo assigned orders aur delivery status handle kar sakte hain.

## 4. Main Value Proposition

- Fresh dairy products ko app-based ordering system me convert karta hai.
- One-time order aur subscription dono flows support karta hai.
- Customer profile, saved address, wishlist, cart, payment aur wallet features ek hi app me milte hain.
- Supabase realtime sync ke through cart, wishlist, orders, profile aur address data user account se linked rehta hai.
- Admin aur delivery operations ke liye backend setup already planned hai.
- WhatsApp notification support admin ko new order ke baare me instantly alert kar sakta hai.
- Android app build ke liye Capacitor wrapper included hai.

## 5. Product Catalog

App me dairy categories category-wise organize ki gayi hain:

- Milk
- Chaach
- Ghee
- Dahi
- Paneer

Current product listing me ye products available hain:

| Category | Product | Starting Price |
| --- | --- | --- |
| Milk | RAW BUFFALO MILK | Rs. 75/L |
| Milk | RAW COW MILK | Rs. 51/L |
| Milk | RAW A2 COW MILK | Rs. 85/L |
| Chaach | BUFFALO BILONA CHAACH | Rs. 40/L |
| Chaach | COW BILONA CHAACH | Rs. 35/L |
| Ghee | BUFFALO GHEE | Rs. 1300/Kg |
| Ghee | COW GHEE | Rs. 1100/Kg |
| Ghee | RAW A2 COW GHEE | Rs. 2800/Kg |
| Dahi | DAHI | Rs. 72/500g |
| Paneer | PANEER | Rs. 450/Kg |

Home page par highlighted/featured products bhi dikhte hain:

- RAW COW MILK
- BUFFALO BILONA CHAACH
- RAW A2 COW GHEE
- DAHI
- PANEER

Product data static HTML se start hota hai, lekin JavaScript Supabase ke `product_catalog` table se realtime catalog hydrate/update karne ki capability rakhta hai. Iska matlab future me admin product name, price, stock status, description, image ya availability update kare to customer app me live reflection possible hai.

## 6. Subscription Plans

App ka important feature recurring delivery/subscription planning hai. Customer product detail screen se plan select kar sakta hai.

Available plan types:

- 30 Days Plan: Daily stable delivery ke liye.
- 15 Days Plan: Mid-duration recurring order ke liye.
- 7 Days Plan: Short weekly trial/regular plan ke liye.
- Customised Plan: Customer selected dates, delivery days, quantity aur flexibility ke liye.
- One Time Only Plan: Single order ke liye, jisme COD option available hai.

Subscription screens me filters bhi available hain:

- All
- Monthly
- Weekly
- 15 Days
- Customised

Home screen par active subscribed products ka daily delivery card show hota hai, jisme aaj/nearest delivery date ke hisaab se customer ke delivery products show kiye ja sakte hain.

## 7. Customer App Screens

App single-page mobile experience ke form me built hai. `index.html` me multiple screens hain aur JavaScript `.screen.active` class se screen switching handle karta hai.

### Authentication Screens

- Splash Screen: App open hote hi JFAM logo based loading/splash experience.
- Login Screen: Email-based login with policy checkbox.
- Register Screen: Name, mobile, email, date of birth aur terms/privacy acceptance.
- OTP Screen: Email OTP verify karne ke liye 6 digit OTP boxes.
- Success Screen: Login/register success confirmation.

### Home And Discovery

- Home Screen: Top bar, profile access, wallet shortcut, notifications, wishlist, banners, subscription plan cards, categories, featured products.
- Products Screen: Category strip ke saath all product listing.
- Product Detail Screen: Product image, product description, plan selection, date/slot/quantity options, wishlist/cart/buy actions.
- Plans Screen: Subscription plan details aur benefit cards.
- Notifications Screen: Cart, wishlist, subscription aur app reminders ki list.

### Shopping And Checkout

- Orders/Cart Screen: Selected cart products, quantity, price panel aur checkout selection.
- Cart Address Screen: Checkout ke liye saved/add/edit delivery address selection.
- Checkout Screen: Buy-now product summary aur delivery address form.
- Payment Mode Screen: COD, UPI aur card-style payment UI. Card option currently "soon"/disabled state me shown hai.
- UPI QR Screen: QR based UPI payment flow with timer and payment progress messaging.
- Payment Success Screen: Payment/order success confirmation.
- Cart Success Screen: Product cart me add hone ke baad success state.

### Profile And Account

- Profile Screen: Customer name/mobile display aur profile menu.
- Edit Profile Screen: Name, email, mobile update form.
- Profile Orders Screen: Customer ke placed orders aur cancel product/order flow.
- Profile Subscriptions Screen: Active subscription list, plan filters aur calendar style subscription detail.
- Profile Addresses Screen: Delivery addresses add/edit/remove.
- Profile Cards Screen: Future saved card management UI.
- Profile UPI Screen: Saved UPI IDs add/edit/remove.
- Wallet Screen: MilkCash balance and wallet options.
- Wallet Transactions Screen: MilkCash credit/debit ledger.
- Add Money Screen: Wallet recharge amount and payment selection UI.
- Help & Support Screen: Customer care, email support, timing aur issue-wise help content.
- Privacy Policy Screen: App data collection/use/security related policy.
- Terms Screen: App usage, ordering, delivery, payments, subscriptions, refunds and restrictions.

### Delivery Controls

Delivery Controls Screen active subscription ke future deliveries manage karne ke liye designed hai. Customer selected subscription/product ke liye:

- Delivery pause kar sakta hai.
- Product switch request kar sakta hai.
- Quantity change kar sakta hai.
- Delivery slot change kar sakta hai.
- Delivery address change/add kar sakta hai.

JavaScript `deliveryControlsByProduct` data structure ke through per-product future delivery controls save karta hai. App wallet adjustment logic bhi include karta hai, jisse product switch/quantity change ke price difference ko MilkCash transactions me adjust kiya ja sakta hai.

## 8. Address And Map Verification

App address management ko multiple places par support karta hai:

- Profile saved addresses.
- Cart checkout address.
- Buy-now checkout address.
- Delivery controls address override.

Current default service location Pilani, Rajasthan aur pincode 333031 ke around configured hai. Address form me name, mobile, house/tower/block, street/locality, town, city aur state fields hain.

Map verification modal bhi included hai. It uses a map picker flow where typed address par pin set hota hai, customer pin adjust kar sakta hai, aur selected exact location use kar sakta hai. JavaScript geocoding/reverse-geocoding flow ke through selected location se address fields improve karne ki capability rakhta hai.

## 9. Payment And Wallet Flow

Payment Mode screen me following payment concepts present hain:

- COD: One-time order ke liye available; COD fee logic Rs. 10 add karta hai.
- UPI: QR based payment flow.
- Card: UI present hai but currently disabled/soon state.
- MilkCash: Wallet balance ko discount/adjustment ke form me checkout par apply kiya ja sakta hai.

UPI QR flow me Razorpay integration hooks available hain:

- `razorpay-create-qr` Supabase Edge Function call.
- Payment attempt ID.
- QR image URL.
- QR expiry timer.
- `razorpay-payment-status` polling every few seconds.
- Success par order completion.

Wallet me MilkCash ledger maintain hota hai:

- Current balance.
- Credits.
- Used amount.
- Transaction history.
- Order payment me wallet deduction.
- Delivery control adjustments me debit/credit.

## 10. Order Flow

Typical customer order flow:

1. Customer login/register karta hai.
2. Home/products se product select karta hai.
3. Product detail screen par plan, quantity, date, slot choose karta hai.
4. Add to cart ya buy now action use karta hai.
5. Cart me selected products review karta hai.
6. Delivery address select/add/edit karta hai.
7. Payment mode choose karta hai.
8. COD/UPI payment complete karta hai.
9. Order `placedOrders` me save hota hai aur Supabase `orders` / `order_items` tables se sync hota hai.
10. Admin ko WhatsApp order notification bhejne ki Edge Function call available hai.
11. Customer profile orders/subscriptions screen se order status/history dekh sakta hai.

Order data me product items, selected plan, quantity, delivery dates, slot, address, payment mode, MilkCash used, COD fee, total amount aur order category jaisi information preserve ki jaati hai.

## 11. Backend Architecture

Backend Supabase project se connected hai. `Supabase.js` app me global `window.supabaseClient` create karta hai. Yeh client frontend se authentication, database operations, realtime channels aur Edge Function calls ke liye use hota hai.

### Supabase Features Used

- Email OTP login/register.
- Google OAuth hooks.
- User profile sync.
- Cart items sync.
- Wishlist items sync.
- Orders and order items sync.
- Saved addresses sync.
- Saved UPI IDs sync.
- Realtime user data updates.
- Product catalog realtime updates.
- Edge Function calls for WhatsApp and Razorpay payment flows.

### Important Tables/Areas

- `profiles`: User profile data.
- `cart_items`: User cart sync.
- `wishlist_items`: User wishlist sync.
- `orders`: Order master rows.
- `order_items`: Order product rows.
- `saved_addresses`: Customer delivery addresses.
- `saved_upis`: Saved UPI IDs.
- `product_catalog`: Product data, pricing, stock/availability.
- `admin_users`: Admin access control.
- `delivery_partners`: Delivery partner profiles.
- `inventory_movements`: Inventory update log for admin operations.

## 12. Admin And Operations Support

Supabase setup files show admin-side planning:

- `admin-setup.sql`: Admin users ko all orders read/update access, customer profile read access, delivery partner management policies.
- `admin-realtime-inventory-setup.sql`: Admin realtime backend setup, product stock/admin columns, inventory movement table, stock update helper function, sales summary views, realtime publication.
- `order-sync-metadata-setup.sql`: Customer app, admin app, delivery app aur Supabase order rows aligned rakhne ke liye order metadata fields.
- `README-admin-whatsapp.md`: Admin browser panel aur WhatsApp notification setup instructions.

Admin capabilities intended:

- Admin email OTP sign-in.
- Orders and order items load karna.
- Supabase Realtime changes listen karna.
- Order status update karna.
- New order par browser notification/sound.
- New customer order par admin WhatsApp alert.
- Product stock/availability manage karna.
- Delivery partners add/update/delete karna.
- Today sales summary and product-wise sales view.

## 13. Delivery Partner Support

`delivery-partner-app-setup.sql` delivery partner app ke backend support ko define karta hai:

- `delivery_partners` table.
- Partner profile creation/update.
- Active partner verification.
- Order assignment fields.
- Delivery status fields.
- Unassigned order pool.
- Claimed/assigned orders.
- Delivery partner can update assigned order delivery status.
- Partner can read relevant customer profile and order items.
- Realtime enabled for orders, order items, delivery partners and profiles.

This makes the overall system customer app + admin operations + delivery partner workflow ke liye scalable base provide karta hai.

## 14. WhatsApp Notification Flow

Supabase Edge Function `send-order-whatsapp` customer app ke order completion ke baad admin ko WhatsApp message bhejne ke liye built hai.

Function order payload se message build karta hai:

- Order ID
- Customer name/mobile
- Payment mode
- Total amount
- Items and quantities
- Delivery address

WhatsApp access token, phone number ID aur admin phone Supabase function secrets me rakhe jaate hain. Frontend me service role key ya sensitive token store nahi hota.

Important behavior: Agar WhatsApp notification fail ho jaaye, checkout/order completion block nahi hota. Error console me log hota hai.

## 15. Android App Build

Project Capacitor ke through Android app me wrap kiya gaya hai.

Important files:

- `index.html`: App screens markup.
- `dairy-app.css`: UI styling.
- `script.js`: App behavior and business logic.
- `Supabase.js`: Supabase client connection.
- `manifest.json`: PWA/app metadata.
- `sw.js`: Service worker.
- `images/`: Product, logo, splash and payment assets.
- `android/`: Native Android Capacitor project.
- `scripts/prepare-capacitor.js`: Web assets ko `www/` me copy karta hai.

Build commands:

```powershell
npm run build
npx cap sync android
npx cap open android
```

Android package id:

```text
com.jfam.customer
```

`www/` generated folder hai, ise manually edit nahi karna chahiye. Changes main source files me karne chahiye aur build/sync command run karna chahiye.

## 16. Data Sync Strategy

App local-first behavior use karta hai. Customer data localStorage me immediately save hota hai, phir Supabase ke saath sync kiya jaata hai. User-specific storage scoping implemented hai, jisse login user ke hisaab se cart, wishlist, orders, wallet, addresses aur delivery controls separate rahen.

Realtime sync channels:

- Profile changes.
- Cart changes.
- Wishlist changes.
- Orders changes.
- Order item changes.
- UPI changes.
- Address changes.
- Product catalog changes.

Isse multiple devices ya admin/customer sync cases me app ko fresh state mil sakti hai.

## 17. Support, Privacy And Legal Readiness

App me complete Help & Support, Privacy Policy aur Terms of Use screens included hain.

Support details:

- Phone: +91 72309 20774
- Email: Jfamown@gmail.com
- Support timing: 7:00 AM - 6:00 PM

Help content covers:

- App issues.
- Product quality complaints.
- Order and cart issues.
- Delivery support.
- Payment, wallet and refund help.
- Subscription and pause help.
- Account and profile help.

Privacy and terms sections customer data, orders, payment, wallet, subscriptions, refunds, delivery limitations, account responsibility and legal disclaimers ko explain karte hain.

## 18. Business Benefits

- Manual dairy subscription management ko digital banata hai.
- Customer repeat ordering easy hoti hai.
- Product visibility and upselling improve hota hai.
- Wishlist and featured products customer engagement badhate hain.
- Subscription model recurring revenue support karta hai.
- Admin order management aur inventory tracking ka foundation available hai.
- Delivery partner assignment operational scalability provide karta hai.
- Realtime order sync se team coordination improve hoti hai.
- WhatsApp alert se new order miss hone ka risk kam hota hai.
- Android wrapper se app installable mobile experience ban sakta hai.

## 19. Investor Pitch Angle

JFAM ek hyperlocal dairy commerce platform hai jo daily essential product category ko subscription-first mobile experience me convert karta hai. Dairy ek high-frequency consumption category hai, jahan customers daily ya weekly repeat purchase karte hain. App customer convenience, recurring revenue, delivery operations aur admin control ko ek connected system me combine karta hai.

The product is not just a product listing app. It is built around daily dairy workflows:

- Recurring plans.
- Flexible pause/change controls.
- Saved addresses.
- Wallet adjustments.
- Order history.
- Admin order visibility.
- Delivery partner support.
- Realtime backend.
- WhatsApp order alerts.

Is base par business future me route optimization, subscription analytics, inventory forecasting, customer retention campaigns, referral wallet credits, product bundles aur area-wise expansion add kar sakta hai.

## 20. Current Project Status

Current app ek working customer-facing web/mobile app structure provide karta hai with:

- HTML/CSS/JavaScript frontend.
- Supabase connection.
- Product catalog UI.
- Cart, checkout, payment and wallet logic.
- Profile and saved data management.
- Subscription and delivery control logic.
- Admin/delivery backend SQL setup.
- Capacitor Android wrapper.

Some advanced integrations, jaise live Razorpay functions, final admin panel hosting, production payment verification, inventory UI aur delivery app UI, depend karte hain ki related Supabase functions/tables/secrets/deployments production me fully configured hain ya nahi.

## 21. Simple Explanation For Anyone

JFAM app ek dairy delivery app hai. Customer isme login karta hai, milk/chaach/ghee/dahi/paneer products dekhta hai, quantity aur plan choose karta hai, address save karta hai aur order place karta hai. Agar customer daily milk delivery chahta hai to subscription plan le sakta hai. Agar ek baar ka order chahiye to one-time order kar sakta hai.

App customer ko wishlist, cart, order history, wallet, saved UPI/address, help support aur subscription controls deta hai. Business side par app ka backend admin ko orders dekhne, status update karne, stock manage karne, delivery partner assign karne aur WhatsApp alert receive karne me help kar sakta hai. Isliye yeh sirf customer app nahi, balki dairy business ke complete digital operations ka base hai.
