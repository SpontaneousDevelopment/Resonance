/// Combining N take scores into the one the lesson is graded on.
///
/// Declared by the content — see `TakeAggregation` — so a lesson's brief can be
/// checked against what actually happens to its takes. The Dial is why that
/// matters: its brief described a metric the code did not have.
library;

import '../curriculum/curriculum.dart';
import 'rubric.dart';

/// One take's contribution.
class ScoredTake {
  const ScoredTake({
    required this.index,
    required this.label,
    required this.score,
  });

  final int index;
  final String label;
  final AttemptScore score;
}

/// The lesson's composite, and which take decided it.
class AggregateScore {
  const AggregateScore({
    required this.composite,
    required this.decidedBy,
    required this.takes,
  });

  /// 0..100. What the mastery ladder consumes.
  final int composite;

  /// The take the composite came from, so the feedback screen can say *which*
  /// rung cost the lesson rather than only that something did.
  final ScoredTake decidedBy;

  final List<ScoredTake> takes;
}

abstract interface class TakeAggregator {
  AggregateScore combine(List<ScoredTake> takes);
}

/// The worst take carries the lesson.
///
/// For a ladder, where the whole point is that clarity has a floor: averaging
/// would let a strong slow read pay for a fast one that fell apart, which is
/// exactly the thing the lesson is trying to show you.
class LowestAcrossTakes implements TakeAggregator {
  const LowestAcrossTakes();

  @override
  AggregateScore combine(List<ScoredTake> takes) {
    if (takes.isEmpty) {
      throw ArgumentError('cannot aggregate an empty take list');
    }

    var worst = takes.first;
    for (final take in takes.skip(1)) {
      if (take.score.composite < worst.score.composite) worst = take;
    }

    return AggregateScore(
      composite: worst.score.composite,
      decidedBy: worst,
      takes: List.unmodifiable(takes),
    );
  }
}

/// Picks the aggregator a lesson declared.
///
/// [TakeAggregation.difference] has no implementation and the curriculum
/// compiler refuses to emit it, so reaching here with one is a bug rather than
/// a content mistake — hence a throw rather than a fallback. A silent fallback
/// to `lowest` is how a lesson ends up graded by something other than what it
/// claims.
TakeAggregator aggregatorFor(TakeAggregation declared) => switch (declared) {
  TakeAggregation.lowest => const LowestAcrossTakes(),
  TakeAggregation.difference => throw UnimplementedError(
    'take_aggregation "difference" has no implementation. It needs a measure '
    'of articulation precision independent of pace; the curriculum compiler '
    'rejects it for that reason, so this was reached by a code path that '
    'bypassed the compiler.',
  ),
};
