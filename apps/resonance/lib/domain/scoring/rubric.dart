/// Turns measurements into a score.
///
/// Every weight and threshold in this file is a product decision, and the
/// biggest risk in the whole app is that these numbers feel arbitrary. A
/// beginner cannot tell a real 68 from a random one — but they can absolutely
/// tell when the app disagrees with their own ears twice in a row, and after
/// that they stop believing any of it.
///
/// Two consequences for how this is written:
///
/// * Pure Dart with no dependencies, so it can be replayed against a fixture
///   set of coach-rated takes in CI. Change a weight, see which fixtures move.
/// * Components are kept separate all the way to the database, so a
///   reweighting can be recomputed against historical attempts rather than
///   invalidating them.
library;

import 'dart:math' as math;

import 'transcript_alignment.dart';

/// The raw measurements for one attempt, before any judgement.
class AttemptMeasurements {
  const AttemptMeasurements({
    required this.alignment,
    required this.durationSeconds,
    required this.targetWpmMin,
    required this.targetWpmMax,
    this.plosiveEvents = 0,
    this.clippedFrames = 0,
    this.totalFrames = 0,
    this.meanConfidence,
  });

  final TranscriptAlignment alignment;
  final double durationSeconds;

  /// The lesson's target pace band. A wide band is a forgiving lesson.
  final int? targetWpmMin;
  final int? targetWpmMax;

  /// Frames where a sudden low-frequency burst was detected.
  final int plosiveEvents;

  final int clippedFrames;
  final int totalFrames;

  /// Mean recogniser confidence across heard words, when available.
  final double? meanConfidence;

  /// Words actually spoken per minute.
  ///
  /// Counts words the recogniser *heard*, not words in the script. A user who
  /// read half the passage in half the time was not reading fast — measuring
  /// against the script would say they were.
  double get wordsPerMinute {
    if (durationSeconds <= 0) return 0;
    final spoken =
        alignment.matches + alignment.substitutions + alignment.insertions;
    return spoken / durationSeconds * 60;
  }

  double get clippingRatio =>
      totalFrames == 0 ? 0 : clippedFrames / totalFrames;
}

/// One scored dimension.
class ScoreComponent {
  const ScoreComponent({
    required this.label,
    required this.score,
    required this.weight,
    this.detail,
  });

  final String label;

  /// 0..100.
  final int score;

  /// Contribution to the composite, 0..1.
  final double weight;

  /// A short human-readable reason, shown under the number.
  final String? detail;
}

/// The full result of scoring an attempt.
class AttemptScore {
  const AttemptScore({
    required this.composite,
    required this.components,
    required this.measurements,
  });

  /// 0..100. This is what the mastery ladder consumes.
  final int composite;

  final List<ScoreComponent> components;
  final AttemptMeasurements measurements;

  ScoreComponent? component(String label) {
    for (final c in components) {
      if (c.label == label) return c;
    }
    return null;
  }
}

/// Scores a `scoredRead` attempt.
class ScoredReadRubric {
  const ScoredReadRubric();

  /// Below this, a read is too incomplete to score meaningfully — usually a
  /// false start, a recogniser failure, or a user who stopped early.
  static const minimumAccuracyToScore = 0.35;

  /// How far outside the target band the pace can stray before it costs
  /// anything. A band with no tolerance would make the meter feel twitchy.
  static const wpmGrace = 10.0;

  AttemptScore score(AttemptMeasurements m) {
    final clarity = _clarity(m);
    final pace = _pace(m);
    final plosive = _plosiveControl(m);

    final components = <ScoreComponent>[clarity, pace, plosive];

    // A read that barely happened should not produce a middling score from
    // strong pace and plosive numbers — you can have immaculate mic technique
    // while saying almost nothing.
    if (m.alignment.accuracy < minimumAccuracyToScore) {
      return AttemptScore(
        composite: math.min(clarity.score, 40),
        components: components,
        measurements: m,
      );
    }

    var total = 0.0;
    var weightSum = 0.0;
    for (final c in components) {
      total += c.score * c.weight;
      weightSum += c.weight;
    }

    var composite = weightSum == 0 ? 0.0 : total / weightSum;

    // Heavy clipping caps the score regardless of everything else: a clipped
    // take is unusable as a recording, however well performed.
    if (m.clippingRatio > 0.02) {
      composite = math.min(composite, 70);
    }

    return AttemptScore(
      composite: composite.round().clamp(0, 100),
      components: components,
      measurements: m,
    );
  }

