import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/progress/progress_repository.dart';
import '../../core/sensory/sensory_director.dart';
import '../../core/speech/platform_speech_recogniser.dart';
import '../../domain/curriculum/curriculum.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
import 'feedback/feedback_screen.dart';
import 'runner/lesson_controller.dart';
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
    recogniser: PlatformSpeechRecogniser(),
    progress: ref.read(progressRepositoryProvider),
    sensory: ref.read(sensoryDirectorProvider),
  );

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

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return switch (_controller.phase) {
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
          _ => RecordView(controller: _controller),
        };
      },
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
