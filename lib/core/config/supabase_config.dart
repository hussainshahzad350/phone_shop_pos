/// Supabase connection settings used only for the email PIN-recovery flow.
///
/// The publishable (anon) key is public by design and safe to ship in the
/// client; it is gated server-side by Supabase. Values can be overridden at
/// build time via `--dart-define`, falling back to the project defaults so the
/// app works out of the box.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pkqrfebrbyuepjuovlkw.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_WVO0kDhNwEGGuqqAnZ4kEA_VAhx_ufD',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
