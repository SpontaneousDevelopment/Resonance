import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/sync/sync_engine.dart';
import 'package:resonance/core/sync/sync_transport.dart';

/// A transport that records what it was asked to send.
class FakeTransport implements SyncTransport {
  FakeTransport({this.available = true});

  bool available;
  final List<List<int>> batches = [];

  /// Set to fail the next send.
  SendResult? nextResult;

  @override
  Future<bool> canSend() async => available;

  @override
  Future<SendResult> send(List<OutboxRow> rows) async {
    batches.add(rows.map((r) => r.seq).toList());
    final planned = nextResult;
    if (planned != null) {
      nextResult = null;
      return planned;
    }
    return SendResult.success(rows.map((r) => r.seq).toList());
  }

  List<int> get allSent => [for (final b in batches) ...b];
}

void main() {
  late ResonanceDatabase db;
  late FakeTransport transport;
  late SyncEngine engine;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    transport = FakeTransport();
    engine = SyncEngine(database: db, transport: transport, batchSize: 3);
  });

  tearDown(() async => db.close());

  Future<void> queue(int count, {String type = 'attempt'}) async {
    for (var i = 0; i < count; i++) {
      await db.enqueue(
        entityType: type,
        entityId: '$type-$i',
        payload: '{"i":$i}',
        at: DateTime(2026, 9, 1).add(Duration(minutes: i)),
      );
    }
  }

  group('draining', () {
    test('sends everything queued and clears it', () async {
      await queue(5);

      expect(await engine.drain(), 5);
      expect(await db.pendingSync(), isEmpty);
    });

    test('sends oldest first, in sequence order', () async {
      // The invariant the whole outbox exists for: a promotion must never
      // reach the server before the attempt that caused it.
      await queue(7);

      await engine.drain();

      final sent = transport.allSent;
      expect(sent, List.generate(7, (i) => sent.first + i));
      for (var i = 1; i < sent.length; i++) {
        expect(sent[i], greaterThan(sent[i - 1]));
      }
    });

    test('respects the batch size', () async {
      await queue(7);
      await engine.drain();

      expect(transport.batches.map((b) => b.length), [3, 3, 1]);
    });

    test('does nothing when the transport cannot send', () async {
      // The state the app has been in since M3 — queueing with nowhere to go.
      transport.available = false;
      await queue(4);

      expect(await engine.drain(), 0);
      expect(await db.pendingSync(), hasLength(4));
      expect(transport.batches, isEmpty);
    });

    test('an empty outbox is a no-op', () async {
      expect(await engine.drain(), 0);
      expect(transport.batches, isEmpty);
    });
  });

  group('failure', () {
    test('a retryable failure leaves rows queued', () async {
      await queue(4);
      transport.nextResult = const SendResult.failure('HTTP 503');

      expect(await engine.drain(), 0);
      expect(await db.pendingSync(), hasLength(4));
    });

    test('and records the error rather than losing it', () async {
      await queue(2);
      transport.nextResult = const SendResult.failure('HTTP 503');
      await engine.drain();

      final row = (await db.pendingSync()).first;
      expect(row.lastError, 'HTTP 503');
    });

    test('stops after a retryable failure rather than hammering', () async {
      // Nine rows, batch of three. A failing server should see one attempt,
      // not three.
      await queue(9);
      transport.nextResult = const SendResult.failure('HTTP 503');

      await engine.drain();

      expect(transport.batches, hasLength(1));
    });

    test('a partial success keeps only what was not accepted', () async {
      await queue(3);
      final pending = await db.pendingSync();
      transport.nextResult = SendResult(
        acceptedSeqs: [pending.first.seq],
        error: 'one row rejected',
      );

      await engine.drain();

      final left = await db.pendingSync();
      expect(left, hasLength(2));
      expect(left.map((r) => r.seq), isNot(contains(pending.first.seq)));
    });

    test('a permanently rejected row is parked, not retried forever', () async {
      // A payload the server will never accept blocks everything behind it.
      await queue(4);
      transport.nextResult = const SendResult.failure(
        'malformed payload',
        retryable: false,
      );

      await engine.drain();

      expect(await engine.parkedRows(), isNotEmpty);
      // Parked, not deleted — a payload bug should stay diagnosable. Checked
      // against every row, since pendingSync now excludes parked ones by
      // design; that exclusion is what stops them blocking the queue.
      expect(await db.allOutboxRows(), isNotEmpty);
      expect(await db.pendingSync(), isEmpty);
    });

    test('parked rows do not block the ones behind them', () async {
      await queue(3);
      transport.nextResult = const SendResult.failure(
        'malformed',
        retryable: false,
      );
      await engine.drain();
      final parked = (await engine.parkedRows()).length;

      // New rows queued after the bad ones still go.
      await queue(2, type: 'streak');
      final sent = await engine.drain();

      expect(parked, greaterThan(0));
      expect(sent, 2);
    });
  });

  group('concurrency', () {
    test('overlapping drains do not double-send', () async {
      await queue(6);

      final results = await Future.wait([engine.drain(), engine.drain()]);

      // One drain does the work; the other exits immediately.
      expect(results.where((n) => n > 0), hasLength(1));
      expect(transport.allSent.toSet().length, transport.allSent.length);
    });

    test('a second drain after the first completes works normally', () async {
      await queue(2);
      await engine.drain();
      expect(engine.isRunning, isFalse);

      await queue(2, type: 'streak');
      expect(await engine.drain(), 2);
    });
  });

  group('the offline default', () {
    test(
      'never sends, so the outbox accumulates rather than erroring',
      () async {
        final offline = SyncEngine(
          database: db,
          transport: const OfflineTransport(),
        );
        await queue(3);

        expect(await offline.drain(), 0);
        expect(await db.pendingSync(), hasLength(3));
      },
    );
  });
}
