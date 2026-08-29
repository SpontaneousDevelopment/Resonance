import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/mastery.dart';

/// A fixed clock. Real dates, so the calendar-day rule is exercised against
/// actual date arithmetic rather than a mock.
final day1 = DateTime(2026, 8, 28, 9, 0);
final day1Late = DateTime(2026, 8, 28, 23, 30);
final day2Early = DateTime(2026, 8, 29, 7, 15);
final day2 = DateTime(2026, 8, 29, 9, 0);

void main() {
  group('promotion', () {
    test('a fresh lesson promotes to bronze at the bronze threshold', () {
      const m = Mastery.fresh();
      final (next, result) = m.applyAttempt(score: 60, at: day1);

      expect(result.promoted, isTrue);
      expect(next.level, MasteryLevel.bronze);
      expect(next.attempts, 1);
      expect(next.bestScore, 60);
    });

    test('scoring one below the threshold does not promote', () {
      const m = Mastery.fresh();
      final (next, result) = m.applyAttempt(score: 59, at: day1);

      expect(result.promoted, isFalse);
      expect(result.block, PromotionBlock.scoreTooLow);
      expect(next.level, MasteryLevel.locked);
      // The attempt still counts, and still moves the best score.
      expect(next.attempts, 1);
      expect(next.bestScore, 59);
    });

    test('an exceptional score promotes one rung, not several', () {
      // The anti-vault rule: a 95 on a fresh lesson is bronze, not master.
      const m = Mastery.fresh();
      final (next, _) = m.applyAttempt(score: 95, at: day1);

      expect(next.level, MasteryLevel.bronze);
    });

    test('master is a ceiling', () {
      final m = Mastery(
        level: MasteryLevel.master,
        attempts: 20,
        bestScore: 96,
        lastPromotedOn: DateTime(2026, 8, 1),
      );
      final (next, result) = m.applyAttempt(score: 99, at: day1);

      expect(result.block, PromotionBlock.atCeiling);
      expect(next.level, MasteryLevel.master);
      expect(next.bestScore, 99);
    });
  });

  group('once-per-day rule', () {
    test('a second promotion on the same day is blocked', () {
      const fresh = Mastery.fresh();
      final (afterFirst, first) = fresh.applyAttempt(score: 75, at: day1);
      expect(first.promoted, isTrue);
      expect(afterFirst.level, MasteryLevel.bronze);

      final (afterSecond, second) =
          afterFirst.applyAttempt(score: 88, at: day1Late);

      expect(second.promoted, isFalse);
      expect(second.block, PromotionBlock.alreadyPromotedToday);
      expect(afterSecond.level, MasteryLevel.bronze);
      // The work is not thrown away — best score and attempts still move.
      expect(afterSecond.bestScore, 88);
      expect(afterSecond.attempts, 2);
    });

    test('promotion resumes the next calendar day, not 24h later', () {
      // 23:30 then 07:15 is under nine hours, but it crosses a night's sleep,
      // which is the thing the rule is actually about.
      const fresh = Mastery.fresh();
      final (afterFirst, _) = fresh.applyAttempt(score: 75, at: day1Late);
      final (afterSecond, second) =
          afterFirst.applyAttempt(score: 75, at: day2Early);

      expect(second.promoted, isTrue);
      expect(afterSecond.level, MasteryLevel.silver);
    });

    test('a blocked attempt does not consume the day', () {
      // Failing on the score should leave the day's promotion still available.
      const fresh = Mastery.fresh();
      final (afterFail, fail) = fresh.applyAttempt(score: 40, at: day1);
      expect(fail.promoted, isFalse);

      final (afterPass, pass) = afterFail.applyAttempt(score: 65, at: day1);
      expect(pass.promoted, isTrue);
      expect(afterPass.level, MasteryLevel.bronze);
    });
  });

  group('decay', () {
    test('drops exactly one level', () {
      final m = Mastery(
        level: MasteryLevel.gold,
        attempts: 8,
        bestScore: 82,
        lastPromotedOn: day1,
      );

      expect(m.decayed().level, MasteryLevel.silver);
    });

    test('never falls below bronze once earned', () {
      final m = Mastery(
        level: MasteryLevel.bronze,
        attempts: 3,
        bestScore: 64,
        lastPromotedOn: day1,
      );

      expect(m.decayed().level, MasteryLevel.bronze);
      expect(m.decayed().decayed().level, MasteryLevel.bronze);
    });

    test('leaves a never-passed lesson alone', () {
      expect(const Mastery.fresh().decayed().level, MasteryLevel.locked);
    });

    test('preserves best score and attempt count', () {
      final m = Mastery(
        level: MasteryLevel.diamond,
        attempts: 12,
        bestScore: 91,
        lastPromotedOn: day1,
      );
      final decayed = m.decayed();

      expect(decayed.bestScore, 91);
      expect(decayed.attempts, 12);
    });
  });

  group('a realistic climb', () {
    test('takes five separate days to reach master at passing scores', () {
      var m = const Mastery.fresh();
      var day = DateTime(2026, 9, 1);

      for (var i = 0; i < 5; i++) {
        final (next, result) = m.applyAttempt(score: 92, at: day);
        expect(result.promoted, isTrue, reason: 'day ${i + 1} should promote');
        m = next;
        day = day.add(const Duration(days: 1));
      }

      expect(m.level, MasteryLevel.master);
      expect(m.attempts, 5);
    });

    test('cannot be short-circuited by grinding in one evening', () {
      var m = const Mastery.fresh();
      final evening = DateTime(2026, 9, 1, 20, 0);

      for (var i = 0; i < 10; i++) {
        final (next, _) =
            m.applyAttempt(score: 95, at: evening.add(Duration(minutes: i * 5)));
        m = next;
      }

      expect(m.level, MasteryLevel.bronze);
      expect(m.attempts, 10);
    });
  });
}
