import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/sanity_gate.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';

/// The sanity gate, against the real alignment pipeline.
///
/// The asymmetry is the thing under test: a genuinely poor read of the right
/// script must pass, and a recording of something else must not. Being too
/// strict tells someone who did read the passage that they did not, which is
/// worse than letting a bad take through to be scored honestly.
const _script =
    'The rugged brigadier bragged briefly about the burglary before breakfast, '
    'then hurried back through the bracken.';

const aligner = TranscriptAligner();
const gate = SanityGate();

AttemptMeasurements measure(String heard, {double seconds = 8}) =>
    AttemptMeasurements(
      alignment: aligner.align(script: _script, transcript: heard),
      durationSeconds: seconds,
      targetWpmMin: 110,
      targetWpmMax: 210,
      totalFrames: 100,
    );

void main() {
  group('a real attempt gets through', () {
    test('a clean read passes', () {
      expect(gate.check(measure(_script)).passed, isTrue);
    });

    test('a poor read of the right script passes', () {
      // Half the words dropped and two mangled. The rubric will score this
      // badly, which is correct — the gate must not be the thing that stops it.
      const halting =
          'The rugged brigadier bragged briefly about the burglar before '
          'breakfast';
      final verdict = gate.check(measure(halting, seconds: 6));
      expect(
        verdict.passed,
        isTrue,
        reason:
            'a weak but genuine take was refused: ${verdict.failure} — this '
            'gate is not a quality bar',
      );
    });

    test('a heavy-accent transcript with substitutions still passes', () {
      const misheard =
          'The rugged brigadier bragged briefly about the burglary before '
          'breakfast then hurried buck through the bricken';
      expect(gate.check(measure(misheard)).passed, isTrue);
    });
  });

  group('a non-attempt is caught', () {
    test('silence', () {
      final v = gate.check(measure('', seconds: 8));
      expect(v.passed, isFalse);
      expect(v.failure, SanityFailure.tooFewWords);
    });

    test('a cough', () {
      final v = gate.check(measure('uh', seconds: 4));
      expect(v.failure, SanityFailure.tooFewWords);
    });

    test('a mis-tap', () {
      final v = gate.check(measure(_script, seconds: 0.4));
      expect(v.failure, SanityFailure.tooShort);
    });

    test('reading something else entirely', () {
      const wrong =
          'I told him I would be there at eight and I meant it it is not '
          'complicated he just has to answer the phone';
      final v = gate.check(measure(wrong, seconds: 9));
      expect(v.passed, isFalse);
      expect(v.failure, SanityFailure.didNotMatchScript);
    });

    test('speech far too fast to be a read', () {
      final v = gate.check(measure(_script, seconds: 1.6));
      expect(v.failure, SanityFailure.implausiblePace);
    });

    test('speech far too slow to be a read', () {
      final v = gate.check(measure(_script, seconds: 60));
      expect(v.failure, SanityFailure.implausiblePace);
    });
  });

  group('the thresholds hold their shape', () {
    test('the gate is far more lenient than Bronze', () {
      // If this ever inverts, the gate has quietly become a quality bar.
      expect(SanityThresholds.minAccuracy, lessThan(0.6));
    });

    test('minSpokenWords fits inside the shortest authored script', () {
      // The Tempo Ladder's line is the shortest at sixteen words.
      expect(SanityThresholds.minSpokenWords, lessThan(16 * 0.5));
    });

    test('the plausible pace band is wider than any authored band', () {
      expect(SanityThresholds.wpmFloor, lessThan(95));
      expect(SanityThresholds.wpmCeiling, greaterThan(215));
    });

    test('every failure says something that is not a judgement', () {
      for (final f in SanityFailure.values) {
        final message = SanityVerdict.fail(f).message;
        expect(message, isNotEmpty);
        expect(
          message.toLowerCase(),
          isNot(contains('bad')),
          reason: 'the gate cannot tell whether a take was bad',
        );
      }
    });
  });
}
