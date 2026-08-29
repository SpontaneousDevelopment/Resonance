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

  /// Frames whose plosive score clears this are counted as an audible pop.
  /// Tuned so a normal P at a sensible mic distance does not register.
  static const plosiveThreshold = 0.55;

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

    final plosiveEvents = plosiveScores
        .where((s) => s >= plosiveThreshold)
        .length;
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
