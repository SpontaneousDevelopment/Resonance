import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../net/supabase_bootstrap.dart';
import 'sync_engine.dart';

/// Decides *when* the outbox drains.
///
/// The engine knows how to drain and the transport knows how to send, but
/// until this existed nothing in the running app ever called `drain()` — both
/// were reachable only from their own tests. That is the same shape as the
/// lesson route that was wired to nothing and passed every test it had, so the
/// triggers get their own tests here rather than being assumed.
///
/// Three moments, each for a different reason:
///
/// * **Reconnecting.** The offline-first promise is that practice done on a
///   train reaches the server without the user thinking about it.
/// * **Signing in.** The queue can be months old by then — everything recorded
///   before there was an account to send it to.
/// * **Finishing an attempt.** Otherwise a session synced only on the next
///   launch, and someone who practises daily on one device would always be a
///   day behind on another.
class SyncScheduler {
  SyncScheduler({
    required this.engine,
    required this.connectivityChanges,
    required this.authChanges,
  });

  final SyncEngine engine;
  final Stream<List<ConnectivityResult>> connectivityChanges;
  final Stream<AuthState> authChanges;

  final List<StreamSubscription<void>> _subscriptions = [];
  bool _started = false;

  /// Begins listening, and drains once for anything left from last time.
  void start() {
    if (_started) return;
    _started = true;

    _subscriptions.add(
      connectivityChanges.listen((results) {
        // Only on the way back up. Draining on the transition *to* offline
        // would just queue a doomed request behind the ones already waiting.
        if (results.any((r) => r != ConnectivityResult.none)) nudge();
      }),
    );
    _subscriptions.add(authChanges.listen((_) => nudge()));

    nudge();
  }

  /// Asks for a drain. Cheap and safe to call repeatedly — the engine exits
  /// immediately when one is already running or the transport cannot send.
  void nudge() {
    unawaited(
      engine.drain().catchError((Object error) {
        // A failed sync must never surface to someone mid-practice. The rows
        // stay queued and the next trigger tries again.
        debugPrint('sync drain failed, rows remain queued: $error');
        return 0;
      }),
    );
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

/// Null when there is no backend, which is the anonymous-first default. That
/// also keeps the connectivity plugin untouched in local-only builds.
final syncSchedulerProvider = Provider<SyncScheduler?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final scheduler = SyncScheduler(
    engine: ref.watch(syncEngineProvider),
    connectivityChanges: Connectivity().onConnectivityChanged,
    authChanges: client.auth.onAuthStateChange,
  );
  scheduler.start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
