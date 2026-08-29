import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/domain/curriculum/mastery.dart';

void main() {
  late ResonanceDatabase db;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('mastery persistence', () {
    test('an unattempted lesson reads as fresh, not null', () async {
      final mastery = await db.masteryFor('t1u3l1-plosive-precision');

      expect(mastery.level, MasteryLevel.locked);
      expect(mastery.attempts, 0);
      expect(mastery.everAttempted, isFalse);
    });

    test('round-trips through the database unchanged', () async {
      final original = Mastery(
        level: MasteryLevel.gold,
        attempts: 7,
        bestScore: 81,
        lastPromotedOn: DateTime(2026, 8, 27),
        lastAttemptedOn: DateTime(2026, 8, 28),
      );

      await db.saveMastery(
        lessonId: 't1u3l1-plosive-precision',
        unitId: 't1u3-articulation',
        mastery: original,
      );

      expect(await db.masteryFor('t1u3l1-plosive-precision'), original);
    });

    test('saving twice updates rather than duplicating', () async {
      var mastery = const Mastery.fresh();
      final day = DateTime(2026, 9, 1);

      for (var i = 0; i < 3; i++) {
        final (next, _) = mastery.applyAttempt(
          score: 90,
          at: day.add(Duration(days: i)),
        );
        mastery = next;
        await db.saveMastery(
          lessonId: 'lesson-a',
          unitId: 'unit-a',
          mastery: mastery,
        );
      }

      final all = await db.masteryForUnit('unit-a');
      expect(all, hasLength(1));
      expect(all['lesson-a']!.level, MasteryLevel.gold);
      expect(all['lesson-a']!.attempts, 3);
    });

    test('masteryForUnit only returns that unit', () async {
      await db.saveMastery(
        lessonId: 'a',
        unitId: 'unit-a',
        mastery: const Mastery.fresh(),
      );
      await db.saveMastery(
        lessonId: 'b',
        unitId: 'unit-b',
        mastery: const Mastery.fresh(),
      );

      expect(await db.masteryForUnit('unit-a'), hasLength(1));
    });
  });

  group('xp', () {
    test('accumulates within a day rather than overwriting', () async {
      final day = DateTime(2026, 9, 1);

      await db.addXp(day: day, amount: 20);
      await db.addXp(day: day, amount: 15);
      await db.addXp(day: day, amount: 5);

      expect(await db.xpOn(day), 40);
    });

    test('keeps days separate', () async {
      await db.addXp(day: DateTime(2026, 9, 1), amount: 20);
      await db.addXp(day: DateTime(2026, 9, 2), amount: 30);

      expect(await db.xpOn(DateTime(2026, 9, 1)), 20);
      expect(await db.xpOn(DateTime(2026, 9, 2)), 30);
    });

    test('a day with no practice reads zero', () async {
      expect(await db.xpOn(DateTime(2026, 9, 9)), 0);
    });
  });

  group('streak', () {
    test('the singleton row exists on a fresh database', () async {
      final streak = await db.streak();

      expect(streak.currentStreak, 0);
      expect(streak.freezesAvailable, 2);
      expect(streak.lastPracticeDay, isNull);
    });

    test('updates in place', () async {
      await db.saveStreak(
        StreakStateCompanion(
          currentStreak: const Value(12),
          longestStreak: const Value(12),
          lastPracticeDay: Value(DateTime(2026, 9, 3)),
        ),
      );

      final streak = await db.streak();
      expect(streak.currentStreak, 12);
      expect(streak.lastPracticeDay, DateTime(2026, 9, 3));
      expect(streak.freezesAvailable, 2);
    });
  });

  group('outbox', () {
    test('replays in the order it was queued', () async {
      for (final entity in ['attempt', 'lesson_progress', 'streak']) {
        await db.enqueue(
          entityType: entity,
          entityId: '$entity-1',
          payload: '{}',
          at: DateTime(2026, 9, 1),
        );
      }

      final pending = await db.pendingSync();
      expect(pending.map((r) => r.entityType).toList(), [
        'attempt',
        'lesson_progress',
        'streak',
      ]);
      expect(pending[0].seq, lessThan(pending[1].seq));
      expect(pending[1].seq, lessThan(pending[2].seq));
    });

    test('sent rows are removed, unsent rows remain', () async {
      await db.enqueue(entityType: 'a', entityId: '1', payload: '{}');
      await db.enqueue(entityType: 'b', entityId: '2', payload: '{}');

      final pending = await db.pendingSync();
      await db.markSent([pending.first.seq]);

      final remaining = await db.pendingSync();
      expect(remaining, hasLength(1));
      expect(remaining.single.entityType, 'b');
    });

    test('a failure is recorded rather than retried silently', () async {
      await db.enqueue(entityType: 'a', entityId: '1', payload: '{}');
      final row = (await db.pendingSync()).single;

      await db.markFailed(row.seq, 'HTTP 503');

      final after = (await db.pendingSync()).single;
      expect(after.lastError, 'HTTP 503');
      expect(after.seq, row.seq);
    });
  });

  group('delete my data', () {
    test('leaves nothing behind, including the outbox', () async {
      await db.saveMastery(
        lessonId: 'a',
        unitId: 'unit-a',
        mastery: const Mastery(
          level: MasteryLevel.gold,
          attempts: 5,
          bestScore: 80,
        ),
      );
      await db.insertAttempt(
        AttemptsCompanion.insert(
          id: 'attempt-1',
          lessonId: 'a',
          recordedAt: DateTime(2026, 9, 1),
          durationMs: 12000,
          score: 80,
        ),
      );
      await db.addXp(day: DateTime(2026, 9, 1), amount: 50);
      await db.enqueue(
        entityType: 'attempt',
        entityId: 'attempt-1',
        payload: '{}',
      );
      await db.saveStreak(const StreakStateCompanion(currentStreak: Value(9)));

      await db.deleteAllUserData();

      expect(await db.attemptsFor('a'), isEmpty);
      expect(await db.masteryForUnit('unit-a'), isEmpty);
      expect(await db.xpOn(DateTime(2026, 9, 1)), 0);
      expect(await db.pendingSync(), isEmpty);

      final streak = await db.streak();
      expect(streak.currentStreak, 0);
      expect(streak.freezesAvailable, 2);
    });
  });

  group('attempt history', () {
    test('returns newest first', () async {
      for (var i = 0; i < 3; i++) {
        await db.insertAttempt(
          AttemptsCompanion.insert(
            id: 'attempt-$i',
            lessonId: 'a',
            recordedAt: DateTime(2026, 9, 1 + i),
            durationMs: 10000,
            score: 60 + i,
          ),
        );
      }

      final history = await db.attemptsFor('a');
      expect(history.map((a) => a.id).toList(), [
        'attempt-2',
        'attempt-1',
        'attempt-0',
      ]);
    });

    test('score components are kept alongside the composite', () async {
      await db.insertAttempt(
        AttemptsCompanion.insert(
          id: 'attempt-1',
          lessonId: 'a',
          recordedAt: DateTime(2026, 9, 1),
          durationMs: 11000,
          score: 74,
          clarityScore: const Value(81),
          paceScore: const Value(70),
          plosiveScore: const Value(68),
          wordsPerMinute: const Value(148),
        ),
      );

      final attempt = (await db.attemptsFor('a')).single;
      expect(attempt.clarityScore, 81);
      expect(attempt.paceScore, 70);
      expect(attempt.plosiveScore, 68);
      expect(attempt.wordsPerMinute, 148);
    });
  });
}
