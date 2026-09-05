import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/progress/progress_repository.dart';
import '../../core/sensory/sensory_director.dart';
import '../../core/audio/recording_session.dart';
import '../../core/speech/platform_speech_recogniser.dart';
import '../../core/sync/sync_scheduler.dart';
import '../../domain/curriculum/curriculum.dart';
import '../../domain/sensory/sensory_cue.dart';
import '../../ui/tokens/motion.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
import 'feedback/feedback_screen.dart';
import '../../domain/curriculum/brief_chunks.dart';
import '../../domain/lesson/take_loop.dart';
import 'runner/lesson_controller.dart';
import 'runner/pre_exercise_cards.dart';
import '../rest/take_five_screen.dart';
import 'runner/record_view.dart';

/// One lesson attempt, start to finish.
///
/// A single screen that switches on [LessonPhase] rather than a stack of routes.
/// The whole point of the loop is that "record → score → again" is one
/// continuous motion; pushing and popping routes between those states would put
/// a navigation animation in the middle of the tightest feedback loop in the
/// product, and make "Again" a pop-then-push.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late final LessonController _controller = LessonController(
    lesson: widget.lesson,
    // From a provider rather than constructed here, so the assembled screen can
    // be driven end to end in a test. Without this seam the only way to reach a
    // failing take is a real microphone.
    recogniser: ref.read(speechRecogniserProvider)(),
    session: ref.read(recordingSessionProvider)(),
    progress: ref.read(progressRepositoryProvider),
    sensory: ref.read(sensoryDirectorProvider),
    // Send it now rather than at next launch. Null whenever there is no
    // backend, which is the anonymous-first default.
    onAttemptRecorded: () => ref.read(syncSchedulerProvider)?.nudge(),
  );

  late final TakeLoop _loop = TakeLoop(takes: widget.lesson.takes);
  TakeLoopState _state = const TakeLoopState.start();

  LessonTake get _take => _loop.takeAt(_state.takeIndex);

  /// True while the rest exercise is showing. Not a phase on the controller:
  /// resting is something the user is doing, not something the attempt is.
  bool _resting = false;

  /// Guards against replaying the celebration on every rebuild — the screen
  /// rebuilds as the coach note arrives, and a level-up fanfare twice would be
  /// worse than none.
  bool _playedOutcome = false;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  void _advance(TakeLoopState next) => setState(() => _state = next);

  /// One short line naming the take about to be recorded.
  ///
  /// Built from the authored label rather than authored separately: a per-take
  /// sentence in the curriculum would be one more thing to write for every
  /// lesson, and the label already says the thing that changes.
  String _takeIntroLine() {
    final take = _take;
    final band = (take.targetWpmMin != null && take.targetWpmMax != null)
        ? ' Aim for ${take.targetWpmMin}–${take.targetWpmMax} words a minute.'
        : '';
    return _loop.count == 1
        ? 'Read the line as it is written.$band'
        : 'Take ${_state.takeNumber} of ${_loop.count}: ${take.label}.$band';
  }

  /// A recording finished. Judge it, signal, and move the loop.
  Future<void> _judgeTake() async {
    // Read before awaiting: syncWith needs a context, and the analyzer is right
    // that holding one across a gap is how a disposed widget gets used.
    final sensory = ref.read(sensoryDirectorProvider)..syncWith(context);

    final verdict = await _controller.stopAndJudge(
      takeIndex: _state.takeIndex,
      lessonTake: _take,
    );

    await sensory.play(
      verdict.passed
          ? sensory.choreography.forTakePassed()
          : sensory.choreography.forTakeFailed(),
    );

    if (!mounted) return;
    _advance(_loop.judged(_state, verdict));

    if (verdict.passed) {
      // The celebration sits on the button, then the loop moves on by itself.
      // A pass needs no decision from the user, and asking for one would put a
      // tap between every take.
      final celebration = ResMotion.duration(
        context,
        FeedbackChoreography.takeCelebration,
      );
      await Future<void>.delayed(celebration);
      if (!mounted) return;
      _controller.bankTake(passedSanity: true);
      final next = _loop.bank(_state, passedSanity: true);
      _advance(next);
      if (next.isComplete) await _controller.commitAttempt();
    }
  }

  /// Past a third failure, with whatever was recorded.
  Future<void> _continueAnyway() async {
    ref.read(sensoryDirectorProvider).tap();
    _controller.bankTake(passedSanity: false);
    final next = _loop.bank(_state, passedSanity: false);
    _advance(next);
    if (next.isComplete) await _controller.commitAttempt();
  }

  void _playOutcomeOnce() {
    if (_playedOutcome) return;
    final outcome = _controller.outcome;
    final score = _controller.score;
    if (outcome == null || score == null) return;

    _playedOutcome = true;
    final sensory = ref.read(sensoryDirectorProvider)..syncWith(context);
    sensory.play(
      sensory.choreography.forAttempt(
        score: score.composite,
        promotion: outcome.promotion,
        energyEvent: outcome.energyEvent,
        streakEvent: outcome.streak.event,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_resting) {
      return TakeFiveScreen(
        onComplete: () async {
          await ref.read(progressRepositoryProvider).completeRest();
          if (mounted) setState(() => _resting = false);
        },
        onSkip: () {
          ref.read(sensoryDirectorProvider).tap();
          setState(() => _resting = false);
        },
      );
    }

    // A lesson whose reference clip has not been chosen is written but not
    // playable. Refusing here is what makes `awaiting_selection` more than a
    // comment — nothing can ship having silently defaulted to some video.
    if (widget.lesson.isBlockedOnSelection) {
      return _AwaitingSelection(
        lesson: widget.lesson,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    // The exercise brief, once per lesson.
    if (_state.stage == TakeLoopStage.exerciseIntro) {
      final chunks = briefChunks(widget.lesson.brief);
      if (chunks.isEmpty) {
        _advance(_loop.briefRead(_state));
      } else {
        return PreExerciseCards(
          title: widget.lesson.title,
          chunks: chunks,
          sensory: ref.read(sensoryDirectorProvider),
          onBack: () => Navigator.of(context).pop(),
          onDone: () => _advance(_loop.briefRead(_state)),
        );
      }
    }

    // One card per take, then a horizontal slide into the record screen — the
    // takes are a deck being paged through, and a vertical transition here
    // would read as the same modal gesture the whole lesson arrived by.
    if (_state.stage == TakeLoopStage.takeIntro) {
      return PreExerciseCards(
        key: ValueKey('take-intro-${_state.takeIndex}'),
        title: '${widget.lesson.title} · Take ${_state.takeNumber}',
        chunks: [_takeIntroLine()],
        sensory: ref.read(sensoryDirectorProvider),
        onBack: () => Navigator.of(context).pop(),
        onDone: () => _advance(_loop.takeIntroRead(_state)),
      );
    }

    // The feedback screen leaves downward, the same gesture the whole lesson
    // arrived by. Continue pops the route, so its exit is the route transition
    // reversing; Again stays on the route, so it needs this. Both read as the
    // results sliding off the exercise rather than being swapped for it.
    //
    // Symmetric on purpose: the outgoing child runs this backwards, so a single
    // offset gives "results drop away" and "exercise rises back" without
    // special-casing direction.
    return AnimatedSwitcher(
      duration: ResMotion.duration(context, FeedbackChoreography.lessonExit),
      switchInCurve: ResMotion.enter,
      switchOutCurve: ResMotion.exit,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return KeyedSubtree(
            key: ValueKey((_controller.phase, _state.stage)),
            child: switch (_controller.phase) {
              LessonPhase.scored => Builder(
                builder: (context) {
                  // After the frame, so the schedule starts alongside the ring fill
                  // rather than before the screen exists.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _playOutcomeOnce(),
                  );
                  return FeedbackScreen(
                    lessonTitle: widget.lesson.title,
                    script: widget.lesson.script ?? '',
                    score: _controller.score!,
                    promotion: _controller.promotion!,
                    coachNote: _controller.coachNote,
                    coachNotePending: _controller.coachNotePending,
                    clarityUnavailable: _controller.clarityUnavailable,
                    outcome: _controller.outcome,
                    onTakeFive: () {
                      ref.read(sensoryDirectorProvider).tap();
                      setState(() => _resting = true);
                    },
                    onRetry: () {
                      ref.read(sensoryDirectorProvider).tap();
                      _playedOutcome = false;
                      _controller.reset();
                    },
                    onContinue: () {
                      ref.read(sensoryDirectorProvider).tap();
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
              LessonPhase.scoring => const _Scoring(),
              LessonPhase.failed => _Failed(
                message: _controller.error ?? 'Something went wrong.',
                onBack: () => Navigator.of(context).pop(),
              ),
              _ => RecordView(
                controller: _controller,
                takeNumber: _state.takeNumber,
                takeCount: _loop.count,
                takeLabel: _take.label,
                stage: _state.stage,
                failure: _state.lastFailure,
                onRecord: () {
                  _controller.sensory.tap();
                  _controller.startRecording();
                },
                onStop: () {
                  _controller.sensory.tap();
                  _judgeTake();
                },
                onRetry: () {
                  _controller.sensory.tap();
                  _advance(_loop.retry(_state));
                  _controller.startRecording();
                },
                onContinueAnyway: _continueAnyway,
              ),
            },
          );
        },
      ),
    );
  }
}

/// Shown for a lesson whose reference clip has not been selected yet.
class _AwaitingSelection extends StatelessWidget {
  const _AwaitingSelection({required this.lesson, required this.onBack});

  final Lesson lesson;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ResSpace.section),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This lesson is not ready yet',
                style: ResType.heading.copyWith(color: colors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ResSpace.tight),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'It needs a reference performance to study, and one has not '
                  'been chosen. Everything else about the lesson is written.',
                  textAlign: TextAlign.center,
                  style: ResType.body.copyWith(color: colors.inkMuted),
                ),
              ),
              const SizedBox(height: ResSpace.loose),
              FilledButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deliberately plain. Scoring is on-device and takes a few hundred
/// milliseconds — anything more elaborate here would be a loading animation
/// nobody has time to read.
class _Scoring extends StatelessWidget {
  const _Scoring();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: ResSpace.base),
            Text(
              'Listening back…',
              style: ResType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ResSpace.section),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: ResType.body.copyWith(color: colors.ink),
              ),
              const SizedBox(height: ResSpace.loose),
              FilledButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      ),
    );
  }
}
