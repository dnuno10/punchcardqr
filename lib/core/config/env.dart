/// Supabase URL and anon key are not secrets — the anon key is designed to be public
/// (RLS policies, not secrecy, protect the data), so both are hardcoded here rather than
/// passed via --dart-define.
class Env {
  static const supabaseUrl = 'https://xcprpmzesfoirchafpjh.supabase.co';

  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhjcHJwbXplc2ZvaXJjaGFmcGpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMjM2ODcsImV4cCI6MjEwNTU5OTY4N30.dd9zJ0_OPVWrD376QjAlCwT034z8r89kNpqvv_ir7p8';

  static const appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://app.punchcardqr.com',
  );
  static const turnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

  /// Publishable key is safe to embed client-side (by design, Stripe's own docs say so).
  /// Checkout itself is server-created (create-checkout-session Edge Function) and hosted
  /// by Stripe, so this is currently unused but kept available for Payment Element / Apple Pay
  /// domain verification if needed later.
  static const stripePublishableKey =
      'pk_live_51UBeiN3kPVs6fjFLFG1nkTgwDEgRYCXSjz5QkijdeMoMfJZb40bavIGpXCQfg9aDIizkykna8yD2rVbiOPDcSTYn009Yv9lSbj';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
