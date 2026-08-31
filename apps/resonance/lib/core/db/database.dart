import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/curriculum/mastery.dart';
import '../../domain/progress/vocal_energy.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [LessonProgress, Attempts, StreakState, DailyXp, Outbox, EnergyState],
)
class ResonanceDatabase extends _$ResonanceDatabase {
  ResonanceDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'resonance'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedSingletons();
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2 adds the Vocal Energy meter. Additive only — no existing
      // column changes — so a user's progress survives untouched. The new row
      // is seeded full: an upgrade must never hand someone a depleted meter.
      if (from < 2) {
        await m.createTable(energyState);
      }
      if (from < 3) {
        // Additive: existing queued rows default to un-parked, which is what
        // they were.
        await m.addColumn(outbox, outbox.parked);
      }
      await _seedSingletons();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Cheap, and it is the only thing standing between a missing singleton
      // and a `getSingle` that throws on every read for the life of the app.
      await _seedSingletons();
    },
  );

  /// Ensures every singleton row exists. Idempotent.
  Future<void> _seedSingletons() async {
    await into(streakState).insert(
      const StreakStateCompanion(id: Value(0)),
      mode: InsertMode.insertOrIgnore,
    );
    await into(energyState).insert(
      const EnergyStateCompanion(id: Value(0)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  // ── Mastery ─────────────────────────────────────────────────────────────

  /// Reads a lesson's mastery, returning a fresh state for a lesson never
  /// attempted rather than null. Callers should not have to distinguish
  /// "never touched" from "touched and failed" at the type level — the
  /// [Mastery.attempts] count already carries that.
  Future<Mastery> masteryFor(String lessonId) async {
    final row = await (select(
      lessonProgress,
    )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();
    return row == null ? const Mastery.fresh() : _toMastery(row);
  }

  /// All mastery rows for a unit, keyed by lesson id.
  Future<Map<String, Mastery>> masteryForUnit(String unitId) async {
    final rows = await (select(
      lessonProgress,
    )..where((t) => t.unitId.equals(unitId))).get();
    return {for (final row in rows) row.lessonId: _toMastery(row)};
  }

  /// Every lesson's mastery, for evaluating the whole tree at once.
  Future<Map<String, Mastery>> allMastery() async {
    final rows = await select(lessonProgress).get();
    return {for (final row in rows) row.lessonId: _toMastery(row)};
  }

  /// Watches every lesson's mastery. Backs the skill tree, which needs the
  /// whole map to evaluate gating rather than one unit at a time.
  Stream<Map<String, Mastery>> watchAllMastery() => select(lessonProgress)
      .watch()
      .map((rows) => {for (final row in rows) row.lessonId: _toMastery(row)});

  /// Watches a unit's mastery so the tree updates the moment an attempt lands,
  /// with no manual invalidation.
  Stream<Map<String, Mastery>> watchMasteryForUnit(String unitId) {
    return (select(lessonProgress)..where((t) => t.unitId.equals(unitId)))
        .watch()
        .map((rows) => {for (final row in rows) row.lessonId: _toMastery(row)});
  }

  /// Persists a mastery state. Upsert, because the first attempt at a lesson
  /// creates its row.
  Future<void> saveMastery({
    required String lessonId,
    required String unitId,
    required Mastery mastery,
  }) {
    return into(lessonProgress).insertOnConflictUpdate(
      LessonProgressCompanion.insert(
        lessonId: lessonId,
        unitId: unitId,
        masteryRank: Value(mastery.level.rank),
        attempts: Value(mastery.attempts),
        bestScore: Value(mastery.bestScore),
        lastPromotedOn: Value(mastery.lastPromotedOn),
        lastAttemptedOn: Value(mastery.lastAttemptedOn),
      ),
    );
  }

  static Mastery _toMastery(LessonProgressRow row) => Mastery(
    level: MasteryLevel.fromRank(row.masteryRank),
    attempts: row.attempts,
    bestScore: row.bestScore,
    lastPromotedOn: row.lastPromotedOn,
    lastAttemptedOn: row.lastAttemptedOn,
  );

  // ── Attempts ────────────────────────────────────────────────────────────

  Future<void> insertAttempt(AttemptsCompanion attempt) =>
      into(attempts).insert(attempt);

  /// A lesson's history, newest first. Powers "hear your first take next to
  /// your latest", which is the feature that makes months of work visible.
  Future<List<AttemptRow>> attemptsFor(String lessonId, {int limit = 20}) {
    return (select(attempts)
          ..where((t) => t.lessonId.equals(lessonId))
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)])
          ..limit(limit))
        .get();
  }

  // ── Streak ──────────────────────────────────────────────────────────────

  Future<StreakRow> streak() =>
      (select(streakState)..where((t) => t.id.equals(0))).getSingle();

  Stream<StreakRow> watchStreak() =>
      (select(streakState)..where((t) => t.id.equals(0))).watchSingle();

  Future<void> saveStreak(StreakStateCompanion streak) =>
      (update(streakState)..where((t) => t.id.equals(0))).write(streak);

  // ── XP ──────────────────────────────────────────────────────────────────

  /// Adds XP to a day, creating the row if needed.
  Future<void> addXp({required DateTime day, required int amount}) async {
    await into(dailyXp).insert(
      DailyXpCompanion.insert(
        day: day,
        xp: Value(amount),
        sessionsCompleted: const Value(1),
      ),
      onConflict: DoUpdate(
        (old) => DailyXpCompanion.custom(
          xp: old.xp + Constant(amount),
          sessionsCompleted: old.sessionsCompleted + const Constant(1),
        ),
        target: [dailyXp.day],
      ),
    );
  }

  Future<int> xpOn(DateTime day) async {
    final row = await (select(
      dailyXp,
    )..where((t) => t.day.equals(day))).getSingleOrNull();
    return row?.xp ?? 0;
  }

  // ── Vocal Energy ────────────────────────────────────────────────────────

  Future<EnergyRow> energy() =>
      (select(energyState)..where((t) => t.id.equals(0))).getSingle();

  Stream<EnergyRow> watchEnergy() =>
      (select(energyState)..where((t) => t.id.equals(0))).watchSingle();

  Future<void> saveEnergy(EnergyStateCompanion energy) =>
      (update(energyState)..where((t) => t.id.equals(0))).write(energy);

  // ── Outbox ──────────────────────────────────────────────────────────────

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String payload,
    DateTime? at,
  }) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        payload: payload,
        queuedAt: at ?? DateTime.now(),
      ),
    );
  }

  /// The next batch to send, in the order it was queued. Order matters: a
  /// mastery promotion that arrives before the attempt that caused it would be
  /// rejected by the server's own validation.
  Future<List<OutboxRow>> pendingSync({int limit = 50}) {
    return (select(outbox)
          ..where((t) => t.parked.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)])
          ..limit(limit))
        .get();
  }

  /// Every row, including parked ones. For diagnostics.
  Future<List<OutboxRow>> allOutboxRows() =>
      (select(outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  /// Marks a row as permanently unsendable so it stops blocking the queue.
  Future<void> markParked(int seq, String error) {
    return (update(outbox)..where((t) => t.seq.equals(seq))).write(
      OutboxCompanion(parked: const Value(true), lastError: Value(error)),
    );
  }

  Future<void> markSent(List<int> seqs) =>
      (delete(outbox)..where((t) => t.seq.isIn(seqs))).go();

  /// Records a failed send so a poison payload can be spotted rather than
  /// retried forever in silence.
  Future<void> markFailed(int seq, String error) {
    return (update(outbox)..where((t) => t.seq.equals(seq))).write(
      OutboxCompanion(
        attemptCount: const Value.absent(),
        lastError: Value(error),
      ),
    );
  }

  // ── Data deletion ───────────────────────────────────────────────────────

  /// Erases everything. Backs the "delete my data" path, which must work
  /// offline and must leave nothing behind — including the outbox, so a
  /// deletion cannot be followed by a queued upload of the data just deleted.
  Future<void> deleteAllUserData() async {
    await transaction(() async {
      await delete(attempts).go();
      await delete(lessonProgress).go();
      await delete(dailyXp).go();
      await delete(outbox).go();
      await (update(energyState)..where((t) => t.id.equals(0))).write(
        const EnergyStateCompanion(
          bars: Value(VocalEnergy.maxBars),
          lastSpentAt: Value(null),
          consecutiveLowLessonId: Value(null),
          consecutiveLowCount: Value(0),
        ),
      );
      await (update(streakState)..where((t) => t.id.equals(0))).write(
        const StreakStateCompanion(
          currentStreak: Value(0),
          longestStreak: Value(0),
          lastPracticeDay: Value(null),
          freezesAvailable: Value(2),
          freezeLastEarnedOn: Value(null),
        ),
      );
    });
  }
}

final databaseProvider = Provider<ResonanceDatabase>((ref) {
  final db = ResonanceDatabase();
  ref.onDispose(db.close);
  return db;
});
