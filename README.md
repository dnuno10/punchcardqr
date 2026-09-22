# PunchCardQR

Digital punch cards with no customer app and no customer account.
Owner: Flutter Web dashboard (Supabase Auth). Customer: a private card URL `/c/{token}`.

## Layout
- `lib/` Flutter app (feature-first). Public routes `/j/:slug`, `/c/:token`, `/recover`; owner routes behind login.
- `supabase/migrations/` schema, RLS, transactional functions, stats, cron.
- `supabase/functions/` Edge Functions for Stripe checkout, portal, and webhooks only. App data flows use PostgREST RPC.

## Deploy
```
supabase link --project-ref <ref>
supabase db push
supabase functions deploy create-checkout-session create-customer-portal stripe-webhook
supabase secrets set APP_URL=https://punchcardqr.com \
  STRIPE_SECRET_KEY=... STRIPE_WEBHOOK_SECRET=...
```
Plan price/product IDs are hardcoded in `supabase/functions/_shared/stripe.ts` (`PRICE_BY_PLAN` /
`PRODUCT_BY_PLAN`) — they're stable identifiers, not secrets, so no env var is needed for them.
Stripe webhook endpoint: `https://<ref>.functions.supabase.co/stripe-webhook`
(events: checkout.session.completed, customer.subscription.created/updated/deleted).

## Run / build
Supabase URL and anon key are hardcoded in `lib/core/config/env.dart` (the anon key is meant
to be public; RLS is what protects the data), so no `--dart-define` is needed for them.
```
flutter run -d chrome
flutter build web --dart-define=APP_URL=https://punchcardqr.com
```
Host `build/web` with an SPA fallback to `index.html` (`web/_redirects` covers Netlify / Cloudflare Pages).

## Security model
- Customers never touch tables directly: public screens call SECURITY DEFINER RPC wrappers that hash/verify card tokens and delegate to transactional Postgres functions.
- The QR a customer shows is a 60-second HMAC code, not the card URL, so a photographed QR expires.
- Every balance change is a `loyalty_events` row written inside one locked transaction; retries are idempotent.
# punchcardqr
