import '../db/database.dart';

/// The result of trying to send one batch.
class SendResult {
  const SendResult({
    required this.acceptedSeqs,
    this.retryable = true,
    this.error,
  });

  /// Rows the server took. Anything absent stays queued.
  final List<int> acceptedSeqs;

  /// Whether a failure is worth retrying. A 500 is; a malformed payload the
  /// server will never accept is not, and retrying it forever would block
  /// every row behind it.
  final bool retryable;

  final String? error;

  bool get isFailure => error != null;

  const SendResult.success(List<int> seqs) : this(acceptedSeqs: seqs);

  const SendResult.failure(String message, {bool retryable = true})
    : this(acceptedSeqs: const [], retryable: retryable, error: message);
}

/// Where outbox rows go.
///
/// An interface because there is no Supabase project to test against yet — the
/// draining logic is the part with the interesting failure modes, and it is
/// fully exercised against a fake. The real transport is a thin adapter.
abstract interface class SyncTransport {
  /// Whether sending is possible right now — signed in, and the connection is
  /// one the user has allowed.
  Future<bool> canSend();

  Future<SendResult> send(List<OutboxRow> rows);
}

/// Never sends. The default until an account exists, so the outbox accumulates
/// rather than erroring.
class OfflineTransport implements SyncTransport {
  const OfflineTransport();

  @override
  Future<bool> canSend() async => false;

  @override
  Future<SendResult> send(List<OutboxRow> rows) async =>
      const SendResult.failure('not signed in');
}
