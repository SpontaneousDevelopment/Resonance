import 'package:drift/drift.dart';

/// Local persistence schema.
///
/// Drift is the **source of truth** on device. Supabase is a replica this
/// pushes to, not the other way round — a user with no signal for a week loses
/// nothing, and every score, streak day and mastery level is computed locally
/// before it is ever sent anywhere.
///
/// Two rules hold throughout:
///
/// * **Nothing here references curriculum content by anything but id.** The
///   curriculum ships in the bundle and is replaced wholesale on update;
///   progress must survive a lesson being reworded or retitled.
/// * **Dates that drive the streak and the once-per-day rule are stored as
///   local calendar days**, not instants. The rules are about sleep and
///   habit, not elapsed hours. Storing a UTC timestamp and converting on read
///   would put a user in Auckland on a different day to the one they lived.

/// Per-lesson mastery. One row per lesson the user has ever attempted; a
/// lesson with no row has never been touched.
@DataClassName('LessonProgressRow')
class LessonProgress extends Table {
  TextColumn get lessonId => text()();
  TextColumn get unitId => text()();

  /// 0..5, matching `MasteryLevel.rank`. Stored as an int rather than an enum
  /// name so inserting a level between two existing ones later is a migration
  /// of data, not of strings.
  IntColumn get masteryRank => integer().withDefault(const Constant(0))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();

  /// Local calendar day, midnight. Null until the first promotion.
  DateTimeColumn get lastPromotedOn => dateTime().nullable()();
  DateTimeColumn get lastAttemptedOn => dateTime().nullable()();

  /// Spaced repetition. [dueOn] is when this lesson resurfaces in Refresh;
  /// [stabilityDays] is the current interval, widening on each clean pass.
  DateTimeColumn get dueOn => dateTime().nullable()();
  IntColumn get stabilityDays => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {lessonId};
}

/// Every scored attempt, kept in full.
///
/// Retained locally so the user can see their own history and hear their own
/// improvement — the single most motivating thing in a craft app. Only the
/// numeric summary is ever synced; see [syncedAt].
@DataClassName('AttemptRow')
class Attempts extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();

  DateTimeColumn get recordedAt => dateTime()();
  IntColumn get durationMs => integer()();

  /// 0..100 composite, and the components that produced it. Stored separately
  /// so a rubric reweighting can be recomputed against historical attempts
  /// rather than invalidating them.
  IntColumn get score => integer()();
  IntColumn get clarityScore => integer().nullable()();
  IntColumn get paceScore => integer().nullable()();
  IntColumn get plosiveScore => integer().nullable()();

  IntColumn get wordsPerMinute => integer().nullable()();

  /// What the recogniser heard. Used for the coach note and for showing the
  /// user which words were dropped.
  TextColumn get transcript => text().nullable()();

  /// The LLM coach note, once it arrives. Null while pending or offline — the
  /// feedback screen is fully usable without it.
  TextColumn get coachNote => text().nullable()();

  /// Path to the recording on disk. Encrypted at rest; the file is deleted
  /// when the attempt is, and nothing outside this device ever reads it.
  TextColumn get audioPath => text().nullable()();

  /// When the numeric summary reached the server. Null means unsynced.
  /// The audio itself is never synced by this field — sharing a recording is a
  /// separate, explicit action.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The streak. A single row, id 0.
@DataClassName('StreakRow')
class StreakState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// The last local calendar day with a completed session.
  DateTimeColumn get lastPracticeDay => dateTime().nullable()();

  /// Freezes in hand. A freeze is spent automatically on the first missed day,
  /// which is the whole point — the user should discover it was saved, not be
  /// asked to save it.
  IntColumn get freezesAvailable => integer().withDefault(const Constant(2))();
  DateTimeColumn get freezeLastEarnedOn => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// XP per calendar day. Drives the streak calendar and, later, weekly league
/// standing.
@DataClassName('DailyXpRow')
class DailyXp extends Table {
  DateTimeColumn get day => dateTime()();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get sessionsCompleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day};
}

/// The sync outbox.
///
/// Every mutation that must reach the server lands here first with a monotonic
/// [seq], and is replayed in order on reconnect. This is what makes the app
/// genuinely offline-first rather than offline-tolerant: the UI never waits on
/// a network call, and a failed send is a retry rather than lost work.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  /// e.g. 'attempt', 'lesson_progress', 'streak'.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// JSON payload, already shaped for the server.
  TextColumn get payload => text()();

  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
