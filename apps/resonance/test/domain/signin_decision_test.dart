import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/sync/signin_decision.dart';

ProgressSummary withHistory({int lessons = 3, int xp = 120, int streak = 4}) =>
    ProgressSummary(
      lessonsAttempted: lessons,
      totalXp: xp,
      currentStreak: streak,
      lastPracticedOn: DateTime(2026, 9, 1),
    );

const empty = ProgressSummary.empty();

void main() {
  group('the common case is not a merge', () {
    test('local progress into a fresh account is adopted wholesale', () {
      // A brand-new account has nothing to reconcile against. Treating this as
      // a merge would be inventing a problem.
      final decision = SignInDecision.evaluate(
        local: withHistory(),
        remote: empty,
      );

      expect(decision.outcome, SignInOutcome.adoptLocal);
      expect(decision.requiresUserChoice, isFalse);
    });

    test('a fresh device signing into an existing account pulls it down', () {
      final decision = SignInDecision.evaluate(
        local: empty,
        remote: withHistory(),
      );

      expect(decision.outcome, SignInOutcome.adoptRemote);
      expect(decision.requiresUserChoice, isFalse);
      expect(decision.localAtRisk, isFalse);
    });

    test('nothing on either side is not a problem to solve', () {
      final decision = SignInDecision.evaluate(local: empty, remote: empty);
      expect(decision.outcome, SignInOutcome.nothingToCarry);
      expect(decision.requiresUserChoice, isFalse);
    });
  });

  group('the rare case is never resolved silently', () {
    test('history on both sides stops and asks', () {
      final decision = SignInDecision.evaluate(
        local: withHistory(lessons: 2),
        remote: withHistory(lessons: 9),
      );

      expect(decision.outcome, SignInOutcome.needsChoice);
      expect(decision.requiresUserChoice, isTrue);
      expect(decision.localAtRisk, isTrue);
    });

    test('a larger remote history does not make the choice automatic', () {
      // The tempting heuristic — keep whichever side has more — is exactly the
      // silent discard this must not do. Two lessons of real practice are not
      // the machine's to throw away.
      final decision = SignInDecision.evaluate(
        local: withHistory(lessons: 1, xp: 12),
        remote: withHistory(lessons: 200, xp: 9000),
      );

      expect(decision.outcome, SignInOutcome.needsChoice);
    });

    test('a more recent remote history does not make it automatic either', () {
      final decision = SignInDecision.evaluate(
        local: ProgressSummary(
          lessonsAttempted: 4,
          totalXp: 100,
          currentStreak: 2,
          lastPracticedOn: DateTime(2026, 1, 1),
        ),
        remote: ProgressSummary(
          lessonsAttempted: 4,
          totalXp: 100,
          currentStreak: 2,
          lastPracticedOn: DateTime(2026, 9, 1),
        ),
      );

      expect(decision.outcome, SignInOutcome.needsChoice);
    });
  });

  group('what counts as history', () {
    test('attempts, not XP', () {
      // Someone who practised and scored nothing still did the work. Losing it
      // would feel the same as losing a good session.
      const scoredNothing = ProgressSummary(
        lessonsAttempted: 5,
        totalXp: 0,
        currentStreak: 0,
      );

      expect(scoredNothing.hasHistory, isTrue);
      expect(
        SignInDecision.evaluate(local: scoredNothing, remote: empty).outcome,
        SignInOutcome.adoptLocal,
      );
    });

    test('an untouched install has none', () {
      expect(const ProgressSummary.empty().hasHistory, isFalse);
    });
  });

  group('the guarantee', () {
    test('no input produces a silent discard of local history', () {
      // The property the whole design exists for: whenever local work exists,
      // the outcome either keeps it or asks. It is never dropped for the user.
      for (final remote in [
        empty,
        withHistory(lessons: 1),
        withHistory(lessons: 500),
      ]) {
        final decision = SignInDecision.evaluate(
          local: withHistory(),
          remote: remote,
        );

        expect(
          decision.outcome == SignInOutcome.adoptLocal ||
              decision.outcome == SignInOutcome.needsChoice,
          isTrue,
          reason: 'local history was neither kept nor surfaced: $decision',
        );
      }
    });
  });
}
