/// Decides which lessons inside a unit are open.
///
/// The unit-level rule ([UnlockEvaluator]) says whether you may enter a unit at
/// all. This says where you may start once you are inside one, and it is a
/// deliberately lower bar: unit-to-unit gating asks for Silver across most of a
/// unit, because crossing into new material should require evidence of
/// retention. Sequencing *within* a unit you have already unlocked is a
/// different question — it exists so lessons are met in the order they were
/// written, not to make you prove anything twice. One passing attempt is
/// enough.
library;

import 'curriculum.dart';
import 'mastery.dart';

/// Why a lesson is in the state it is. Surfaced to the user, so these are
/// distinct for a reason: "you have not got here yet" and "this lesson has no
/// clip chosen" are different facts and a padlock for both would be a lie about
/// one of them.
enum LessonLockReason {
  /// Enterable.
  unlocked,

  /// The unit itself is closed, so nothing inside it is reachable.
  unitLocked,

  /// The lesson before this one has not been passed yet.
  previousLessonIncomplete,

  /// Written, but its reference clip has not been chosen. Nothing the user
  /// does opens this; it is waiting on a decision, not on practice.
  awaitingContent,
}

class LessonUnlockState {
  const LessonUnlockState({
    required this.lessonId,
    required this.reason,
    this.blockingLessonId,
    this.blockingLessonTitle,
  });

  final String lessonId;
  final LessonLockReason reason;

  /// The lesson still holding this one closed, so the UI can name it rather
  /// than showing a bare padlock.
  final String? blockingLessonId;
  final String? blockingLessonTitle;

  bool get isOpen => reason == LessonLockReason.unlocked;
}

class LessonUnlockEvaluator {
  const LessonUnlockEvaluator();

  /// What the previous lesson must have reached, at its best, for the next to
  /// open.
  ///
  /// Bronze — one attempt that passed. Compare [UnlockEvaluator.requiredLevel],
  /// which is Silver, and applies to entering a *new* unit.
  static const requiredLevel = MasteryLevel.bronze;

  /// Evaluates every lesson in [unit].
  ///
  /// [mastery] is keyed by lesson id; a missing entry means never attempted.
  Map<String, LessonUnlockState> evaluate({
    required Unit unit,
    required bool unitIsOpen,
    required Map<String, Mastery> mastery,
  }) {
    final states = <String, LessonUnlockState>{};

    for (var i = 0; i < unit.lessons.length; i++) {
      final lesson = unit.lessons[i];
      states[lesson.id] = _stateFor(
        lesson: lesson,
        index: i,
        unit: unit,
        unitIsOpen: unitIsOpen,
        mastery: mastery,
      );
    }

    return states;
  }

  LessonUnlockState _stateFor({
    required Lesson lesson,
    required int index,
    required Unit unit,
    required bool unitIsOpen,
    required Map<String, Mastery> mastery,
  }) {
    LessonUnlockState state(LessonLockReason reason, [Lesson? blocker]) =>
        LessonUnlockState(
          lessonId: lesson.id,
          reason: reason,
          blockingLessonId: blocker?.id,
          blockingLessonTitle: blocker?.title,
        );

    // The outer gate first. Nothing inside a closed unit is reachable, whatever
    // its own state would otherwise be.
    if (!unitIsOpen) return state(LessonLockReason.unitLocked);

    // A fact about the lesson rather than about the user, so it does not change
    // as they progress and is reported the same way from the first launch.
    if (lesson.isBlockedOnSelection) {
      return state(LessonLockReason.awaitingContent);
    }

    // Already been in here. Never re-lock something that has been opened —
    // a lesson someone has practised staying replayable is the whole point of
    // a mastery ladder that decays.
    if ((mastery[lesson.id] ?? const Mastery.fresh()).everAttempted) {
      return state(LessonLockReason.unlocked);
    }

    // The nearest previous lesson that can actually be entered. A lesson
    // awaiting a clip is skipped rather than treated as incomplete: content
    // that nobody can open must not wall off the lessons behind it, the same
    // rule unauthored units follow.
    final blocker = _previousEnterable(unit, index);
    if (blocker == null) return state(LessonLockReason.unlocked);

    // The high-water mark, not the current level. `bestScore` only ever rises,
    // so a lesson opened once stays open — where reading `level` would take it
    // away again the moment the lesson before it decayed or a restored backup
    // came back a rung short. Never remove something the user has been given.
    final best = (mastery[blocker.id] ?? const Mastery.fresh()).bestScore;
    return best >= (requiredLevel.threshold ?? 0)
        ? state(LessonLockReason.unlocked)
        : state(LessonLockReason.previousLessonIncomplete, blocker);
  }

  Lesson? _previousEnterable(Unit unit, int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (!unit.lessons[i].isBlockedOnSelection) return unit.lessons[i];
    }
    return null;
  }
}
