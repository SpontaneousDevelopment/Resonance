import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/sensory/breath_cycle.dart';

/// A four-part cycle, driven by a virtual clock.
///
/// The bug this covers: size was a boolean derived by string-matching the phase
/// label, with no state for *hold* — so hold fell into the "not expanded"
/// branch and the circle shrank through it. The visible cycle was grow, shrink,
/// shrink.
const cycle = BreathCycle([
  BreathPhase(label: 'Breathe in', seconds: 4, shape: BreathShape.expand),
  BreathPhase(label: 'Hold', seconds: 4, shape: BreathShape.hold),
  BreathPhase(label: 'Breathe out', seconds: 6, shape: BreathShape.contract),
  BreathPhase(label: 'Rest', seconds: 2, shape: BreathShape.rest),
]);

double scaleAt(int ms) => cycle.stateAt(Duration(milliseconds: ms)).scale;

void main() {
  group('the four-part cycle', () {
    test('starts small', () {
      expect(scaleAt(0), 0);
      expect(cycle.stateAt(Duration.zero).phase.label, 'Breathe in');
    });

    test('expands monotonically through the inhale', () {
      var previous = -1.0;
      for (var ms = 0; ms <= 4000; ms += 100) {
        final scale = scaleAt(ms);
        expect(
          scale,
          greaterThanOrEqualTo(previous),
          reason: 'inhale went backwards at ${ms}ms',
        );
        previous = scale;
      }
      expect(scaleAt(3999), greaterThan(0.99));
    });

    test('HOLDS through the hold — constant, not drifting', () {
      // The actual regression. Every sample across the hold must be identical;
      // the old implementation shrank from 1.0 to 0.0 across these four seconds.
      final samples = [for (var ms = 4000; ms < 8000; ms += 100) scaleAt(ms)];

      expect(
        samples.every((s) => s == 1.0),
        isTrue,
        reason: 'hold is not holding: ${samples.first} → ${samples.last}',
      );
    });

    test('contracts monotonically through the exhale', () {
      var previous = 2.0;
      for (var ms = 8000; ms < 14000; ms += 100) {
        final scale = scaleAt(ms);
        expect(
          scale,
          lessThanOrEqualTo(previous),
          reason: 'exhale went backwards at ${ms}ms',
        );
        previous = scale;
      }
    });

    test('rests small and still', () {
      final samples = [for (var ms = 14000; ms < 16000; ms += 100) scaleAt(ms)];
      expect(samples.every((s) => s == 0.0), isTrue);
    });

    test('the exhale ends where the rest begins', () {
      // A discontinuity here reads as the circle snapping.
      expect(scaleAt(13999), lessThan(0.02));
      expect(scaleAt(14000), 0);
    });
  });

  group('phase boundaries', () {
    test('each phase starts exactly when the previous ends', () {
      expect(
        cycle.stateAt(const Duration(milliseconds: 3999)).phase.label,
        'Breathe in',
      );
      expect(
        cycle.stateAt(const Duration(milliseconds: 4000)).phase.label,
        'Hold',
      );
      expect(
        cycle.stateAt(const Duration(milliseconds: 7999)).phase.label,
        'Hold',
      );
      expect(
        cycle.stateAt(const Duration(milliseconds: 8000)).phase.label,
        'Breathe out',
      );
    });

    test('the countdown reaches zero only as a phase ends', () {
      // A floor would show "3" for a four-second phase's first instant.
      expect(cycle.stateAt(Duration.zero).secondsRemaining, 4);
      expect(
        cycle.stateAt(const Duration(milliseconds: 3999)).secondsRemaining,
        1,
      );
    });
  });

  group('purity', () {
    test('the same elapsed time always gives the same state', () {
      // This is what makes the circle immune to rebuilds: nothing about the
      // result depends on when or how often it is asked.
      for (final ms in [0, 1234, 4000, 7999, 12000, 15999]) {
        final a = scaleAt(ms);
        for (var i = 0; i < 5; i++) {
          expect(scaleAt(ms), a, reason: 'not pure at ${ms}ms');
        }
      }
    });

    test('asking out of order does not change anything', () {
      // A rebuild can land at any moment; evaluation order must not matter.
      final forward = [for (var ms = 0; ms < 16000; ms += 500) scaleAt(ms)];
      final backward = [
        for (var ms = 15500; ms >= 0; ms -= 500) scaleAt(ms),
      ].reversed.toList();

      expect(forward, backward);
    });
  });

  group('edges', () {
    test('past the end it settles rather than wrapping', () {
      final state = cycle.stateAt(const Duration(seconds: 60));
      expect(state.isComplete, isTrue);
      expect(state.cycleProgress, 1);
    });

    test('a negative elapsed clamps to the start', () {
      expect(cycle.stateAt(const Duration(seconds: -5)).scale, 0);
    });

    test('total is the sum of its phases', () {
      expect(cycle.total, const Duration(seconds: 16));
    });
  });
}
