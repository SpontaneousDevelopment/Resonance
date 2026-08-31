import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'sync_transport.dart';

/// Drains the outbox.
///
/// The outbox has been written-but-never-drained since M3, deliberately — there
/// was no backend to drain it to, and building a consumer against nothing would
/// have been guesswork. The rows written since are real history, which is why
/// they were recorded from the start.
///
/// Ordering is the invariant that matters. Rows carry a monotonic sequence and
/// are sent in it: a mastery promotion that reached the server before the
/// attempt that caused it would be rejected by the server's own validation, and
/// the client would retry it forever.
class SyncEngine {
  SyncEngine({
    required ResonanceDatabase database,
    required this.transport,
    this.batchSize = 50,
  }) : _db = database;

  final ResonanceDatabase _db;
  final SyncTransport transport;
  final int batchSize;

  bool _running = false;

  /// True while a drain is in flight. Overlapping drains would double-send.
  bool get isRunning => _running;

  /// Sends everything queued, oldest first.
  ///
  /// Returns how many rows the server accepted. Safe to call often — it exits
  /// immediately when another drain is already running, when there is nothing
  /// queued, or when the transport says it cannot send.
  Future<int> drain() async {
    if (_running) return 0;
    _running = true;
    try {
      if (!await transport.canSend()) return 0;

      var sent = 0;
      while (true) {
        // Parked rows are excluded by the query, so a permanently rejected
        // row at the head of the queue cannot stop the ones behind it.
        final batch = await _db.pendingSync(limit: batchSize);
        if (batch.isEmpty) break;

        final result = await transport.send(batch);

        if (result.acceptedSeqs.isNotEmpty) {
          await _db.markSent(result.acceptedSeqs);
          sent += result.acceptedSeqs.length;
        }

        if (result.isFailure) {
          final unsent = batch
              .where((row) => !result.acceptedSeqs.contains(row.seq))
              .toList();

          for (final row in unsent) {
            await _db.markFailed(row.seq, result.error!);
            if (!result.retryable) {
              // A row the server will never accept blocks everything behind it
              // forever. Park it and keep going.
              await _db.markParked(row.seq, result.error!);
              debugPrint(
                'Sync: parking row ${row.seq} (${row.entityType}) — '
                '${result.error}',
              );
            }
          }
          // Stop on a retryable failure: the next rows are almost certainly
          // going to fail the same way, and hammering a struggling server is
          // not a retry strategy.
          if (result.retryable) break;
        }

        // A batch where nothing was accepted and nothing was poisoned would
        // loop forever.
        if (result.acceptedSeqs.isEmpty && result.retryable) break;
      }
      return sent;
    } finally {
      _running = false;
    }
  }

  /// Rows parked as permanently unsendable. Surfaced so they are visible in
  /// diagnostics rather than quietly accumulating.
  Future<List<OutboxRow>> parkedRows() async =>
      (await _db.allOutboxRows()).where((row) => row.parked).toList();
}

final syncTransportProvider = Provider<SyncTransport>(
  (ref) => const OfflineTransport(),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    database: ref.watch(databaseProvider),
    transport: ref.watch(syncTransportProvider),
  ),
);
