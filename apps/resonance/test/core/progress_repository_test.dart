import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/progress/progress_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/progress/streak.dart';
import 'package:resonance/domain/progress/vocal_energy.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';

const lesson = Lesson(
  id: 't1u3l1-plosive-precision',
  unitId: 't1u3-articulation',
  title: 'Plosive Precision',
  type: LessonType.scoredRead,
  brief: 'Read steadily.',
  script: 'Peter picked a bitter batch of pickled peppers',
  targetWpmMin: 130,
  targetWpmMax: 165,
);

const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

/// Builds a score by varying the transcript, so the composite is produced by
/// the real rubric rather than hand-set — otherwise these tests would pass on
/// numbers the app can never actually produce.
AttemptScore scoreOf({required bool good}) => rubric.score(
  AttemptMeasurements(
    alignment: aligner.align(
      script: lesson.script!,
      transcript: good ? lesson.script! : 'peter',
    ),
    durationSeconds: good ? 3.6 : 1.0,
    targetWpmMin: 130,
    targetWpmMax: 165,
    totalFrames: 100,
  ),
);

DateTime day(int d, {int hour = 10}) => DateTime(2026, 9, d, hour);

void main() {
  late ResonanceDatabase db;
  late ProgressRepository repo;
  var counter = 0;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    repo = ProgressRepository(db);
    counter = 0;
  });

  tearDown(() async => db.close());

  Future<SessionOutcome> record({
    required bool good,
    required DateTime at,
    Lesson forLesson = lesson,
  }) {
    return repo.recordAttempt(
      lesson: forLesson,
      score: scoreOf(good: good),
      attemptId: 'attempt-${counter++}',
      durationMs: 3600,
      now: at,
    );
  }

  group('one attempt writes everything', () {
    test('attempt, mastery, xp, streak and outbox all land', () async {
      final outcome = await record(good: true, at: day(1));

      expect(outcome.promotion.promoted, isTrue);
      expect(outcome.xpAwarded, greaterThan(0));

      expect(await db.attemptsFor(lesson.id), hasLength(1));
      expect((await repo.masteryFor(lesson.id)).level, MasteryLevel.bronze);
      expect(await repo.xpToday(day(1)), outcome.xpAwarded);
      expect((await db.streak()).currentStreak, 1);
      expect(await db.pendingSync(), hasLength(1));
    });

    test('score components are persisted, not just the composite', () async {
      await record(good: true, at: day(1));
      final row = (await db.attemptsFor(lesson.id)).single;

      expect(row.clarityScore, isNotNull);
      expect(row.paceScore, isNotNull);
      expect(row.plosiveScore, isNotNull);
      expect(row.wordsPerMinute, isNotNull);
    });

    test('the outbox payload carries what a server would need', () async {
      await record(good: true, at: day(1));
      final row = (await db.pendingSync()).single;

      expect(row.entityType, 'attempt');
      expect(row.payload, contains(lesson.id));
      expect(row.payload, contains('mastery_rank'));
    });
  });

  group('mastery over days', () {
    test('climbs one level per day', () async {
      for (var d = 1; d <= 3; d++) {
        await record(good: true, at: day(d));
      }
      expect((await repo.masteryFor(lesson.id)).level, MasteryLevel.gold);
    });

    test('a second attempt the same day does not promote again', () async {
      await record(good: true, at: day(1, hour: 9));
      final second = await record(good: true, at: day(1, hour: 21));

      expect(second.promotion.promoted, isFalse);
      expect(second.promotion.block, PromotionBlock.alreadyPromotedToday);
      expect((await repo.masteryFor(lesson.id)).level, MasteryLevel.bronze);
      // But the attempt is still recorded and still earns XP.
      expect(await db.attemptsFor(lesson.id), hasLength(2));
      expect(second.xpAwarded, greaterThan(0));
    });
  });

  group('vocal energy', () {
    test('a good attempt costs nothing', () async {
      final outcome = await record(good: true, at: day(1));

      expect(outcome.energyEvent, EnergyEvent.unchanged);
      expect(outcome.energy.bars, VocalEnergy.maxBars);
    });

    test('a poor attempt spends a bar and persists it', () async {
      final outcome = await record(good: false, at: day(1));

      expect(outcome.energyEvent, EnergyEvent.spent);
      expect((await repo.energy()).bars, VocalEnergy.maxBars - 1);
    });

    test(
      'rest restores without unblocking anything, because nothing blocks',
      () async {
        // Minutes apart, not hours: spacing attempts an hour apart lets the
        // meter regenerate faster than it drains, which is exactly what it is
        // supposed to do. Depletion is a hammering pattern.
        // 5 → -1 → 4 → -2 → 2 → -2 → 0 (the repeat penalty compounds).
        for (var i = 0; i < 3; i++) {
          await record(good: false, at: DateTime(2026, 9, 1, 10, i * 5));
        }
        expect((await repo.energy()).bars, 0);

        // The meter is empty and the next attempt still succeeds — the product
        // rule that energy never gates practice.
        final stillWorks = await record(
          good: true,
          at: DateTime(2026, 9, 1, 10, 20),
        );
        expect(stillWorks.promotion.promoted, isTrue);

        final rested = await repo.completeRest(
          now: DateTime(2026, 9, 1, 10, 25),
        );
        expect(rested.bars, 2);
      },
    );
  });

  group('streak', () {
    test('consecutive days extend it', () async {
      await record(good: true, at: day(1));
      final second = await record(good: true, at: day(2));

      expect(second.streak.event, StreakEvent.extended);
      expect(second.streak.currentStreak, 2);
    });

    test('a missed day is covered by a freeze', () async {
      await record(good: true, at: day(1));
      final third = await record(good: true, at: day(3));

      expect(third.streak.event, StreakEvent.savedByFreeze);
      expect((await db.streak()).freezesAvailable, 1);
    });
  });

  group('atomicity', () {
    test('a failed write leaves nothing behind', () async {
      // Reusing an attempt id violates the primary key mid-transaction. Every
      // earlier write in that transaction must roll back — a promotion whose
      // attempt did not land is an orphan the user cannot explain.
      await repo.recordAttempt(
        lesson: lesson,
        score: scoreOf(good: true),
        attemptId: 'duplicate',
        durationMs: 3600,
        now: day(1),
      );

      final masteryBefore = await repo.masteryFor(lesson.id);
      final xpBefore = await repo.xpToday(day(2));

      await expectLater(
        repo.recordAttempt(
          lesson: lesson,
          score: scoreOf(good: true),
          attemptId: 'duplicate',
          durationMs: 3600,
          now: day(2),
        ),
        throwsA(anything),
      );

      expect(await repo.masteryFor(lesson.id), masteryBefore);
      expect(await repo.xpToday(day(2)), xpBefore);
      expect(await db.attemptsFor(lesson.id), hasLength(1));
    });
  });

  group('xp', () {
    test('rewards turning up more than scoring well', () async {
      // A rough session must still be worth doing. Mastery expresses quality;
      // XP expressing it again would punish the same bad day twice.
      final poor = xpFor(score: 30, promoted: false);
      final good = xpFor(score: 95, promoted: false);

      expect(poor, greaterThan(0));
      expect(good - poor, lessThan(poor));
    });

    test('a promotion is worth a real bonus', () {
      expect(
        xpFor(score: 80, promoted: true),
        greaterThan(xpFor(score: 80, promoted: false)),
      );
    });
  });

  group('schema migration', () {
    test('the energy row exists on a fresh database', () async {
      final energy = await repo.energy();
      expect(energy.bars, VocalEnergy.maxBars);
      expect(energy.isFull, isTrue);
    });

    test('delete-my-data resets the meter to full, not empty', () async {
      await record(good: false, at: day(1));
      await db.deleteAllUserData();

      expect((await repo.energy()).bars, VocalEnergy.maxBars);
    });
  });
}
