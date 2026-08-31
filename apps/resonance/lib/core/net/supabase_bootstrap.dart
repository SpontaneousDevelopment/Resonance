import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Brings Supabase up, if it is configured at all.
///
/// Returns false when there is no backend, which is a normal state rather than
/// an error — the app is anonymous-first and every feature that matters works
/// without an account. Sign-in is additive.
Future<bool> initialiseSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    debugPrint(
      'Supabase not configured — running local-only. '
      '${SupabaseConfig.setupHint}',
    );
    return false;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // The SDK renamed this: `anonKey` is deprecated in favour of
      // `publishableKey`, which settles the earlier ambiguity — the
      // sb_publishable_ value *is* the anon key's replacement. The env var
      // keeps its name because .env.example declares it.
      publishableKey: SupabaseConfig.anonKey,
      // The device is the source of truth; realtime would be pushing changes
      // the app does not act on.
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 1),
    );
    return true;
  } catch (error) {
    // A backend that will not start must not stop the app. Practising is the
    // product; syncing it is an enhancement.
    debugPrint('Supabase failed to initialise, continuing local-only: $error');
    return false;
  }
}

/// The client, or null when running without a backend.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Whether someone is signed in. False throughout the anonymous-first path.
final isSignedInProvider = Provider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.currentUser != null;
});
