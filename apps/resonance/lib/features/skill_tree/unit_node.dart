import 'package:flutter/material.dart';

import '../../domain/curriculum/curriculum.dart';
import '../../domain/curriculum/mastery.dart';
import '../../ui/tokens/motion.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
import 'mastery_ring.dart';

/// One unit on the tree.
///
/// A locked unit is shown, not hidden. Seeing the shape of the road is a large
/// part of what makes a tree motivating — hiding it would turn the screen into
/// a to-do list with one item.
class UnitNode extends StatefulWidget {
  const UnitNode({
    super.key,
    required this.unit,
    required this.mastery,
    required this.isUnlocked,
    this.onTap,
  });

  final Unit unit;
  final Mastery mastery;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  State<UnitNode> createState() => _UnitNodeState();
}

class _UnitNodeState extends State<UnitNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = widget.unit;
    final tierColor = colors.tier(unit.tierNumber);
    final enabled = widget.isUnlocked;

    final background = enabled
        ? (_hovered ? colors.surfaceRaised : colors.surface)
        : colors.surface;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '${unit.label} ${unit.title}. '
          '${unit.displayLessonCount} lessons. '
          '${enabled ? widget.mastery.level.label : "Locked"}.',
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: ResMotion.duration(context, ResMotion.control),
            curve: ResMotion.enter,
            padding: const EdgeInsets.all(ResSpace.base),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(ResRadius.medium),
              border: Border.all(
                color: enabled && _hovered ? tierColor : colors.ruleSoft,
              ),
            ),
            child: Opacity(
              // Locked units recede rather than disappear.
              opacity: enabled ? 1.0 : 0.55,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MasteryRing(
                    level: widget.mastery.level,
                    color: tierColor,
                    locked: !enabled,
                  ),
                  const SizedBox(width: ResSpace.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              unit.label,
                              style: ResType.label.copyWith(color: tierColor),
                            ),
                            if (unit.isGate) ...[
                              const SizedBox(width: ResSpace.tight),
                              _Pill(
                                label: 'CHECK',
                                color: tierColor,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: ResSpace.hair),
                        Text(
                          unit.title,
                          style: ResType.heading.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: ResSpace.hair),
                        Text(
                          unit.summary,
                          style: ResType.caption
                              .copyWith(color: colors.inkMuted),
                        ),
                        const SizedBox(height: ResSpace.snug),
                        Row(
                          children: [
                            Text(
                              '${unit.displayLessonCount} lessons',
                              style: ResType.metric.copyWith(
                                color: colors.inkFaint,
                                fontSize: 12,
                              ),
                            ),
                            if (!unit.isAuthored) ...[
                              Text(
                                '  ·  ',
                                style: ResType.metric.copyWith(
                                  color: colors.inkFaint,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'coming soon',
                                style: ResType.metric.copyWith(
                                  color: colors.inkFaint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.inkFaint,
                      size: 22,
                    )
                  else
                    Icon(
                      Icons.lock_outline_rounded,
                      color: colors.inkFaint,
                      size: 18,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(ResRadius.small),
      ),
      child: Text(
        label,
        style: ResType.label.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}
