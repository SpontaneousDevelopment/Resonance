import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/take_aggregation.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';

/// Combining takes into the score the ladder is graded on.
const _script = 'The rugged brigadier bragged briefly about the burglary.';
const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

/// Produced by the real rubric, so these cannot pass on composites the app
/// could never actually generate.
ScoredTake take(
  int index,
  String label, {
  required String heard,
  double seconds = 4,
}) => ScoredTake(
  index: index,
  label: label,
  score: rubric.score(
    AttemptMeasurements(
      alignment: aligner.align(script: _script, transcript: heard),
      durationSeconds: seconds,
      targetWpmMin: 110,
      targetWpmMax: 210,
      totalFrames: 100,
    ),
  ),
);

void main() {
  const lowest = LowestAcrossTakes();

  test('the worst take carries the lesson', () {
    final takes = [
      take(0, 'Slow', heard: _script),
      take(1, 'Conversational', heard: _script),
      take(2, 'Fast', heard: 'The rugged brigadier'),
    ];

    final result = lowest.combine(takes);

    expect(result.composite, takes[2].score.composite);
    expect(
      result.composite,
      lessThan(takes[0].score.composite),
      reason: 'a fast take that fell apart must pull the lesson down',
    );
  });

  test('it names which take decided it', () {
    // So the feedback screen can say which rung cost the lesson rather than
    // only that something did.
    final takes = [
      take(0, 'Slow', heard: 'The rugged'),
      take(1, 'Conversational', heard: _script),
    ];

    expect(lowest.combine(takes).decidedBy.label, 'Slow');
  });

  test('averaging is not what happens', () {
    // The distinction the ladder exists to teach: a strong slow read must not
    // pay for a fast one that collapsed.
    final takes = [
      take(0, 'Slow', heard: _script),
      take(1, 'Fast', heard: 'The'),
    ];
    final result = lowest.combine(takes);
    final mean =
        takes.map((t) => t.score.composite).reduce((a, b) => a + b) ~/ 2;

    expect(result.composite, lessThan(mean));
  });

  test('a single take aggregates to itself', () {
    final takes = [take(0, 'The take', heard: _script)];
    final result = lowest.combine(takes);

    expect(result.composite, takes.first.score.composite);
    expect(result.decidedBy.index, 0);
  });

  test('every take is kept, not just the deciding one', () {
    final takes = [
      take(0, 'Slow', heard: _script),
      take(1, 'Fast', heard: 'The rugged'),
    ];
    expect(lowest.combine(takes).takes, hasLength(2));
  });

  test('an empty take list is a bug, not a zero', () {
    expect(() => lowest.combine(const []), throwsArgumentError);
  });

  group('choosing an aggregator', () {
    test('lowest resolves', () {
      expect(aggregatorFor(TakeAggregation.lowest), isA<LowestAcrossTakes>());
    });

    test('difference throws rather than quietly falling back', () {
      // A silent fallback to `lowest` is how a lesson ends up graded by
      // something other than what it claims — which is the exact bug the Dial
      // had. The compiler already refuses to emit this; reaching here means a
      // path bypassed it.
      expect(
        () => aggregatorFor(TakeAggregation.difference),
        throwsUnimplementedError,
      );
    });
  });
}
