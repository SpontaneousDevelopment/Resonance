import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

import '../tokens/theme.dart';

/// A rolling record of recent frames, sized to the visible window.
///
/// A [ListQueue] rather than a growing list: a 90-second take at 23 frames a
/// second is over 2000 frames, and the visualiser only ever draws the last
/// hundred or so. Keeping the rest would grow without bound during a long
/// audiobook drill for no visible benefit.
class _FrameHistory {
  _FrameHistory(this.capacity);

  final int capacity;
  final ListQueue<FrameAnalysis> _frames = ListQueue();

  void add(FrameAnalysis frame) {
    _frames.addLast(frame);
    while (_frames.length > capacity) {
      _frames.removeFirst();
    }
  }

  void clear() => _frames.clear();

  int get length => _frames.length;
  bool get isEmpty => _frames.isEmpty;
  FrameAnalysis operator [](int i) => _frames.elementAt(i);
  Iterable<FrameAnalysis> get all => _frames;
}

/// The live recording visualiser: level bars beneath, pitch contour above.
///
/// Two things drive the design.
///
/// **Pitch is plotted in semitones, not hertz.** A linear Hz axis squashes the
/// bottom of the vocal range flat — the difference between 90 and 100 Hz is
/// most of a whole tone and would be almost invisible, while the same visual
/// distance up at 400 Hz is a fraction of a semitone. A semitone axis makes an
/// octave leap look like an octave leap wherever it happens.
///
/// **Unvoiced frames leave a gap.** Drawing a line through silence, or down to
/// zero, invents a pitch movement the speaker never made. Breaths and pauses
/// are part of the performance and should read as absence.
class LiveVisualiser extends StatefulWidget {
  const LiveVisualiser({
    super.key,
    required this.analysis,
    this.windowFrames = 96,
    this.height = 180,
    this.referenceContour,
  });

  /// Frames as they are analysed, roughly 23 Hz.
  final Stream<FrameAnalysis> analysis;

  /// How many frames stay on screen — about four seconds at 2048/48 kHz.
  final int windowFrames;

  final double height;

  /// The target contour to match, in semitones above C0, when the lesson has
  /// one. Drawn behind the user's own trace.
  final List<double>? referenceContour;

  @override
  State<LiveVisualiser> createState() => _LiveVisualiserState();
}

class _LiveVisualiserState extends State<LiveVisualiser>
    with SingleTickerProviderStateMixin {
  late final _FrameHistory _history = _FrameHistory(widget.windowFrames);
  late final Ticker _ticker;
  StreamSubscription<FrameAnalysis>? _subscription;

  /// Fractional position between the second-newest and newest frame, 0..1.
  ///
  /// The analyser produces frames at ~23 Hz but the display runs at 60. Without
  /// this the waveform advances in visible steps; with it the scroll is
  /// continuous and only the newest bar is ever mid-transit.
  double _interFrame = 0;
  Duration _lastFrameAt = Duration.zero;

  /// Expected spacing between analysed frames — 2048 samples at 48 kHz.
  /// Used only to pace the interpolation, so a little drift is harmless.
  static const _frameInterval = Duration(milliseconds: 43);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _subscription = widget.analysis.listen(_onAnalysis);
  }

  void _onAnalysis(FrameAnalysis frame) {
    _history.add(frame);
    _interFrame = 0;
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_history.isEmpty) return;

    final delta = elapsed - _lastFrameAt;
    _lastFrameAt = elapsed;

    final progress = delta.inMicroseconds / _frameInterval.inMicroseconds;
    final next = (_interFrame + progress).clamp(0.0, 1.0);
    if (next != _interFrame) {
      setState(() => _interFrame = next);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // With reduced motion the scroll snaps frame to frame rather than gliding.
    final smooth = !MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _VisualiserPainter(
            history: _history,
            windowFrames: widget.windowFrames,
            interFrame: smooth ? _interFrame : 1.0,
            referenceContour: widget.referenceContour,
            levelColor: colors.userTrace,
            contourColor: colors.userTrace,
            referenceColor: colors.referenceTrace,
            gridColor: colors.ruleSoft,
            clipColor: colors.clip,
          ),
        ),
      ),
    );
  }
}

class _VisualiserPainter extends CustomPainter {
  _VisualiserPainter({
    required this.history,
    required this.windowFrames,
    required this.interFrame,
    required this.levelColor,
    required this.contourColor,
    required this.referenceColor,
    required this.gridColor,
    required this.clipColor,
    this.referenceContour,
  });

  final _FrameHistory history;
  final int windowFrames;
  final double interFrame;
  final List<double>? referenceContour;

  final Color levelColor;
  final Color contourColor;
  final Color referenceColor;
  final Color gridColor;
  final Color clipColor;

