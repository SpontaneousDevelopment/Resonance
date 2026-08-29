import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/progress/streak.dart';

const engine = StreakEngine();

DateTime day(int d) => DateTime(2026, 9, d, 19, 30);

void main() {
  group('starting', () {
    test('the first ever session starts a streak of one', () {
      final result = engine.practise(
        at: day(1),
        currentStreak: 0,
        longestStreak: 0,
        freezesAvailable: 2,
      );

      expect(result.event, StreakEvent.started);
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });
  });

  group('extending', () {
    test('a consecutive day extends', () {
      final result = engine.practise(
        at: day(2),
        currentStreak: 1,
        longestStreak: 1,
        freezesAvailable: 2,
        lastPracticeDay: day(1),
      );

      expect(result.event, StreakEvent.extended);
      expect(result.currentStreak, 2);
    });

    test('a second session the same day changes nothing', () {
      // The streak measures days, not sessions. Practising twice is welcome and
      // earns XP, but it does not buy tomorrow.
      final result = engine.practise(
        at: DateTime(2026, 9, 2, 23, 0),
        currentStreak: 5,
        longestStreak: 5,
        freezesAvailable: 1,
        lastPracticeDay: DateTime(2026, 9, 2, 8, 0),
      );

      expect(result.event, StreakEvent.alreadyPracticedToday);
      expect(result.currentStreak, 5);
      expect(result.freezesRemaining, 1);
    });

    test('crossing midnight counts as a new day, not 24 hours later', () {
      final result = engine.practise(
        at: DateTime(2026, 9, 3, 0, 30),
        currentStreak: 4,
        longestStreak: 4,
        freezesAvailable: 2,
        lastPracticeDay: DateTime(2026, 9, 2, 23, 45),
      );

      expect(result.event, StreakEvent.extended);
      expect(result.currentStreak, 5);
    });

    test('longest only moves when the current passes it', () {
      final result = engine.practise(
        at: day(2),
        currentStreak: 3,
        longestStreak: 40,
        freezesAvailable: 2,
        lastPracticeDay: day(1),
      );

      expect(result.currentStreak, 4);
      expect(result.longestStreak, 40);
    });
  });

  group('freezes', () {
    test('one missed day is covered automatically', () {
      // Spent without asking. At the moment the decision would need making the
      // user is, by definition, not in the app.
      final result = engine.practise(
        at: day(3),
        currentStreak: 12,
        longestStreak: 12,
        freezesAvailable: 2,
        lastPracticeDay: day(1),
      );

      expect(result.event, StreakEvent.savedByFreeze);
      expect(result.currentStreak, 13);
      expect(result.freezesRemaining, 1);
    });

    test('a missed day with no freezes resets', () {
      final result = engine.practise(
        at: day(3),
        currentStreak: 12,
        longestStreak: 12,
        freezesAvailable: 0,
        lastPracticeDay: day(1),
      );

      expect(result.event, StreakEvent.reset);
      expect(result.currentStreak, 1);
      // The record survives what the streak did not.
      expect(result.longestStreak, 12);
    });

    test('two missed days reset even with freezes in hand', () {
      // A freeze covers a bad night, not a lapsed habit. Papering over a longer
      // gap would make the number mean nothing.
      final result = engine.practise(
        at: day(4),
        currentStreak: 30,
        longestStreak: 30,
        freezesAvailable: 2,
        lastPracticeDay: day(1),
      );

      expect(result.event, StreakEvent.reset);
      expect(result.currentStreak, 1);
      expect(result.freezesRemaining, 2);
    });

    test('a freeze is earned back every ten days', () {
      final result = engine.practise(
        at: day(11),
        currentStreak: 9,
        longestStreak: 9,
        freezesAvailable: 0,
        lastPracticeDay: day(10),
      );

      expect(result.currentStreak, 10);
      expect(result.freezesRemaining, 1);
    });

    test('earned freezes are capped', () {
      final result = engine.practise(
        at: day(21),
        currentStreak: 19,
        longestStreak: 19,
        freezesAvailable: StreakEngine.maxFreezes,
        lastPracticeDay: day(20),
      );

      expect(result.currentStreak, 20);
      expect(result.freezesRemaining, StreakEngine.maxFreezes);
    });
  });

  group('a lived-in month', () {
    test('survives one skipped day and breaks on a real lapse', () {
      var streak = 0;
      var longest = 0;
      var freezes = 2;
      DateTime? last;
      final events = <StreakEvent>[];

      // Practises on days 1-5, skips 6, practises 7-9, then vanishes until 14.
      for (final d in [1, 2, 3, 4, 5, 7, 8, 9, 14]) {
        final result = engine.practise(
          at: day(d),
          currentStreak: streak,
          longestStreak: longest,
          freezesAvailable: freezes,
          lastPracticeDay: last,
        );
        streak = result.currentStreak;
        longest = result.longestStreak;
        freezes = result.freezesRemaining;
        last = result.lastPracticeDay;
        events.add(result.event);
      }

      expect(events[5], StreakEvent.savedByFreeze);
      expect(events.last, StreakEvent.reset);
      expect(streak, 1);
      // Eight days were reached before the lapse.
      expect(longest, 8);
      expect(freezes, 1);
    });
  });
}
