import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/progress/vocal_energy.dart';

DateTime at(int hour, {int minute = 0, int day = 1}) =>
    DateTime(2026, 9, day, hour, minute);

void main() {
  group('passing attempts', () {
    test('cost nothing', () {
      const energy = VocalEnergy.full();
      final (next, event) =
          energy.applyAttempt(lessonId: 'a', score: 75, at: at(10));

      expect(event, EnergyEvent.unchanged);
      expect(next.bars, VocalEnergy.maxBars);
    });

    test('the threshold is the Bronze line, so a promoting take is free', () {
      // An attempt good enough to level up must never cost energy — charging
      // for success would make the meter feel arbitrary.
      const energy = VocalEnergy.full();
      final (next, event) = energy.applyAttempt(
        lessonId: 'a',
        score: VocalEnergy.lowScoreThreshold,
        at: at(10),
      );

      expect(event, EnergyEvent.unchanged);
      expect(next.bars, VocalEnergy.maxBars);
    });

    test('a passing attempt clears a struggle streak', () {
      const energy = VocalEnergy(
        bars: 3,
        consecutiveLowLessonId: 'a',
        consecutiveLowCount: 2,
      );

      final (next, _) =
          energy.applyAttempt(lessonId: 'a', score: 80, at: at(10));

      expect(next.consecutiveLowCount, 0);
      expect(next.consecutiveLowLessonId, isNull);
    });
  });

  group('low-scoring attempts', () {
    test('cost one bar', () {
      const energy = VocalEnergy.full();
      final (next, event) =
          energy.applyAttempt(lessonId: 'a', score: 40, at: at(10));

      expect(event, EnergyEvent.spent);
      expect(next.bars, 4);
    });

    test('a second consecutive low score on the same lesson costs two', () {
      // Repeating a lesson that is not improving is usually fatigue. That is
      // the specific pattern worth interrupting.
      const energy = VocalEnergy.full();
      final (once, _) =
          energy.applyAttempt(lessonId: 'a', score: 40, at: at(10));
      final (twice, event) =
          once.applyAttempt(lessonId: 'a', score: 38, at: at(10, minute: 2));

      expect(event, EnergyEvent.spentOnRepeat);
      expect(twice.bars, 2);
    });

    test('switching lesson resets the repeat counter', () {
      const energy = VocalEnergy.full();
      final (first, _) =
          energy.applyAttempt(lessonId: 'a', score: 40, at: at(10));
      final (second, event) =
          first.applyAttempt(lessonId: 'b', score: 40, at: at(10, minute: 2));

      expect(event, EnergyEvent.spent);
      expect(second.bars, 3);
    });

    test('reaching zero reports depletion', () {
      var energy = const VocalEnergy(bars: 1);
      final (next, event) =
          energy.applyAttempt(lessonId: 'a', score: 20, at: at(10));

      expect(event, EnergyEvent.depleted);
      expect(next.bars, 0);
      expect(next.isEmpty, isTrue);
    });

    test('never goes below zero', () {
      const energy = VocalEnergy(bars: 1, consecutiveLowLessonId: 'a', consecutiveLowCount: 1);
      final (next, _) =
          energy.applyAttempt(lessonId: 'a', score: 10, at: at(10));

      expect(next.bars, 0);
    });
  });

  group('regeneration', () {
    test('one bar returns every thirty idle minutes', () {
      final energy = VocalEnergy(bars: 2, lastSpentAt: at(10));

      expect(energy.regenerated(at(10, minute: 29)).bars, 2);
      expect(energy.regenerated(at(10, minute: 30)).bars, 3);
      // 60 idle minutes = two bars earned.
      expect(energy.regenerated(at(11)).bars, 4);
      // 90 = three, which caps the meter.
      expect(energy.regenerated(at(11, minute: 30)).bars, VocalEnergy.maxBars);
    });

    test('partial progress toward the next bar is not discarded', () {
      // Regenerating advances the clock by what was consumed, not to `now` —
      // otherwise every read would silently reset the timer.
      final energy = VocalEnergy(bars: 2, lastSpentAt: at(10));
      final after = energy.regenerated(at(10, minute: 45));

      expect(after.bars, 3);
      expect(after.lastSpentAt, at(10, minute: 30));
      expect(after.regenerated(at(11)).bars, 4);
    });

    test('caps at full and clears the timer', () {
      final energy = VocalEnergy(bars: 1, lastSpentAt: at(10));
      final after = energy.regenerated(at(20));

      expect(after.bars, VocalEnergy.maxBars);
      expect(after.lastSpentAt, isNull);
    });

    test('a new calendar day restores everything', () {
      // The meter must not follow someone across days. Tomorrow starts full.
      final energy = VocalEnergy(bars: 0, lastSpentAt: at(23, minute: 50));
      final after = energy.regenerated(at(7, day: 2));

      expect(after.bars, VocalEnergy.maxBars);
      expect(after.consecutiveLowCount, 0);
    });

    test('a clock moving backwards does not grant energy', () {
      final energy = VocalEnergy(bars: 2, lastSpentAt: at(12));
      expect(energy.regenerated(at(11)).bars, 2);
    });
  });

  group('rest', () {
    test('restores two bars, not five', () {
      // Enough to continue; not enough to make resting a way to farm energy.
      const energy = VocalEnergy(bars: 0);
      expect(energy.afterRest(at(10)).bars, 2);
    });

    test('never reduces what the user already has', () {
      const energy = VocalEnergy(bars: 4);
      expect(energy.afterRest(at(10)).bars, 4);
    });

    test('clears the struggle streak so the next attempt starts fresh', () {
      const energy = VocalEnergy(
        bars: 0,
        consecutiveLowLessonId: 'a',
        consecutiveLowCount: 3,
      );
      expect(energy.afterRest(at(10)).consecutiveLowCount, 0);
    });
  });

  group('the meter never blocks', () {
    test('an empty meter still accepts attempts', () {
      // The central product rule. Depleted routes the user to a rest exercise;
      // it does not stop them practising, and no method here can express a
      // refusal.
      const energy = VocalEnergy(bars: 0);
      final (next, event) =
          energy.applyAttempt(lessonId: 'a', score: 30, at: at(10));

      expect(next.bars, 0);
      expect(event, EnergyEvent.depleted);
    });

    test('a good attempt while empty is still free', () {
      const energy = VocalEnergy(bars: 0);
      final (_, event) =
          energy.applyAttempt(lessonId: 'a', score: 90, at: at(10));

      expect(event, EnergyEvent.unchanged);
    });
  });
}
