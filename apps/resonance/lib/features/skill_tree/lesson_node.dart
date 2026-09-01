import 'package:flutter/material.dart';

import '../../domain/curriculum/curriculum.dart';
import '../../domain/curriculum/lesson_unlock.dart';
import '../../domain/curriculum/mastery.dart';
import '../../ui/tokens/motion.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
import 'mastery_ring.dart';

/// One lesson inside an expanded unit.
///
/// Three states, and they are deliberately not interchangeable:
///
/// * **Open** — enterable, with the level reached shown on its ring.
/// * **Not yet reached** — locked by sequence, and it says which lesson opens
///   it, because "do the one before" is actionable and a padlock is not.
/// * **Awaiting content** — written, but its reference clip has not been
///   chosen. Nothing the user does opens this one, so showing the same padlock
///   would be telling them to keep practising toward something that is not
///   waiting on them.
class LessonNode extends StatefulWidget {
  const LessonNode({
    super.key,
    required this.lesson,
    required this.number,
    required this.mastery,
    required this.unlock,
    required this.tierColor,
    this.onTap,
  });

  final Lesson lesson;

  /// 1-based position, shown to the user.
  final int number;
  final Mastery mastery;
  final LessonUnlockState unlock;
  final Color tierColor;
  final VoidCallback? onTap;

  @override
  State<LessonNode> createState() => _LessonNodeState();
}

class _LessonNodeState extends State<LessonNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = widget.unlock.isOpen;
    final awaiting = widget.unlock.reason == LessonLockReason.awaitingContent;

    final subtitle = switch (widget.unlock.reason) {
      LessonLockReason.unlocked =>
        widget.mastery.everAttempted
            ? '${widget.mastery.level.label} · best ${widget.mastery.bestScore}'
            : 'Not started',
      LessonLockReason.previousLessonIncomplete =>
        widget.unlock.blockingLessonTitle == null
            ? 'Finish the lesson before this one'
            : 'Pass “${widget.unlock.blockingLessonTitle}” to open this',
      LessonLockReason.awaitingContent => 'Clip not chosen yet',
      LessonLockReason.unitLocked => 'This unit is locked',
    };

    return Semantics(
      button: open,
      enabled: open,
      label:
          'Lesson ${widget.number}. ${widget.lesson.title}. '
          '${open ? widget.mastery.level.label : "Locked"}. $subtitle.',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: open ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: open ? widget.onTap : null,
          child: AnimatedContainer(
            duration: ResMotion.duration(context, ResMotion.control),
            curve: ResMotion.enter,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: ResSpace.base,
              vertical: ResSpace.snug,
            ),
            decoration: BoxDecoration(
              color: open && _hovered ? colors.surfaceRaised : colors.surface,
              borderRadius: BorderRadius.circular(ResRadius.small),
              border: Border.all(
                color: open && _hovered ? widget.tierColor : colors.ruleSoft,
              ),
            ),
            child: Opacity(
              opacity: open ? 1.0 : 0.6,
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${widget.number}',
                      style: ResType.metric.copyWith(
                        color: colors.inkFaint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  MasteryRing(
                    level: widget.mastery.level,
                    color: widget.tierColor,
                    locked: !open,
                    size: 26,
                  ),
                  const SizedBox(width: ResSpace.snug),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lesson.title,
                          style: ResType.bodyStrong.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: ResSpace.hair),
                        Text(
                          subtitle,
                          style: ResType.caption.copyWith(
                            // Awaiting content is a note about the library, not
                            // a warning about the user's progress.
                            color: awaiting ? colors.caution : colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (open)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.inkFaint,
                      size: 20,
                    )
                  else if (awaiting)
                    // Distinct from the padlock on purpose: this one is not
                    // waiting on the user at all.
                    Icon(
                      Icons.hourglass_empty_rounded,
                      color: colors.caution,
                      size: 16,
                    )
                  else
                    Icon(
                      Icons.lock_outline_rounded,
                      color: colors.inkFaint,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
