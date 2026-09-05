import 'package:flutter/material.dart';

import '../../../ui/charts/live_visualiser.dart';
import '../../../ui/tokens/motion.dart';
import '../../../ui/tokens/spacing.dart';
import '../../../ui/tokens/theme.dart';
import '../../../ui/tokens/typography.dart';
import '../../../domain/lesson/take_loop.dart';
import '../../../domain/scoring/sanity_gate.dart';
import '../../../domain/sensory/sensory_cue.dart';
import 'lesson_controller.dart';

/// The record surface, driven by [LessonController].
///
/// Sequence is deliberate: permission, then room check, then record. The room
/// check runs *before* the take rather than after, because telling someone
/// their performance was unusable once they have already given it is the
/// fastest way to make an app feel punitive.
class RecordView extends StatelessWidget {
  const RecordView({
    super.key,
    required this.controller,
    required this.takeNumber,
    required this.takeCount,
    required this.takeLabel,
    required this.stage,
    required this.onRecord,
    required this.onStop,
    required this.onRetry,
    required this.onContinueAnyway,
    this.failure,
  });

  final LessonController controller;

  /// 1-based, shown on the button. The authored label goes above it as a
  /// heading — a button says what tapping does, and an authored string is
  /// variable-length.
  final int takeNumber;
  final int takeCount;
  final String takeLabel;

  final TakeLoopStage stage;
  final SanityFailure? failure;

  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lesson = controller.lesson;
    final recording = controller.phase == LessonPhase.recording;
    final busy = controller.phase == LessonPhase.checkingRoom;
    final room = controller.room;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The brief is not here any more. As a paragraph of caption text
              // above the script it was present and therefore skipped; it now
              // gets its own screen before this one, one beat at a time, with
              // a tap between each. See PreExerciseCards.
              // The verdict, on the script itself. Colour is never the only
              // channel: an icon sits beside it, the haptic differs, and the
              // semantics say pass or fail in words.
              if (stage == TakeLoopStage.passed ||
                  stage == TakeLoopStage.failed ||
                  stage == TakeLoopStage.exhausted)
                _Verdict(stage: stage, failure: failure),

              Expanded(
                child: SingleChildScrollView(
                  child: Semantics(
                    liveRegion: true,
                    label: switch (stage) {
                      TakeLoopStage.passed => 'Take $takeNumber accepted.',
                      TakeLoopStage.failed || TakeLoopStage.exhausted =>
                        'Take $takeNumber was not accepted. '
                            '${SanityVerdict.fail(failure ?? SanityFailure.didNotMatchScript).message}',
                      _ => 'The line to read.',
                    },
                    child: Text(
                      lesson.script ?? '',
                      style: ResType.script.copyWith(
                        color: switch (stage) {
                          TakeLoopStage.passed => colors.signal,
                          TakeLoopStage.failed ||
                          TakeLoopStage.exhausted => colors.clip,
                          _ => colors.ink,
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: ResSpace.base),

              if (room == null)
                _Notice(
                  message:
                      'Check your room before you read — it takes two '
                      'seconds and makes the score fair.',
                  tone: colors.inkMuted,
                )
              else if (room.advice != null)
                _Notice(
                  message: room.advice!,
                  tone: room.isAcceptable ? colors.caution : colors.clip,
                ),

              const SizedBox(height: ResSpace.snug),
              LiveVisualiser(analysis: controller.analysis),
              const SizedBox(height: ResSpace.snug),
              _Readout(controller: controller),
              const SizedBox(height: ResSpace.base),

              if (takeCount > 1) ...[
                Text(
                  'TAKE $takeNumber OF $takeCount · ${takeLabel.toUpperCase()}',
                  style: ResType.label.copyWith(color: colors.inkFaint),
                ),
                const SizedBox(height: ResSpace.tight),
              ],

              SizedBox(
                width: double.infinity,
                child: room == null
                    ? FilledButton(
                        onPressed: busy
                            ? null
                            : () {
                                controller.sensory.tap();
                                controller.checkRoom();
                              },
                        child: Text(busy ? 'Listening…' : 'Check my room'),
                      )
                    : _TakeButton(
                        stage: stage,
                        takeNumber: takeNumber,
                        recording: recording,
                        enabled: room.isAcceptable,
                        onRecord: onRecord,
                        onStop: onStop,
                        onRetry: onRetry,
                        onContinueAnyway: onContinueAnyway,
                      ),
              ),
              const SizedBox(height: ResSpace.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: ResMotion.duration(context, ResMotion.control),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ResSpace.snug),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ResRadius.small),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Text(message, style: ResType.caption.copyWith(color: tone)),
      ),
    );
  }
}

/// Live numbers. Monospace with tabular figures so the digits do not jitter as
/// they update twenty-odd times a second.
class _Readout extends StatelessWidget {
  const _Readout({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = controller.latestFrame;

    return Semantics(
      // Four live numbers that change every frame. Read out individually they
      // are noise — "—", "0 dB", "12.4s" — so the strip gets one label saying
      // what it is, and the glyphs themselves are not announced.
      label: controller.room == null
          ? 'Live readout. Room not checked yet.'
          : 'Live readout. Room noise floor '
                '${controller.room!.noiseFloorDb.toStringAsFixed(0)} decibels.',
      excludeSemantics: true,
      child: DefaultTextStyle(
        // `ink`, not `inkMuted`: this is a measurement someone reads while
        // performing, and it sat at 3.15:1 against the dark ground.
        style: ResType.metric.copyWith(color: colors.ink),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${controller.elapsedSeconds.toStringAsFixed(1)}s'),
            Text(
              frame.isClipping
                  ? 'CLIPPING'
                  : '${frame.db.toStringAsFixed(0)} dB',
              style: ResType.metric.copyWith(
                color: frame.isClipping ? colors.clip : colors.ink,
              ),
            ),
            Text(
              frame.hasPitch ? '${frame.pitchHz.toStringAsFixed(0)} Hz' : '—',
            ),
            Text(
              controller.room == null
                  ? 'room —'
                  : 'room ${controller.room!.noiseFloorDb.toStringAsFixed(0)} dB',
            ),
          ],
        ),
      ),
    );
  }
}

