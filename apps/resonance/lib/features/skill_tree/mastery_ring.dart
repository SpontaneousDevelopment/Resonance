import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/curriculum/mastery.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// The mastery indicator: five segments, one per level.
///
/// Segments rather than a continuous arc, because the ladder *is* discrete —
/// a smooth ring would imply partial progress between levels, and there is no
/// such thing. The gaps are the point.
class MasteryRing extends StatelessWidget {
  const MasteryRing({
    super.key,
    required this.level,
    required this.color,
    this.locked = false,
    this.size = 44,
  });

  final MasteryLevel level;
  final Color color;
  final bool locked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          filled: locked ? 0 : level.rank,
          fillColor: color,
          trackColor: colors.ruleSoft,
          strokeWidth: size * 0.09,
        ),
        child: Center(
          child: locked
              ? Icon(
                  Icons.lock_outline_rounded,
                  size: size * 0.36,
                  color: colors.inkFaint,
                )
              : Text(
                  level == MasteryLevel.locked ? '–' : '${level.rank}',
                  style: ResType.metric.copyWith(
                    color: level == MasteryLevel.locked
                        ? colors.inkFaint
                        : color,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.filled,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  /// 0..5.
  final int filled;
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  static const _segments = 5;

  /// Angular gap between segments, in radians.
  static const _gap = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: centre, radius: radius);

    final sweep = (2 * math.pi / _segments) - _gap;
    // Start at 12 o'clock, offset by half a gap so the first segment's leading
    // edge sits on the vertical rather than the gap straddling it.
    final start = -math.pi / 2 + _gap / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _segments; i++) {
      paint.color = i < filled ? fillColor : trackColor;
      canvas.drawArc(arcRect, start + i * (sweep + _gap), sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.filled != filled ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
