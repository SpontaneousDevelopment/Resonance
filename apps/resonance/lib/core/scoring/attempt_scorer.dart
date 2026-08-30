import 'package:resonance_dsp/resonance_dsp.dart';

import '../../domain/curriculum/curriculum.dart';
import '../../domain/scoring/rubric.dart';
import '../../domain/scoring/transcript_alignment.dart';
import '../audio/recording_session.dart';
import '../speech/speech_recogniser.dart';

/// Turns a finished take plus a transcript into a score.
///
/// The join between the audio layer, the speech layer and the pure rubric. Kept
/// deliberately thin: everything with a judgement in it lives in
/// `domain/scoring`, so it stays testable without a microphone.
class AttemptScorer {
  const AttemptScorer({
    this.rubric = const ScoredReadRubric(),
    this.aligner = const TranscriptAligner(),
  });

  final ScoredReadRubric rubric;
  final TranscriptAligner aligner;

  /// Frames whose plosive score clears this are candidates for a pop.
  ///
  /// The detector returns 0 or 0.55–1.0, so this asks "did the frame meet every
  /// minimum condition" rather than encoding a separate policy of its own.
  static const plosiveThreshold = 0.55;

  /// How long after a counted pop before another can be counted.
  ///
  /// A plosive's low-frequency energy decays over roughly 60–150 ms, spanning
  /// two or three 43 ms frames. 200 ms is also below the fastest a human can
  /// articulate consecutive plosives, so no real pop is ever swallowed.
  static const plosiveRefractory = Duration(milliseconds: 200);

  AttemptScore score({
    required Lesson lesson,
    required Take take,
    required Transcript transcript,
    required List<FrameAnalysis> frameAnalyses,
    required List<double> plosiveScores,
  }) {
    final alignment = aligner.align(
      script: lesson.script ?? '',
      transcript: transcript.text,
      wordConfidences: transcript.wordConfidences.isEmpty
          ? null
          : transcript.wordConfidences,
    );

    final plosiveEvents = countPlosiveEvents(
      plosiveScores,
      frameDuration: _frameDuration(take, frameAnalyses),
    );
    final clippedFrames = frameAnalyses.where((f) => f.isClipping).length;

    // Duration comes from the *voiced* span, not the file length. A user who
    // hits record, thinks for four seconds, then reads at a perfectly good pace
    // should not be told they were slow.
    final voicedSeconds = _voicedSpanSeconds(frameAnalyses, take);

    return rubric.score(
      AttemptMeasurements(
        alignment: alignment,
        durationSeconds: voicedSeconds,
        targetWpmMin: lesson.targetWpmMin,
        targetWpmMax: lesson.targetWpmMax,
        plosiveEvents: plosiveEvents,
        clippedFrames: clippedFrames,
        totalFrames: frameAnalyses.length,
        meanConfidence: transcript.meanConfidence,
      ),
    );
  }

  /// Counts distinct pops, not qualifying frames.
  ///
  /// One physical plosive decays across several frames; counting each as its
  /// own event is what produced implausible rates. Measured on recorded audio
  /// with known injected pops, three of five spanned two frames — a 60%
  /// over-count. After a counted pop, later frames are ignored until the
  /// refractory window passes.
  static int countPlosiveEvents(
    List<double> scores, {
    required Duration frameDuration,
  }) {
    if (scores.isEmpty || frameDuration <= Duration.zero) return 0;

    final int framesToSkip =
        (plosiveRefractory.inMicroseconds / frameDuration.inMicroseconds)
            .ceil();

    var events = 0;
    var blockedUntil = -1;
    for (var i = 0; i < scores.length; i++) {
      if (i <= blockedUntil) continue;
      if (scores[i] < plosiveThreshold) continue;
      events++;
      blockedUntil = i + framesToSkip - 1;
    }
    return events;
  }

  /// How long each analysed frame covers, derived from the take rather than
  /// assumed — the frame size is configurable on [VoiceAnalyser].
  Duration _frameDuration(Take take, List<FrameAnalysis> frames) {
    if (frames.isEmpty || take.durationSeconds <= 0) {
      return const Duration(milliseconds: 43);
    }
    final seconds = take.durationSeconds / frames.length;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  /// Seconds between the first and last voiced frame.
  double _voicedSpanSeconds(List<FrameAnalysis> frames, Take take) {
    if (frames.isEmpty) return take.durationSeconds;

    final first = frames.indexWhere((f) => f.isVoiced);
    if (first < 0) return take.durationSeconds;

    var last = frames.length - 1;
    while (last > first && !frames[last].isVoiced) {
      last--;
    }

    final frameSeconds = take.durationSeconds / frames.length;
    final span = (last - first + 1) * frameSeconds;
    return span <= 0 ? take.durationSeconds : span;
  }
}
