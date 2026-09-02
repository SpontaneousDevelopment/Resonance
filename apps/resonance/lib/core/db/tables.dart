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

/// One recording within an attempt.
///
/// A child of [Attempts] rather than more columns on it: a lesson has N takes
/// and N is content, not schema. Written in the same transaction as its parent
/// — an attempt whose takes half-landed is worse than one that failed outright,
/// because the composite score would be computed from a subset and look real.
class TakeRecords extends Table {
  TextColumn get attemptId =>
      text().references(Attempts, #id, onDelete: KeyAction.cascade)();

  /// Position in the lesson's take list, 0-based. Recording order is the
  /// lesson's order; there is no backward navigation between takes.
  IntColumn get takeIndex => integer()();

  /// The authored label, copied rather than referenced. Content can be re-worded
  /// later, and a stored attempt should still say what the user was asked for
  /// at the time.
  TextColumn get label => text()();

  IntColumn get score => integer().nullable()();
  IntColumn get wordsPerMinute => integer().nullable()();
  TextColumn get transcript => text().nullable()();

  /// Path to this take's audio. One file per take, all deleted together.
  TextColumn get audioPath => text().nullable()();

  IntColumn get durationMs => integer()();

  /// False when the take only got through because it was the third consecutive
  /// failure of the sanity gate and the user chose to continue. Recorded so the
  /// rubric's honest low score is distinguishable from a gate that gave up.
  BoolColumn get passedSanity => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {attemptId, takeIndex};
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

  /// Set when the server has permanently rejected this row.
  ///
  /// Persisted rather than held in memory: a parked row sits at the head of the
  /// queue, so anything that does not skip it blocks every row behind it — and
  /// an in-memory set is lost on relaunch, which would re-block the queue every
  /// session. Kept rather than deleted so a payload bug stays diagnosable.
  BoolColumn get parked => boolean().withDefault(const Constant(false))();
}

/// The Vocal Energy meter. A single row, id 0.
///
/// Separate from [StreakState] because they answer different questions and
/// change on different cadences — the streak moves once a day, energy moves
/// several times a session — and folding them together would make every
/// attempt rewrite the streak row for no reason.
@DataClassName('EnergyRow')
class EnergyState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  IntColumn get bars => integer().withDefault(const Constant(5))();

  /// When a bar was last spent. Null when the meter is full.
  DateTimeColumn get lastSpentAt => dateTime().nullable()();

  /// The lesson currently being struggled with, and how many consecutive low
  /// scores it has taken. Drives the double cost on a repeat.
  TextColumn get consecutiveLowLessonId => text().nullable()();
  IntColumn get consecutiveLowCount =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