/// The verdict on the last take, in a channel that is not colour.
///
/// The script turning green or red is the loud signal, and it is the one a
/// colour-blind user gets nothing from. This sits beside it: a distinct icon
/// and a word. The haptic differs too — `takePassed` is a medium impact where
/// the failure is a light one — so the same fact arrives three ways.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.stage, this.failure});

  final TakeLoopStage stage;
  final SanityFailure? failure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final passed = stage == TakeLoopStage.passed;

    return Padding(
      padding: const EdgeInsets.only(bottom: ResSpace.snug),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons.check_circle_rounded
                : Icons.replay_circle_filled_rounded,
            color: passed ? colors.signal : colors.clip,
            size: 20,
          ),
          const SizedBox(width: ResSpace.tight),
          Expanded(
            child: Text(
              passed
                  ? 'Take accepted.'
                  : SanityVerdict.fail(
                      failure ?? SanityFailure.didNotMatchScript,
                    ).message,
              style: ResType.caption.copyWith(
                color: passed ? colors.signal : colors.clip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The record button, in each of the states the take loop can be in.
///
/// Four, and they are genuinely different actions rather than one button with
/// different words: record, stop, re-record, and continue past a gate that has
/// given up. The last is deliberately not automatic — proceeding on the user's
/// behalf after telling them three times that something was wrong would be the
/// app overruling itself.
class _TakeButton extends StatefulWidget {
  const _TakeButton({
    required this.stage,
    required this.takeNumber,
    required this.recording,
    required this.enabled,
    required this.onRecord,
    required this.onStop,
    required this.onRetry,
    required this.onContinueAnyway,
  });

  final TakeLoopStage stage;
  final int takeNumber;
  final bool recording;
  final bool enabled;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onContinueAnyway;

  @override
  State<_TakeButton> createState() => _TakeButtonState();
}

class _TakeButtonState extends State<_TakeButton>
    with SingleTickerProviderStateMixin {
  /// The same loop the continue prompt uses, at the same period — a second
  /// blink rhythm in the app would read as a different kind of urgency.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: FeedbackChoreography.briefBlink,
  );

  @override
  void didUpdateWidget(_TakeButton old) {
    super.didUpdateWidget(old);
    _syncBlink();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBlink());
  }

  void _syncBlink() {
    if (!mounted) return;
    final wants =
        widget.stage == TakeLoopStage.failed &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (wants && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!wants && _blink.isAnimating) {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (label, action, background, semantic) = switch (widget.stage) {
      TakeLoopStage.passed => (
        'Success!',
        null,
        colors.signal,
        'Take ${widget.takeNumber} accepted.',
      ),
      TakeLoopStage.failed => (
        'Re-record',
        widget.onRetry,
        colors.clip,
        'That take was not accepted. Activate to record take '
            '${widget.takeNumber} again.',
      ),
      TakeLoopStage.exhausted => (
        'Continue',
        widget.onContinueAnyway,
        colors.inkFaint,
        'Continue with the take as recorded.',
      ),
      _ =>
        widget.recording
            ? (
                'Stop and score',
                widget.onStop,
                colors.clip,
                'Recording. Activate to stop.',
              )
            : (
                'Record Take ${widget.takeNumber}',
                widget.onRecord,
                colors.accent,
                'Record take ${widget.takeNumber}.',
              ),
    };

    final button = FilledButton(
      onPressed: widget.enabled ? action : null,
      style: FilledButton.styleFrom(backgroundColor: background),
      child: Text(label),
    );

    return Semantics(
      liveRegion: true,
      button: action != null,
      enabled: widget.enabled && action != null,
      label: semantic,
      excludeSemantics: true,
      child: widget.stage == TakeLoopStage.failed
          ? FadeTransition(
              key: const ValueKey('re-record-blink'),
              opacity: _blink.drive(Tween(begin: 1.0, end: 0.45)),
              child: button,
            )
          : AnimatedSwitcher(
              // "Success!" fades in rather than the word changing under the
              // cursor: it is a small celebration, not a state label.
              duration: ResMotion.duration(context, ResMotion.control),
              child: KeyedSubtree(key: ValueKey(label), child: button),
            ),
    );
  }
}
