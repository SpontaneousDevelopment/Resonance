import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/sync/sync_engine.dart';
import 'package:resonance/core/sync/sync_scheduler.dart';
import 'package:resonance/core/sync/sync_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records what it was asked to send, so the assertions below are about rows
/// actually leaving the device rather than about a method having been called.
class CountingTransport implements SyncTransport {
  final List<List<int>> batches = [];

  @override
  Future<bool> canSend() async => true;

  @override
  Future<SendResult> send(List<OutboxRow> rows) async {
    batches.add(rows.map((r) => r.seq).toList());
    return SendResult.success(rows.map((r) => r.seq).toList());
  }
}

void main() {
  late ResonanceDatabase db;
  late CountingTransport transport;
  late SyncEngine engine;
  late StreamController<List<ConnectivityResult>> connectivity;
  late StreamController<AuthState> auth;
  late SyncScheduler scheduler;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    transport = CountingTransport();
    engine = SyncEngine(database: db, transport: transport);
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    auth = StreamController<AuthState>.broadcast();
    scheduler = SyncScheduler(
      engine: engine,
      connectivityChanges: connectivity.stream,
      authChanges: auth.stream,
    );
  });

  tearDown(() async {
    scheduler.dispose();
    await connectivity.close();
    await auth.close();
    await db.close();
  });

  Future<void> queueOne(String id) => db.enqueue(
    entityType: 'attempt',
    entityId: id,
    payload: '{"lesson_id":"plosive-1"}',
    at: DateTime(2026, 9, 1),
  );

  /// Lets the unawaited drain inside `nudge` finish before asserting.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starting drains what was queued while there was no backend', () async {
    await queueOne('a');

    scheduler.start();
    await settle();

    expect(transport.batches, isNotEmpty, reason: 'the queue never went out');
    expect(await db.pendingSync(limit: 10), isEmpty);
  });

  test('reconnecting sends what was recorded offline', () async {
    scheduler.start();
    await settle();
    transport.batches.clear();

    // Recorded on a train, with nothing to send it to.
    await queueOne('offline-attempt');
    expect(transport.batches, isEmpty, reason: 'nothing should have sent yet');

    connectivity.add([ConnectivityResult.wifi]);
    await settle();

    expect(transport.batches, hasLength(1));
    expect(await db.pendingSync(limit: 10), isEmpty);
  });

  test('losing the connection does not trigger a doomed send', () async {
    scheduler.start();
    await settle();
    transport.batches.clear();

    await queueOne('b');
    connectivity.add([ConnectivityResult.none]);
    await settle();

    expect(transport.batches, isEmpty);
    // Still queued, waiting for a real reconnection.
    expect(await db.pendingSync(limit: 10), hasLength(1));
  });

  test(
    'signing in sends the history recorded before the account existed',
    () async {
      scheduler.start();
      await settle();
      transport.batches.clear();

      await queueOne('months-of-practice');

      auth.add(AuthState(AuthChangeEvent.signedIn, null));
      await settle();

      expect(transport.batches, hasLength(1));
    },
  );

  test(
    'finishing an attempt sends it without waiting for a relaunch',
    () async {
      scheduler.start();
      await settle();
      transport.batches.clear();

      await queueOne('just-practised');
      scheduler.nudge();
      await settle();

      expect(transport.batches, hasLength(1));
    },
  );

  test('disposing actually stops it listening', () async {
    scheduler.start();
    await settle();
    transport.batches.clear();

    scheduler.dispose();
    await queueOne('c');
    connectivity.add([ConnectivityResult.wifi]);
    await settle();

    expect(
      transport.batches,
      isEmpty,
      reason: 'a disposed scheduler kept draining',
    );
  });
}
