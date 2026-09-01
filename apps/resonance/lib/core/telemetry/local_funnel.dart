import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../net/supabase_bootstrap.dart';

/// Counts the one product signal worth having before there are users — on the
/// device, and nowhere else.
///
/// Sign-in is the moment someone chooses a deeper level of investment, so it is
/// the real conversion event and worth knowing how long people take to reach.
/// What it is *not* worth is standing up a second data processor for zero
/// current users, so this writes two dates to local storage and stops.
///
/// Nothing here is transmitted. It is not wired to the crash reporter, it has
/// no server table, and it is not part of sync. When product analytics ships
/// post-MVP it can read these; until then they are a local answer to a local
/// question.
class LocalFunnel {
  const LocalFunnel(this._prefs);

  final Future<SharedPreferences> Function() _prefs;

  static const _firstLaunchKey = 'funnel_first_launch';
  static const _firstSignInKey = 'funnel_first_sign_in';

  /// Stamped once, ever. Later launches leave the original date alone.
  Future<void> recordFirstLaunch() async {
    final prefs = await _prefs();
    if (prefs.getString(_firstLaunchKey) != null) return;
    await prefs.setString(
      _firstLaunchKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Stamped on the first successful sign-in only. A later sign-in on the same
  /// device is a return, not a conversion.
  Future<void> recordSignIn() async {
    final prefs = await _prefs();
    if (prefs.getString(_firstSignInKey) != null) return;
    await prefs.setString(
      _firstSignInKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<FunnelSnapshot> read() async {
    final prefs = await _prefs();
    DateTime? parse(String key) {
      final raw = prefs.getString(key);
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return FunnelSnapshot(
      firstLaunch: parse(_firstLaunchKey),
      firstSignIn: parse(_firstSignInKey),
    );
  }
}

class FunnelSnapshot {
  const FunnelSnapshot({this.firstLaunch, this.firstSignIn});

  final DateTime? firstLaunch;
  final DateTime? firstSignIn;

  /// How long someone took to decide, or null if they have not.
  Duration? get timeToConvert => (firstLaunch == null || firstSignIn == null)
      ? null
      : firstSignIn!.difference(firstLaunch!);
}

/// Watches for the conversion and writes it down.
///
/// Separate from [LocalFunnel] so the *connection* can be tested. The recorder
/// is the part that can silently stop being called, which is the failure this
/// project keeps finding.
class FunnelRecorder {
  FunnelRecorder({required this.funnel, required this.authChanges});

  final LocalFunnel funnel;
  final Stream<AuthState> authChanges;

  StreamSubscription<AuthState>? _subscription;

  void start() {
    if (_subscription != null) return;
    unawaited(funnel.recordFirstLaunch());
    _subscription = authChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        unawaited(funnel.recordSignIn());
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final localFunnelProvider = Provider<LocalFunnel>(
  (ref) => LocalFunnel(SharedPreferences.getInstance),
);

/// Null with no backend configured — there is no sign-in to convert to.
final funnelRecorderProvider = Provider<FunnelRecorder?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final recorder = FunnelRecorder(
    funnel: ref.watch(localFunnelProvider),
    authChanges: client.auth.onAuthStateChange,
  );
  recorder.start();
  ref.onDispose(recorder.dispose);
  return recorder;
});