  /// The contour occupies the top 60% and the level bars the bottom 40% — the
  /// pitch trace carries more information and earns the space.
  static const _contourFraction = 0.6;

  /// Semitone span drawn around the running median. Two octaves comfortably
  /// contains any single speaker while keeping small movements visible.
  static const _semitoneSpan = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final contourHeight = size.height * _contourFraction;
    final levelTop = contourHeight + 8;
    final levelHeight = size.height - levelTop;

    _paintGrid(canvas, size, contourHeight);

    if (history.isEmpty) return;

    final slotWidth = size.width / windowFrames;
    // Scroll by a fraction of a slot so motion is continuous between frames.
    final scrollOffset = (1.0 - interFrame) * slotWidth;

    _paintLevels(canvas, size, levelTop, levelHeight, slotWidth, scrollOffset);
    _paintContour(canvas, size, contourHeight, slotWidth, scrollOffset);
  }

  void _paintGrid(Canvas canvas, Size size, double contourHeight) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Octave lines through the contour region.
    for (var i = 0; i <= 2; i++) {
      final y = contourHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintLevels(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double slotWidth,
    double scrollOffset,
  ) {
    final barWidth = math.max(1.0, slotWidth * 0.6);
    final centreY = top + height / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < history.length; i++) {
      final frame = history[i];
      final slot = windowFrames - history.length + i;
      final x = slot * slotWidth + scrollOffset;
      if (x < -slotWidth || x > size.width) continue;

      // dB rather than linear amplitude: a linear meter spends most of its
      // range on the loudest tenth of the signal and shows a quiet, controlled
      // read as a flat line.
      final normalised = ((frame.db + 60) / 60).clamp(0.0, 1.0);
      final barHeight = math.max(1.5, normalised * height * 0.9);

      paint.color = frame.isClipping
          ? clipColor
          : levelColor.withValues(alpha: frame.isVoiced ? 0.85 : 0.3);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + slotWidth / 2, centreY),
            width: barWidth,
            height: barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  void _paintContour(
    Canvas canvas,
    Size size,
    double height,
    double slotWidth,
    double scrollOffset,
  ) {
    final voiced = history.all.where((f) => f.hasPitch).toList();
    if (voiced.isEmpty) return;

    // Centre the axis on the median of what has actually been sung, so the
    // trace stays in frame for a bass and a soprano alike without either
    // hitting the ceiling.
    final pitches = voiced.map((f) => f.semitonesAboveC0).toList()..sort();
    final centre = pitches[pitches.length ~/ 2];

    double yFor(double semitones) {
      final offset = (semitones - centre) / _semitoneSpan;
      return height * (0.5 - offset);
    }

    if (referenceContour != null) {
      _strokeContour(
        canvas,
        size,
        referenceContour!.asMap().entries.map((e) {
          final slot = windowFrames - referenceContour!.length + e.key;
          return (
            Offset(
              slot * slotWidth + scrollOffset + slotWidth / 2,
              yFor(e.value),
            ),
            1.0,
          );
        }).toList(),
        referenceColor,
        strokeWidth: 2,
        dashed: true,
      );
    }

    // Split into runs of consecutive voiced frames. Each run is its own path,
    // which is what produces a gap across a breath rather than a line through
    // it.
    final runs = <List<(Offset, double)>>[];
    List<(Offset, double)> current = [];

    for (var i = 0; i < history.length; i++) {
      final frame = history[i];
      final slot = windowFrames - history.length + i;
      final x = slot * slotWidth + scrollOffset + slotWidth / 2;

      if (frame.hasPitch) {
        current.add((
          Offset(x, yFor(frame.semitonesAboveC0)),
          frame.pitchConfidence,
        ));
      } else if (current.isNotEmpty) {
        runs.add(current);
        current = [];
      }
    }
    if (current.isNotEmpty) runs.add(current);

    for (final run in runs) {
      _strokeContour(canvas, size, run, contourColor, strokeWidth: 2.5);
    }
  }

  /// Strokes a contour segment by segment so each can carry the confidence of
  /// its own frame — a breathy passage fades rather than being drawn as
  /// confidently as a clean sustained note.
  void _strokeContour(
    Canvas canvas,
    Size size,
    List<(Offset, double)> points,
    Color color, {
    required double strokeWidth,
    bool dashed = false,
  }) {
    if (points.length < 2) {
      if (points.length == 1) {
        final (point, confidence) = points.first;
        canvas.drawCircle(
          point,
          strokeWidth / 2,
          Paint()..color = color.withValues(alpha: 0.3 + 0.7 * confidence),
        );
      }
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < points.length - 1; i++) {
      final (from, fromConfidence) = points[i];
      final (to, _) = points[i + 1];
      if (dashed && i.isOdd) continue;

      paint.color = color.withValues(alpha: 0.25 + 0.75 * fromConfidence);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_VisualiserPainter old) => true;
}
