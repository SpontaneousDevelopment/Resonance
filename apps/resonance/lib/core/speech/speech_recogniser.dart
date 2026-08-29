/// Speech recognition, behind an interface.
///
/// The interface exists because of a real unknown: the recogniser and the
/// recorder both want the microphone. On Apple platforms `speech_to_text` drives
/// `SFSpeechRecognizer` off its own `AVAudioEngine`, while `record` opens its
/// own capture — whether two clients can tap the same input device at once is
/// platform- and version-dependent, and cannot be settled without a live mic.
///
/// So the scoring pipeline is written against this interface and tested against
/// [FakeSpeechRecogniser]. If live capture turns out to contend, the fix is a
/// new implementation of this one class — transcribing the finished file rather
/// than listening live — and nothing downstream changes.
library;

import 'dart:async';

/// What the recogniser heard.
class Transcript {
  const Transcript({
    required this.text,
    this.wordConfidences = const [],
    this.meanConfidence,
    this.isFinal = true,
  });

  const Transcript.empty()
    : text = '',
      wordConfidences = const [],
      meanConfidence = null,
      isFinal = true;

  final String text;

  /// Per-word confidence, where the platform reports it. Often empty — Android
  /// gives a single utterance-level figure and iOS varies by OS version, so
  /// nothing downstream may depend on this being populated.
  final List<double> wordConfidences;

  /// Utterance-level confidence, 0..1, or null when unavailable.
  final double? meanConfidence;

  /// False for interim results during live recognition.
  final bool isFinal;

  bool get isEmpty => text.trim().isEmpty;
}

/// Why recognition could not run. Surfaced to the user, so the copy matters.
enum SpeechUnavailableReason {
  permissionDenied,
  noRecogniserOnDevice,

  /// The recogniser needs the network and there isn't any. On-device
  /// recognition is available on newer iOS and some Android builds, but not
  /// universally — so an offline lesson must degrade rather than fail.
  offline,

  unknown,
}

class SpeechUnavailable implements Exception {
  const SpeechUnavailable(this.reason, [this.detail]);

  final SpeechUnavailableReason reason;
  final String? detail;

  /// What the user is told. Never a raw platform error.
  String get message => switch (reason) {
    SpeechUnavailableReason.permissionDenied =>
      'Resonance needs speech recognition to score your words. You can '
          'grant it in Settings, or keep practising without a score.',
    SpeechUnavailableReason.noRecogniserOnDevice =>
      'This device has no speech recogniser, so we cannot score clarity. '
          'Your pace and mic technique are still measured.',
    SpeechUnavailableReason.offline =>
      'Clarity scoring needs a connection on this device. Your take is '
          'saved and will be scored when you are back online.',
    SpeechUnavailableReason.unknown =>
      'Speech recognition is unavailable right now. Your take is saved.',
  };

  @override
  String toString() =>
      'SpeechUnavailable($reason${detail == null ? '' : ': $detail'})';
}

/// Transcribes speech.
abstract interface class SpeechRecogniser {
  /// Whether recognition can run at all. Cheap; safe to call before every take.
  Future<bool> isAvailable();

  /// Begins recognising.
  ///
  /// [contextHint] is the script the user is reading. Some platforms accept it
  /// as a biasing hint, which materially improves accuracy on proper nouns and
  /// tongue-twisters — exactly the material these lessons are made of.
  Future<void> start({String? localeId, String? contextHint});

  /// Interim and final results as they arrive.
  Stream<Transcript> get results;

  /// Stops and returns the final transcript.
  Future<Transcript> stop();

  Future<void> cancel();

  Future<void> dispose();
}

/// A recogniser that returns a scripted answer.
///
/// Used by tests and by the simulator, where there is no microphone. Lets the
/// entire scoring and feedback pipeline be exercised deterministically, which
/// is how the rubric gets tuned without re-recording a fixture set by hand.
class FakeSpeechRecogniser implements SpeechRecogniser {
  FakeSpeechRecogniser({
    required this.transcript,
    this.available = true,
    this.meanConfidence = 0.9,
    this.failure,
  });

  /// What this recogniser will claim to have heard.
  final String transcript;
  final bool available;
  final double? meanConfidence;

  /// When set, [start] throws this instead of recognising.
  final SpeechUnavailable? failure;

  final _controller = StreamController<Transcript>.broadcast();
  bool _running = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> start({String? localeId, String? contextHint}) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    _running = true;
  }

  @override
  Stream<Transcript> get results => _controller.stream;

  @override
  Future<Transcript> stop() async {
    _running = false;
    return Transcript(text: transcript, meanConfidence: meanConfidence);
  }

  @override
  Future<void> cancel() async {
    _running = false;
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _controller.close();
  }

  bool get isRunning => _running;
}
