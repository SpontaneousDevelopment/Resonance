/// Streak rules.
///
/// Duolingo's central insight is that a streak is only motivating while it
/// feels *protectable*. The moment it feels arbitrary or punitive, breaking it
/// becomes a relief rather than a loss — and a user who has lost a 40-day
/// streak to a single bad night frequently never returns.
///
/// So the freeze is spent automatically. A user should discover their streak
/// was saved, not be asked in advance to save it: at the moment the decision
/// would need making, they are by definition not in the app.
///
/// Pure Dart. All dates are local calendar days, never instants — a rule about
/// daily habit must agree with the day the user believes they are living in.
library;

/// The state a streak update produces, plus what to tell the user about it.
class StreakOutcome {
  const StreakOutcome({
    required this.currentStreak,
    required this.longestStreak,
    required this.freezesRemaining,
    required this.lastPracticeDay,
    required this.event,
  });

  final int currentStreak;
  final int longestStreak;
  final int freezesRemaining;
  final DateTime lastPracticeDay;
  final StreakEvent event;
}

enum StreakEvent {
  /// First ever session.
  started,

  /// Consecutive day.
  extended,

  /// Already practised today; nothing changed.
  alreadyPracticedToday,

  /// A day was missed and a freeze covered it. The streak survived.
  savedByFreeze,

  /// The streak lapsed and restarted at one.
  reset,
}

class StreakEngine {
  const StreakEngine();

  /// Freezes are capped so they cannot accumulate into an indefinite pause.
  static const maxFreezes = 2;

  /// Consecutive days that earn one freeze back.
  static const daysPerEarnedFreeze = 10;

  StreakOutcome practise({
    required DateTime at,
    required int currentStreak,
    required int longestStreak,
    required int freezesAvailable,
    DateTime? lastPracticeDay,
  }) {
    final today = _dayOf(at);

    if (lastPracticeDay == null) {
      return StreakOutcome(
        currentStreak: 1,
        longestStreak: longestStreak < 1 ? 1 : longestStreak,
        freezesRemaining: freezesAvailable,
        lastPracticeDay: today,
        event: StreakEvent.started,
      );
    }

    final last = _dayOf(lastPracticeDay);
    final gap = today.difference(last).inDays;

    if (gap <= 0) {
      // Already counted today. Practising more is welcome but the streak is a
      // measure of days, not sessions.
      return StreakOutcome(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        freezesRemaining: freezesAvailable,
        lastPracticeDay: last,
        event: StreakEvent.alreadyPracticedToday,
      );
    }

    if (gap == 1) {
      return _extend(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        freezesAvailable: freezesAvailable,
        today: today,
        event: StreakEvent.extended,
      );
    }

    // One missed day is covered by a freeze if there is one. Two or more is
    // beyond what a freeze is for — at that point the honest thing is to let it
    // restart rather than pretend continuity that was not there.
    final missedDays = gap - 1;
    if (missedDays == 1 && freezesAvailable > 0) {
      return _extend(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        freezesAvailable: freezesAvailable - 1,
        today: today,
        event: StreakEvent.savedByFreeze,
      );
    }

    return StreakOutcome(
      currentStreak: 1,
      longestStreak: longestStreak,
      freezesRemaining: freezesAvailable,
      lastPracticeDay: today,
      event: StreakEvent.reset,
    );
  }

  StreakOutcome _extend({
    required int currentStreak,
    required int longestStreak,
    required int freezesAvailable,
    required DateTime today,
    required StreakEvent event,
  }) {
    final next = currentStreak + 1;

    // Earn a freeze back every ten consecutive days, capped. Tied to the streak
    // rather than to spending money, so the safety net grows with the habit.
    var freezes = freezesAvailable;
    if (next % daysPerEarnedFreeze == 0 && freezes < maxFreezes) {
      freezes++;
    }

    return StreakOutcome(
      currentStreak: next,
      longestStreak: next > longestStreak ? next : longestStreak,
      freezesRemaining: freezes,
      lastPracticeDay: today,
      event: event,
    );
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
