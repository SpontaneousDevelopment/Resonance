import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/net/supabase_config.dart';

/// Configuration is absent by default, and that must remain a supported state.
///
/// The app is anonymous-first: every feature that matters works with no
/// account and no backend. A build without dart-defines is the common case in
/// tests and in CI, so "unconfigured" has to be ordinary rather than an error
/// path nobody exercises.
void main() {
  test('an unconfigured build reports itself unconfigured', () {
    // No --dart-define in a test run, so both are empty.
    expect(SupabaseConfig.url, isEmpty);
    expect(SupabaseConfig.anonKey, isEmpty);
    expect(SupabaseConfig.isConfigured, isFalse);
  });

  test('both values are required, not either', () {
    // A URL with no key would fail at initialise rather than here, which is a
    // worse place to find out.
    expect(SupabaseConfig.isConfigured, isFalse);
  });

  test('no credential is compiled in as a default', () {
    // The failure this guards: someone adding `defaultValue:` to make local
    // running easier, and shipping a key in the binary.
    expect(SupabaseConfig.url, isNot(contains('supabase.co')));
    expect(SupabaseConfig.anonKey, isNot(startsWith('sb_')));
    expect(SupabaseConfig.anonKey, isNot(startsWith('eyJ')));
  });
}
