import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_recogniser.dart';

/// [SpeechRecogniser] backed by the OS recogniser — `SFSpeechRecognizer` on
/// Apple platforms, `SpeechRecognizer` on Android.
///
/// Chosen over bundling Whisper for the MVP because the task here is *alignment
/// against a known script*, not open transcription. That is a much easier
/// problem, platform recognisers are good enough at it, and it saves a 150&nbsp;MB
/// post-install model download. Whisper returns when accent drills need
/// per-phoneme timing.
class PlatformSpeechRecogniser implements SpeechRecogniser {
  PlatformSpeechRecogniser({stt.SpeechToText? engine})
    : _engine = engine ?? stt.SpeechToText();

  final stt.SpeechToText _engine;
  final _controller = StreamController<Transcript>.broadcast();

  bool _initialised = false;
  Transcript _latest = const Transcript.empty();
  Completer<Transcript>? _finished;

  @override
  Future<bool> isAvailable() async {
    if (_initialised) return _engine.isAvailable;
    _initialised = await _engine.initialize(
      onError: _onError,
      onStatus: _onStatus,
      debugLogging: false,
    );
    return _initialised;
  }

  @override
  Future<void> start({String? localeId, String? contextHint}) async {
    if (!await isAvailable()) {
      throw const SpeechUnavailable(
        SpeechUnavailableReason.noRecogniserOnDevice,
      );
    }

    _latest = const Transcript.empty();
    _finished = Completer<Transcript>();

    await _engine.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        // Partial results drive the live "we can hear you" affordance. Without
        // them a long read looks like nothing is happening.
        partialResults: true,
        // Keep listening through the pauses that punctuation creates. The
        // default cuts off at the first breath, which would truncate every
        // read at the first comma.
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        // Long enough for an audiobook paragraph; the caller stops it
        // explicitly rather than relying on the timeout.
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
      ),
    );
  }

  void _onResult(dynamic result) {
    final alternates = result.alternates as List<dynamic>?;
    final confidence = (alternates != null && alternates.isNotEmpty)
        ? (alternates.first.confidence as double?)
        : null;

    _latest = Transcript(
      text: result.recognizedWords as String? ?? '',
      // Platform confidence is reported as 0 when the platform declines to
      // estimate. Treating that as "completely unintelligible" would wrongly
      // tank an otherwise clean read, so it becomes null instead.
      meanConfidence: (confidence == null || confidence <= 0)
          ? null
          : confidence,
      isFinal: result.finalResult as bool? ?? false,
    );
    _controller.add(_latest);

    if (_latest.isFinal && !(_finished?.isCompleted ?? true)) {
      _finished?.complete(_latest);
    }
  }

  void _onError(dynamic error) {
    final message = error.errorMsg as String? ?? '';
    final reason = switch (message) {
      final m when m.contains('permission') =>
        SpeechUnavailableReason.permissionDenied,
      final m when m.contains('network') => SpeechUnavailableReason.offline,
      _ => SpeechUnavailableReason.unknown,
    };
    _controller.addError(SpeechUnavailable(reason, message));
  }

  void _onStatus(String status) {
    if (status == 'done' && !(_finished?.isCompleted ?? true)) {
      _finished?.complete(_latest);
    }
  }

  @override
  Stream<Transcript> get results => _controller.stream;

  @override
  Future<Transcript> stop() async {
    await _engine.stop();

    // Give the platform a moment to deliver its final result, but never hang
    // the feedback screen on it — a transcript we did not get is a clarity
    // score we cannot give, not a reason to block the whole attempt.
    final finished = _finished;
    if (finished != null && !finished.isCompleted) {
      await finished.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => _latest,
      );
    }
    return _latest;
  }

  @override
  Future<void> cancel() async {
    await _engine.cancel();
    _latest = const Transcript.empty();
  }

  @override
  Future<void> dispose() async {
    await _engine.cancel();
    await _controller.close();
  }
}
