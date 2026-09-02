import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database.dart';
import '../progress/audio_store.dart';
import '../net/supabase_bootstrap.dart';

/// Account actions. Every one of them is optional.
///
/// Being signed out gates nothing — the app is anonymous-first and every
/// feature works without an account. Signing in adds sync; it does not unlock
/// anything that was previously withheld.
class AccountService {
  const AccountService({
    required this.client,
    required this.database,
    required this.audio,
  });

  /// Null when no backend is configured. All methods no-op rather than throw,
  /// so an unconfigured build behaves exactly as it always has.
  final SupabaseClient? client;
  final ResonanceDatabase database;

  /// The recordings on disk. Rows and files are separate deletions, and the
  /// files were the half nobody was doing.
  final AudioStore audio;

  bool get isAvailable => client != null;
  User? get currentUser => client?.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  /// Sends a magic link.
  ///
  /// Passwordless deliberately: a password is one more thing to lose, one more
  /// thing to reuse, and one more thing this app would be responsible for
  /// storing. Nothing here is worth that.
  Future<void> sendMagicLink(String email) async {
    final auth = client?.auth;
    if (auth == null) throw const AccountUnavailable();
    await auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'app.resonance://login-callback',
    );
  }

  Future<void> signOut() async {
    // Local progress is untouched. Signing out is not a deletion, and a user
    // who signs out on a shared device should still find their practice when
    // they come back.
    await client?.auth.signOut();
  }

  /// Deletes everything, everywhere, and the account itself.
  ///
  /// Server first. If the local wipe went first and the server call then
  /// failed, the user would be left signed into an account holding data they
  /// had been told was gone, with no local copy to retry from.
  Future<void> deleteEverything() async {
    final auth = client?.auth;
    if (auth != null && auth.currentUser != null) {
      final response = await client!.functions.invoke('delete-account');
      if (response.status != 200) {
        throw AccountDeletionFailed(
          'The server could not complete the deletion '
          '(${response.status}). Nothing has been removed.',
        );
      }
      await auth.signOut();
    }

    // Files before rows: the rows are what say where the files are. Wiping the
    // database first would leave every recording on disk with nothing left
    // pointing at it — undeletable by the app, and still there.
    await audio.deleteAll();
    await database.deleteAllUserData();
  }
}

class AccountUnavailable implements Exception {
  const AccountUnavailable();
  @override
  String toString() => 'No account backend is configured.';
}

class AccountDeletionFailed implements Exception {
  const AccountDeletionFailed(this.message);
  final String message;
  @override
  String toString() => message;
}

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(databaseProvider),
    audio: ref.watch(audioStoreProvider),
  ),
);

/// Rebuilds when auth changes, so the settings screen follows a magic-link
/// callback arriving while it is open.
final authStateProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange;
});
