/// The mastery ladder.
///
/// This file is the pedagogical core of the product, so the rules are written
/// out rather than scattered across the UI:
///
/// * A lesson is promoted one level when a **fresh** attempt scores at or above
///   the next level's threshold. Scores above two levels up do not skip — the
///   ladder is climbed one rung at a time, so a lucky take cannot vault someone
///   past material they have not internalised.
/// * A lesson may be promoted **at most once per calendar day**. Voice is a
///   motor skill and consolidates during sleep; letting someone grind a unit in
///   an evening would produce a number that does not describe their ability.
/// * Levels **decay** on a spacing schedule but never below [bronze] once
///   earned. Decay exists to route review, not to punish absence.
library;

/// Where a single lesson sits on the ladder.
enum MasteryLevel {
  /// Never passed. Not the same as "not attempted" — see [Mastery.attempts].
  locked(0, 'Locked', null),
  bronze(1, 'Bronze', 60),
  silver(2, 'Silver', 70),
  gold(3, 'Gold', 78),
  diamond(4, 'Diamond', 85),
  master(5, 'Master', 90);

  const MasteryLevel(this.rank, this.label, this.threshold);

  /// 0..5. Used for ordering and for the ring fill on the skill tree.
  final int rank;

  final String label;

  /// Score required to *reach* this level. Null for [locked], which is where
  /// everyone starts and which has no entry requirement.
  final int? threshold;

  MasteryLevel? get next =>
      rank >= master.rank ? null : MasteryLevel.values[rank + 1];

  MasteryLevel? get previous =>
      rank <= locked.rank ? null : MasteryLevel.values[rank - 1];

  bool operator >=(MasteryLevel other) => rank >= other.rank;
  bool operator >(MasteryLevel other) => rank > other.rank;
  bool operator <=(MasteryLevel other) => rank <= other.rank;
  bool operator <(MasteryLevel other) => rank < other.rank;

  static MasteryLevel fromRank(int rank) =>
      MasteryLevel.values[rank.clamp(0, master.rank)];
}

/// Why a promotion did not happen. Surfaced to the user verbatim, so the
/// wording here is product copy, not developer text.
enum PromotionBlock {
  /// Score was below the next threshold.
  scoreTooLow,

  /// Already promoted today. The most common case, and the one that most needs
  /// a kind explanation.
  alreadyPromotedToday,

  /// Already at [MasteryLevel.master].
  atCeiling,
}

/// Outcome of applying an attempt to a lesson's mastery state.
class PromotionResult {
  const PromotionResult({
    required this.before,
    required this.after,
    this.block,
  });

  final MasteryLevel before;
  final MasteryLevel after;

  /// Null when a promotion occurred.
  final PromotionBlock? block;

  bool get promoted => after > before;

  @override
  String toString() =>
      'PromotionResult($before -> $after${block == null ? '' : ', $block'})';
}

/// A lesson's mastery state, and the rules that move it.
///
/// Immutable: [applyAttempt] returns a new instance rather than mutating, so
/// the scoring pipeline can evaluate a hypothetical attempt without committing
/// it (used by the "what would this score get me" hint on the feedback screen).
class Mastery {
  const Mastery({
    required this.level,
    required this.attempts,
    required this.bestScore,
    this.lastPromotedOn,
    this.lastAttemptedOn,
  });

  const Mastery.fresh()
    : level = MasteryLevel.locked,
      attempts = 0,
      bestScore = 0,
      lastPromotedOn = null,
      lastAttemptedOn = null;

  final MasteryLevel level;
  final int attempts;
  final int bestScore;

  /// Date-only (local). Compared by calendar day, never by elapsed hours — a
  /// user practising at 11pm and again at 8am has slept, which is the thing
  /// the rule is actually about.
  final DateTime? lastPromotedOn;
  final DateTime? lastAttemptedOn;

  bool get everAttempted => attempts > 0;

  /// Whether a promotion is available today at all, regardless of score.
  bool canPromoteOn(DateTime day) {
    if (level.next == null) return false;
    final last = lastPromotedOn;
    if (last == null) return true;
    return !_sameDay(last, day);
  }

  /// Applies a scored attempt and returns the resulting state plus a reason if
  /// no promotion occurred.
  (Mastery, PromotionResult) applyAttempt({
    required int score,
    required DateTime at,
  }) {
    final day = _dateOnly(at);
    final nextLevel = level.next;

    PromotionBlock? block;
    if (nextLevel == null) {
      block = PromotionBlock.atCeiling;
    } else if (!canPromoteOn(day)) {
      block = PromotionBlock.alreadyPromotedToday;
    } else if (score < nextLevel.threshold!) {
      block = PromotionBlock.scoreTooLow;
    }

    final promotedLevel = block == null ? nextLevel! : level;

    final updated = Mastery(
      level: promotedLevel,
      attempts: attempts + 1,
      bestScore: score > bestScore ? score : bestScore,
      lastPromotedOn: block == null ? day : lastPromotedOn,
      lastAttemptedOn: day,
    );

    return (
      updated,
      PromotionResult(before: level, after: promotedLevel, block: block),
    );
  }

  /// Drops one level as a spacing-interval lapse. Never falls below [bronze]
  /// once earned, and never touches a lesson that was never passed.
  Mastery decayed() {
    if (level <= MasteryLevel.bronze) return this;
    return Mastery(
      level: level.previous!,
      attempts: attempts,
      bestScore: bestScore,
      lastPromotedOn: lastPromotedOn,
      lastAttemptedOn: lastAttemptedOn,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  bool operator ==(Object other) =>
      other is Mastery &&
      other.level == level &&
      other.attempts == attempts &&
      other.bestScore == bestScore &&
      other.lastPromotedOn == lastPromotedOn &&
      other.lastAttemptedOn == lastAttemptedOn;

  @override
  int get hashCode =>
      Object.hash(level, attempts, bestScore, lastPromotedOn, lastAttemptedOn);
}