  /// Did the words arrive intact.
  ///
  /// Weighted highest because it is the most reliable signal we have — the
  /// target text is known, so this is alignment rather than open transcription.
  ScoreComponent _clarity(AttemptMeasurements m) {
    final accuracy = m.alignment.accuracy;

    // Substitutions are weighted worse than omissions here, which is
    // deliberate. Skipping a word is usually a reading slip; a word heard as a
    // *different* word is an articulation failure, which is what this unit
    // actually teaches.
    final substitutionPenalty = m.alignment.expectedCount == 0
        ? 0.0
        : m.alignment.substitutions / m.alignment.expectedCount * 0.35;

    var raw = (accuracy - substitutionPenalty).clamp(0.0, 1.0);

    // Nudge by recogniser confidence where the platform gives it. Low
    // confidence on words that did match usually means mumbled-but-guessable.
    final confidence = m.meanConfidence;
    if (confidence != null) {
      raw *= 0.85 + 0.15 * confidence.clamp(0.0, 1.0);
    }

    final score = (raw * 100).round().clamp(0, 100);
    final missed = m.alignment.missed;

    return ScoreComponent(
      label: 'Clarity',
      score: score,
      weight: 0.55,
      detail: missed.isEmpty
          ? 'Every word landed.'
          : missed.length == 1
          ? 'Lost one word: "${missed.first.expected}".'
          : 'Lost ${missed.length} words, starting with '
                '"${missed.first.expected}".',
    );
  }

  /// Was the pace inside the lesson's band.
  ScoreComponent _pace(AttemptMeasurements m) {
    final wpm = m.wordsPerMinute;
    final min = m.targetWpmMin;
    final max = m.targetWpmMax;

    if (min == null || max == null) {
      return ScoreComponent(
        label: 'Pace',
        score: 100,
        weight: 0.0, // Unweighted when the lesson sets no target.
        detail: '${wpm.round()} words per minute.',
      );
    }

    if (wpm >= min - wpmGrace && wpm <= max + wpmGrace) {
      return ScoreComponent(
        label: 'Pace',
        score: 100,
        weight: 0.25,
        detail: '${wpm.round()} wpm — inside the target band.',
      );
    }

    final distance = wpm < min ? (min - wpm) : (wpm - max);
    // Ten points per 10 wpm outside the band, floored at 30 — being far off
    // pace is a real fault but should not zero an otherwise clean read.
    final score = math.max(30.0, 100 - distance).round();

    return ScoreComponent(
      label: 'Pace',
      score: score,
      weight: 0.25,
      detail: wpm < min
          ? '${wpm.round()} wpm — slower than the $min–$max target.'
          : '${wpm.round()} wpm — faster than the $min–$max target.',
    );
  }

  /// Mic technique: were plosives controlled.
  ScoreComponent _plosiveControl(AttemptMeasurements m) {
    if (m.durationSeconds <= 0) {
      return const ScoreComponent(
        label: 'Plosive control',
        score: 100,
        weight: 0.2,
      );
    }

    final perMinute = m.plosiveEvents / m.durationSeconds * 60;

    // Up to two audible plosives a minute is normal even for a professional on
    // a good day. Beyond about ten the read needs a pop filter or an angle
    // change, not more effort.
    final score = perMinute <= 2
        ? 100
        : math.max(0.0, 100 - (perMinute - 2) * 8).round();

    return ScoreComponent(
      label: 'Plosive control',
      score: score,
      weight: 0.2,
      detail: perMinute <= 2
          ? 'Clean — no thumping.'
          : '${perMinute.round()} pops a minute. Try angling the mic slightly '
                'off your mouth.',
    );
  }
}
