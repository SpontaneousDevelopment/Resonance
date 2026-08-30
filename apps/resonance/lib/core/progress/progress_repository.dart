import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/curriculum/curriculum.dart';
import '../../domain/curriculum/mastery.dart';
import '../../domain/progress/streak.dart';
import '../../domain/progress/vocal_energy.dart';
import '../../domain/scoring/rubric.dart';
import '../db/database.dart';

/// Everything one finished attempt changed.
///
/// Returned as a single value so the feedback screen renders the whole outcome
/// from one call, rather than issuing four reads and hoping they agree.
class SessionOutcome {
  const SessionOutcome({
    required this.promotion,
    required this.streak,
    required this.xpAwarded,
    required this.energy,
    required this.energyEvent,
  });

  final PromotionResult promotion;
  final StreakOutcome streak;
  final int xpAwarded;
  final VocalEnergy energy;
  final EnergyEvent energyEvent;
}

/// XP for one attempt.
///
/// Weighted toward *turning up* rather than toward scoring well: a beginner
/// having a rough session still earns most of what a strong one does. XP is a
/// measure of practice, and the mastery ladder is where quality is expressed —
/// making XP a second quality score would say the same thing twice and punish
/// the same bad day twice.
int xpFor({required int score, required bool promoted}) {
  const base = 10;
  final quality = (score / 100 * 5).round();
  final promotionBonus = promoted ? 15 : 0;
  return base + quality + promotionBonus;
}

/// The seam between the database and the domain.
///
/// The domain types own every rule; this class owns transactions and mapping.
/// Nothing here decides anything — if a decision appears in this file it is in
/// the wrong place.
class ProgressRepository {
  ProgressRepository(this._db, {this.streaks = const StreakEngine()});

  final ResonanceDatabase _db;
  final StreakEngine streaks;

  Future<Mastery> masteryFor(String lessonId) => _db.masteryFor(lessonId);

  Future<Map<String, Mastery>> masteryForUnit(String unitId) =>
      _db.masteryForUnit(unitId);

  /// Every lesson's mastery, for evaluating the whole tree at once.
  Future<Map<String, Mastery>> allMastery() => _db.allMastery();

  Stream<Map<String, Mastery>> watchAllMastery() => _db.watchAllMastery();

  Future<VocalEnergy> energy() async => _toEnergy(await _db.energy());

  Stream<VocalEnergy> watchEnergy() => _db.watchEnergy().map(_toEnergy);

  Stream<StreakRow> watchStreak() => _db.watchStreak();

  Future<int> xpToday(DateTime now) => _db.xpOn(_dayOf(now));

  /// Commits one attempt and everything it changed.
  ///
  /// A single transaction, deliberately. A mastery promotion whose attempt did
  /// not land is an orphan the user cannot explain, and the outbox's ordering
  /// guarantee — that a promotion never reaches the server before the attempt
  /// that caused it — only holds if they commit together.
  Future<SessionOutcome> recordAttempt({
    required Lesson lesson,
    required AttemptScore score,
    required String attemptId,
    required int durationMs,
    String? transcript,
    String? audioPath,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final day = _dayOf(at);

    return _db.transaction(() async {
      final previousMastery = await _db.masteryFor(lesson.id);
      final (nextMastery, promotion) = previousMastery.applyAttempt(
        score: score.composite,
        at: at,
      );

      final previousEnergy = _toEnergy(await _db.energy());
      final (nextEnergy, energyEvent) = previousEnergy.applyAttempt(
        lessonId: lesson.id,
        score: score.composite,
        at: at,
      );

      final streakRow = await _db.streak();
      final streak = streaks.practise(
        at: at,
        currentStreak: streakRow.currentStreak,
        longestStreak: streakRow.longestStreak,
        freezesAvailable: streakRow.freezesAvailable,
        lastPracticeDay: streakRow.lastPracticeDay,
      );

      final xp = xpFor(score: score.composite, promoted: promotion.promoted);

      await _db.insertAttempt(
        AttemptsCompanion.insert(
          id: attemptId,
          lessonId: lesson.id,
          recordedAt: at,
          durationMs: durationMs,
          score: score.composite,
          clarityScore: Value(score.component('Clarity')?.score),
          paceScore: Value(score.component('Pace')?.score),
          plosiveScore: Value(score.component('Plosive control')?.score),
          wordsPerMinute: Value(score.measurements.wordsPerMinute.round()),
          transcript: Value(transcript),
          audioPath: Value(audioPath),
        ),
      );

      await _db.saveMastery(
        lessonId: lesson.id,
        unitId: lesson.unitId,
        mastery: nextMastery,
      );

      await _db.addXp(day: day, amount: xp);

      await _db.saveStreak(
        StreakStateCompanion(
          currentStreak: Value(streak.currentStreak),
          longestStreak: Value(streak.longestStreak),
          freezesAvailable: Value(streak.freezesRemaining),
          lastPracticeDay: Value(streak.lastPracticeDay),
        ),
      );

      await _saveEnergy(nextEnergy);

      // Enqueue-only for now: nothing drains this yet. Writing the rows from
      // the start means the sync consumer, when it arrives, has real history to
      // replay rather than a gap where the first weeks of use should be.
      await _db.enqueue(
        entityType: 'attempt',
        entityId: attemptId,
        payload: jsonEncode({
          'lesson_id': lesson.id,
          'recorded_at': at.toIso8601String(),
          'score': score.composite,
          'mastery_rank': nextMastery.level.rank,
          'xp': xp,
        }),
        at: at,
      );

      return SessionOutcome(
        promotion: promotion,
        streak: streak,
        xpAwarded: xp,
        energy: nextEnergy,
        energyEvent: energyEvent,
      );
    });
  }

  /// Records a completed rest exercise.
  Future<VocalEnergy> completeRest({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final restored = (await energy()).afterRest(at);
    await _saveEnergy(restored);
    return restored;
  }

  Future<void> _saveEnergy(VocalEnergy energy) => _db.saveEnergy(
    EnergyStateCompanion(
      bars: Value(energy.bars),
      lastSpentAt: Value(energy.lastSpentAt),
      consecutiveLowLessonId: Value(energy.consecutiveLowLessonId),
      consecutiveLowCount: Value(energy.consecutiveLowCount),
    ),
  );

  static VocalEnergy _toEnergy(EnergyRow row) => VocalEnergy(
    bars: row.bars,
    lastSpentAt: row.lastSpentAt,
    consecutiveLowLessonId: row.consecutiveLowLessonId,
    consecutiveLowCount: row.consecutiveLowCount,
  );

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);
