import 'package:flutter/material.dart';

import '../../../ui/charts/live_visualiser.dart';
import '../../../ui/tokens/motion.dart';
import '../../../ui/tokens/spacing.dart';
import '../../../ui/tokens/theme.dart';
import '../../../ui/tokens/typography.dart';
import 'lesson_controller.dart';

/// The record surface, driven by [LessonController].
///
/// Sequence is deliberate: permission, then room check, then record. The room
/// check runs *before* the take rather than after, because telling someone
/// their performance was unusable once they have already given it is the
/// fastest way to make an app feel punitive.
class RecordView extends StatelessWidget {
  const RecordView({super.key, required this.controller});

  final LessonController controller;

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
              Text(
                lesson.brief,
                style: ResType.caption.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: ResSpace.base),

              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    lesson.script ?? '',
                    style: ResType.script.copyWith(color: colors.ink),
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
                    : FilledButton(
                        onPressed: room.isAcceptable
                            ? () {
                                // A tap while recording is silent — the duck is
                                // held and the microphone is open. Deliberate:
                                // Stop is the only button on screen mid-take.
                                controller.sensory.tap();
                                if (recording) {
                                  controller.stopAndScore();
                                } else {
                                  controller.startRecording();
                                }
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: recording
                              ? colors.clip
                              : colors.accent,
                        ),
                        child: Text(recording ? 'Stop and score' : 'Record'),
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

    return DefaultTextStyle(
      style: ResType.metric.copyWith(color: colors.inkMuted),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${controller.elapsedSeconds.toStringAsFixed(1)}s'),
          Text(
            frame.isClipping ? 'CLIPPING' : '${frame.db.toStringAsFixed(0)} dB',
            style: ResType.metric.copyWith(
              color: frame.isClipping ? colors.clip : colors.inkMuted,
            ),
          ),
          Text(frame.hasPitch ? '${frame.pitchHz.toStringAsFixed(0)} Hz' : '—'),
          Text(
            controller.room == null
                ? 'room —'
                : 'room ${controller.room!.noiseFloorDb.toStringAsFixed(0)} dB',
          ),
        ],
      ),
    );
  }
}
