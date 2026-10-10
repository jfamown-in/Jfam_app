# UAT plan

| ID | Workflow | Preconditions | Steps | Expected result | Backend proof |
| --- | --- | --- | --- | --- | --- |
| UAT-001 | Web startup/catalog | Built bundle, browser | Open app; open Products | Catalog and images render, no broken controls | No write request |
| UAT-002 | OTP login | Synthetic test account | Request/verify OTP | Session and own profile only | Auth session + profiles RLS |
| UAT-003 | Cart/address | Logged-in synthetic account | Add/update cart and address; refresh | Own data persists | User-scoped row assertions |
| UAT-004 | Cross-user isolation | Two test accounts | Try direct API reads/mutations for other user | Denied | pgTAP/API denial evidence |
| UAT-005 | Checkout idempotency | Test catalog/address + local DB | Submit same idempotency key twice | One order, one wallet debit | Transaction assertions |
| UAT-006 | Payment verification | Razorpay test mode | Send valid/invalid/replayed webhook | Only valid signed event confirms order | Payment attempt/status assertions |
| UAT-007 | Wallet concurrency | Test wallet | Two simultaneous debits | Never negative; one/both correct denial | Ledger + balance assertions |
| UAT-008 | Delivery privacy | Admin + partner + customers | Partner reads assigned/unassigned data | Only assigned data readable | RLS denial tests |
| UAT-009 | Android recovery | Debug app/emulator | Start UPI; background/restart | Pending state resumes from server | Payment attempt read |

Statuses remain Not Run/Blocked until a disposable Supabase test environment and synthetic accounts exist.
