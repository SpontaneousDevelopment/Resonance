import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database.dart';
import '../net/supabase_bootstrap.dart';
import 'sync_settings.dart';
import 'sync_transport.dart';

/// Sends outbox rows to Supabase.
///
/// Rows are upserted on the client's own primary keys, which makes the push
/// idempotent: a retry after a timeout that actually succeeded writes the same
/// row rather than a duplicate. That matters because the client cannot tell a
/// lost response from a lost request.
class SupabaseTransport implements SyncTransport {
  SupabaseTransport({
    required this.client,
    required this.settings,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final SupabaseClient client;
  final SyncSettings settings;
  final Connectivity _connectivity;

  @override
  Future<bool> canSend() async {
    if (client.auth.currentUser == null) return false;

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    final onlyCellular =
        results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);

    // Progress data only — see SyncSettings. Audio must never inherit this.
    if (onlyCellular && !settings.syncOnCellular) return false;

    return true;
  }

  @override
  Future<SendResult> send(List<OutboxRow> rows) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const SendResult.failure('signed out', retryable: false);
    }

    final accepted = <int>[];
    for (final row in rows) {
      try {
        await _sendOne(row, userId);
        accepted.add(row.seq);
      } on PostgrestException catch (error) {
        // 22xxx and 23xxx are data and constraint errors: the payload is wrong
        // and will be wrong forever. Retrying blocks everything behind it.
        final permanent =
            error.code != null &&
            (error.code!.startsWith('22') || error.code!.startsWith('23'));
        return SendResult(
          acceptedSeqs: accepted,
          retryable: !permanent,
          error: '${error.code}: ${error.message}',
        );
      } catch (error) {
        return SendResult(acceptedSeqs: accepted, error: '$error');
      }
    }
    return SendResult.success(accepted);
  }

  Future<void> _sendOne(OutboxRow row, String userId) async {
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;

    switch (row.entityType) {
      case 'attempt':
        // Two tables from one row: the attempt itself, and the mastery it
        // moved. They were written in one local transaction and belong
        // together here too.
        await client
            .from('attempts')
            .upsert(
              {
                'id': row.entityId,
                'user_id': userId,
                'lesson_id': payload['lesson_id'],
                'recorded_at': payload['recorded_at'],
                'duration_ms': payload['duration_ms'] ?? 0,
                'score': payload['score'],
                // `ignoreDuplicates` rather than a merge. An attempt is immutable —
                // the table has no UPDATE policy on purpose — so a merging upsert is
                // refused with 403 on every retry, which live verification caught.
                // Ignoring is also the right semantics: a resend means the first
                // request landed, not that the record changed.
              },
              onConflict: 'user_id,id',
              ignoreDuplicates: true,
            );

        if (payload['mastery_rank'] != null && payload['unit_id'] != null) {
          await client.from('lesson_progress').upsert({
            'user_id': userId,
            'lesson_id': payload['lesson_id'],
            'unit_id': payload['unit_id'],
            'mastery_rank': payload['mastery_rank'],
          }, onConflict: 'user_id,lesson_id');
        }

      case 'lesson_progress':
        await client.from('lesson_progress').upsert({
          'user_id': userId,
          ...payload,
        }, onConflict: 'user_id,lesson_id');

      case 'streak':
        await client.from('streak_state').upsert({
          'user_id': userId,
          ...payload,
        }, onConflict: 'user_id');

      default:
        // An unknown type is a client bug, not a server one. Failing it
        // permanently parks it rather than retrying forever.
        throw PostgrestException(
          message: 'unknown outbox entity type "${row.entityType}"',
          code: '22000',
        );
    }
  }
}

/// The live transport when signed in, the offline one otherwise.
final liveSyncTransportProvider = Provider<SyncTransport>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const OfflineTransport();

  return SupabaseTransport(
    client: client,
    settings: ref.watch(syncSettingsProvider),
  );
});
