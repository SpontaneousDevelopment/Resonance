/// How the app finds its backend.
///
/// Values come from `--dart-define`, never from a bundled `.env`. An asset is
/// readable by anyone who unzips the app, and while the publishable key is
/// client-safe by design, shipping a habit of "secrets live in an asset" is how
/// a genuinely secret one eventually ends up there too.
///
/// Unset is a supported state, not a failure. The app is anonymous-first: with
/// no backend configured it works exactly as it has all along — local
/// persistence, no account, the outbox accumulating against the day there is
/// somewhere to send it.
library;

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether a backend is available at all.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Run with local values:
  ///   fvm flutter run -d macos \
  ///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  ///
  /// `tools/dart_defines.sh` turns the repo's .env into exactly those flags.
  static const setupHint =
      'Pass --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY, '
      'or run scripts/run_with_env.sh';
}
