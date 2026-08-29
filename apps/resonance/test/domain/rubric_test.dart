import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';

const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

const script =
    'Peter picked a bitter batch of pickled peppers, packed them '
    'tight, and put the barrel back beside the broken gate.';

/// ~22 words. At 150 wpm that is about 8.8 seconds.
AttemptMeasurements measure({
  String? transcript,
  double durationSeconds = 8.8,
  int plosiveEvents = 0,
  int clippedFrames = 0,
  int totalFrames = 200,
  double? meanConfidence,
}) {
  return AttemptMeasurements(
    alignment: aligner.align(script: script, transcript: transcript ?? script),
    durationSeconds: durationSeconds,
    targetWpmMin: 130,
    targetWpmMax: 165,
    plosiveEvents: plosiveEvents,
    clippedFrames: clippedFrames,
    totalFrames: totalFrames,
    meanConfidence: meanConfidence,
  );
}

void main() {
  group('a clean read', () {
    test('scores high enough to promote', () {
      final result = rubric.score(measure());

      // Must clear Gold (78) — a genuinely clean read at the right pace with
      // no pops should not be stuck at Bronze.
      expect(result.composite, greaterThanOrEqualTo(78));
      expect(result.component('Clarity')!.score, 100);
      expect(result.component('Pace')!.score, 100);
      expect(result.component('Plosive control')!.score, 100);
    });

    test('says something specific rather than only a number', () {
      final result = rubric.score(measure());
      expect(result.component('Clarity')!.detail, 'Every word landed.');
    });
  });

  group('clarity', () {
    test('drops as words are lost', () {
      final clean = rubric.score(measure()).component('Clarity')!.score;
      final lossy = rubric
          .score(
            measure(
              transcript:
                  'peter picked a batch of peppers packed them tight '
                  'and put the barrel back beside the gate',
            ),
          )
          .component('Clarity')!
          .score;

      expect(lossy, lessThan(clean));
    });

    test('names the word that was lost', () {
      final result = rubric.score(
        measure(
          transcript:
              'peter picked a bitter of pickled peppers packed them '
              'tight and put the barrel back beside the broken gate',
        ),
      );

      expect(result.component('Clarity')!.detail, contains('batch'));
    });

    test('penalises a substitution more than an omission', () {
      // Skipping a word is a reading slip; a word heard as a different word is
      // an articulation failure, which is what this unit teaches.
      final omitted = rubric
          .score(
            measure(
              transcript:
                  'peter picked a bitter of pickled peppers packed them '
                  'tight and put the barrel back beside the broken gate',
            ),
          )
          .component('Clarity')!
          .score;

      final substituted = rubric
          .score(
            measure(
              transcript:
                  'peter picked a bitter bat of pickled peppers packed '
                  'them tight and put the barrel back beside the broken gate',
            ),
          )
          .component('Clarity')!
          .score;

      expect(substituted, lessThan(omitted));
    });

    test('low recogniser confidence nudges the score down', () {
      final confident = rubric
          .score(measure(meanConfidence: 1.0))
          .component('Clarity')!
          .score;
      final mumbled = rubric
          .score(measure(meanConfidence: 0.3))
          .component('Clarity')!
          .score;

      expect(mumbled, lessThan(confident));
      // But only a nudge — confidence is a hint, not a verdict.
      expect(confident - mumbled, lessThan(20));
    });
  });

  group('pace', () {
    test('inside the band scores full marks', () {
      expect(rubric.score(measure()).component('Pace')!.score, 100);
    });

    test('slightly outside the band is forgiven', () {
      // A hard edge would make the meter feel twitchy on an otherwise fine read.
      final result = rubric.score(measure(durationSeconds: 9.8));
      expect(result.component('Pace')!.score, 100);
    });

    test('rushing costs points and says so', () {
      final result = rubric.score(measure(durationSeconds: 4.0));
      final pace = result.component('Pace')!;

      expect(pace.score, lessThan(100));
      expect(pace.detail, contains('faster'));
    });

    test('dragging costs points and says so', () {
      final result = rubric.score(measure(durationSeconds: 20.0));
      final pace = result.component('Pace')!;

      expect(pace.score, lessThan(100));
      expect(pace.detail, contains('slower'));
    });

    test('being far off pace does not zero an otherwise clean read', () {
      final result = rubric.score(measure(durationSeconds: 90.0));
      expect(result.component('Pace')!.score, greaterThanOrEqualTo(30));
    });

    test('wpm counts words spoken, not words in the script', () {
      // Someone who read half the passage in half the time was not reading
      // fast. Measuring against the script would say they were.
      final half = measure(
        transcript:
            'peter picked a bitter batch of pickled peppers packed '
            'them tight',
        durationSeconds: 4.4,
      );

      expect(half.wordsPerMinute, closeTo(150, 20));
    });
  });

  group('plosive control', () {
    test('a couple of pops a minute is normal', () {
      final result = rubric.score(measure(plosiveEvents: 0));
      expect(result.component('Plosive control')!.score, 100);
    });

    test('persistent popping costs points and offers a fix', () {
      final result = rubric.score(
        measure(plosiveEvents: 4, durationSeconds: 10),
      );
      final plosive = result.component('Plosive control')!;

      expect(plosive.score, lessThan(100));
      expect(plosive.detail, contains('angling the mic'));
    });
  });

  group('guards', () {
    test('a near-empty read cannot score well on pace and mic alone', () {
      // You can have immaculate mic technique while saying almost nothing.
      final result = rubric.score(
        measure(transcript: 'peter', durationSeconds: 0.4),
      );

      expect(result.composite, lessThanOrEqualTo(40));
    });

    test('a clipped take is capped however well performed', () {
      final clean = rubric.score(measure()).composite;
      final clipped = rubric.score(measure(clippedFrames: 30)).composite;

      expect(clean, greaterThan(70));
      expect(clipped, lessThanOrEqualTo(70));
    });

    test('a zero-length attempt does not divide by zero', () {
      final result = rubric.score(
        measure(transcript: '', durationSeconds: 0, totalFrames: 0),
      );

      expect(result.composite, inInclusiveRange(0, 100));
    });

    test('the composite always lands in range', () {
      for (final duration in [0.1, 1.0, 8.8, 60.0, 600.0]) {
        for (final pops in [0, 5, 100]) {
          final result = rubric.score(
            measure(durationSeconds: duration, plosiveEvents: pops),
          );
          expect(result.composite, inInclusiveRange(0, 100));
        }
      }
    });
  });

  group('score ordering', () {
    test('better reads score higher, monotonically', () {
      // The single most important property: if the app ever ranks a worse take
      // above a better one, the user stops trusting every number in it.
      final perfect = rubric.score(measure()).composite;

      final oneDropped = rubric
          .score(
            measure(
              transcript:
                  'peter picked a bitter of pickled peppers packed them '
                  'tight and put the barrel back beside the broken gate',
            ),
          )
          .composite;

      final several = rubric
          .score(
            measure(
              transcript:
                  'peter picked a of peppers packed them and put the '
                  'barrel beside the gate',
            ),
          )
          .composite;

      final poor = rubric
          .score(
            measure(transcript: 'peter picked something', durationSeconds: 3),
          )
          .composite;

      expect(perfect, greaterThan(oneDropped));
      expect(oneDropped, greaterThan(several));
      expect(several, greaterThan(poor));
    });
  });
}
