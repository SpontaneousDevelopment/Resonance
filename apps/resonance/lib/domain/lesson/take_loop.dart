/// The take loop: intro, record, judge, repeat.
///
/// Pure. Every transition is a function from one state to the next, so the
/// sequencing can be tested without a microphone, a widget or a clock — and the
/// awkward paths (a retry, a third failure, the last take) are the cheap ones
/// to test rather than the expensive ones.
///
/// It replaces `LessonPhase` for everything between opening a lesson and
/// reaching the results screen. That enum described *one* recording and had no
/// way to say "take two of three, one failure so far", which is most of what
/// this screen now needs to know.
library;

import '../curriculum/curriculum.dart';
import '../scoring/sanity_gate.dart';

enum TakeLoopStage {
  /// The lesson's own brief, one beat per card.
  exerciseIntro,

  /// One card describing the take about to be recorded.
  takeIntro,

  /// The record screen, before or during recording.
  recording,

  /// The take cleared the sanity gate. Brief — this celebrates, then moves on.
  passed,

  /// The take did not look like an attempt. Re-record on the same screen.
  failed,

  /// Three consecutive failures. The user is offered a way past rather than
  /// held here arguing about whether they spoke.
  exhausted,

  /// Every take recorded. The results screen takes over.
  complete,
}

/// Where the loop is. Immutable; transitions return a new one.
class TakeLoopState {
  const TakeLoopState({
    required this.stage,
    required this.takeIndex,
    required this.consecutiveFailures,
    required this.recorded,
    this.lastFailure,
  });

  const TakeLoopState.start()
    : stage = TakeLoopStage.exerciseIntro,
      takeIndex = 0,
      consecutiveFailures = 0,
      recorded = const [],
      lastFailure = null;

  final TakeLoopStage stage;

  /// Which take is being worked on, 0-based.
  final int takeIndex;

  /// Failures on *this* take. Reset when a take is banked, never carried over —
  /// the allowance is per take, not per lesson.
  final int consecutiveFailures;

  /// Takes banked so far, in order.
  final List<TakeOutcome> recorded;

  /// Why the last attempt was refused, for the message on screen.
  final SanityFailure? lastFailure;

  /// Human-facing position, 1-based.
  int get takeNumber => takeIndex + 1;

  bool get isComplete => stage == TakeLoopStage.complete;
}

/// One banked take.
class TakeOutcome {
  const TakeOutcome({
    required this.index,
    required this.label,
    required this.passedSanity,
  });

  final int index;
  final String label;

  /// False when this take only proceeded because the gate had failed three
  /// times. The rubric still scores it honestly; this records that the gate
  /// gave up rather than approved.
  final bool passedSanity;
}

/// Drives [TakeLoopState]. Holds no state of its own.
class TakeLoop {
  const TakeLoop({required this.takes});

  final List<LessonTake> takes;

  int get count => takes.length;

  LessonTake takeAt(int index) => takes[index];

  /// The lesson brief has been read through.
  TakeLoopState briefRead(TakeLoopState s) => TakeLoopState(
    stage: TakeLoopStage.takeIntro,
    takeIndex: s.takeIndex,
    consecutiveFailures: s.consecutiveFailures,
    recorded: s.recorded,
  );

  /// The take's own card has been tapped through.
  TakeLoopState takeIntroRead(TakeLoopState s) => TakeLoopState(
    stage: TakeLoopStage.recording,
    takeIndex: s.takeIndex,
    consecutiveFailures: s.consecutiveFailures,
    recorded: s.recorded,
  );

  /// A recording finished and the gate has judged it.
  TakeLoopState judged(TakeLoopState s, SanityVerdict verdict) {
    if (verdict.passed) {
      return TakeLoopState(
        stage: TakeLoopStage.passed,
        takeIndex: s.takeIndex,
        consecutiveFailures: 0,
        recorded: s.recorded,
      );
    }

    final failures = s.consecutiveFailures + 1;
    return TakeLoopState(
      // The third failure does not proceed on its own. It offers.
      stage: failures >= SanityThresholds.failuresBeforeContinue
          ? TakeLoopStage.exhausted
          : TakeLoopStage.failed,
      takeIndex: s.takeIndex,
      consecutiveFailures: failures,
      recorded: s.recorded,
      lastFailure: verdict.failure,
    );
  }

  /// Re-record after a failure. Same take, same screen — the intro card is not
  /// shown again, because the user has just read it.
  TakeLoopState retry(TakeLoopState s) => TakeLoopState(
    stage: TakeLoopStage.recording,
    takeIndex: s.takeIndex,
    consecutiveFailures: s.consecutiveFailures,
    recorded: s.recorded,
    lastFailure: s.lastFailure,
  );

  /// Bank the current take and move on. Used both by a pass and, after three
  /// failures, by the user choosing to continue.
  TakeLoopState bank(TakeLoopState s, {required bool passedSanity}) {
    final banked = [
      ...s.recorded,
      TakeOutcome(
        index: s.takeIndex,
        label: takes[s.takeIndex].label,
        passedSanity: passedSanity,
      ),
    ];

    final next = s.takeIndex + 1;
    if (next >= count) {
      return TakeLoopState(
        stage: TakeLoopStage.complete,
        takeIndex: s.takeIndex,
        consecutiveFailures: 0,
        recorded: banked,
      );
    }

    return TakeLoopState(
      stage: TakeLoopStage.takeIntro,
      takeIndex: next,
      consecutiveFailures: 0,
      recorded: banked,
    );
  }
}
