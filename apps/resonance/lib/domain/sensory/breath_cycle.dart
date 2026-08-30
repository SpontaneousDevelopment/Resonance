/// The breathing exercise as a pure function of elapsed time.
///
/// The circle's size was previously `expanded ? big : small`, where `expanded`
/// was derived by string-matching the phase label. That has no state for
/// *hold* — hold fell into the `false` branch, so the circle shrank through it
/// and the visible cycle was grow, shrink, shrink rather than
/// inhale-hold-exhale-rest.
///
/// Size is now a pure function of (phase, progress within phase). Nothing about
/// it depends on when a rebuild happens, so no external trigger can restart or
/// desynchronise it, and the whole cycle is testable against a virtual clock.
library;

/// What the circle does during a phase.
///
/// Explicit rather than inferred from the label: a copy edit should not be able
/// to silently change the animation, which is exactly how *hold* came to shrink.
enum BreathShape {
  /// Grow from small to full.
  expand,

  /// Stay at full. The phase that was missing.
  hold,

  /// Shrink from full to small.
  contract,

  /// Stay small.
  rest,
}

class BreathPhase {
  const BreathPhase({
    required this.label,
    required this.seconds,
    required this.shape,
    this.detail = '',
  });

  final String label;
  final int seconds;
  final BreathShape shape;

  /// Why this phase exists. Someone who understands a phase will actually do
  /// it, and this is a technique they should end up using without the app.
  final String detail;

  Duration get duration => Duration(seconds: seconds);
}

/// A snapshot of the exercise at one instant.
class BreathState {
  const BreathState({
    required this.phaseIndex,
    required this.phase,
    required this.progress,
    required this.scale,
    required this.secondsRemaining,
    required this.cycleProgress,
    required this.isComplete,
  });

  final int phaseIndex;
  final BreathPhase phase;

  /// 0..1 through the current phase.
  final double progress;

  /// 0..1, where 0 is the resting size and 1 is fully expanded.
  final double scale;

  /// Counts down, and reaches 0 only as the phase ends.
  final int secondsRemaining;

  /// 0..1 through the whole exercise.
  final double cycleProgress;

  final bool isComplete;
}

class BreathCycle {
  const BreathCycle(this.phases);

  final List<BreathPhase> phases;

  Duration get total =>
      phases.fold(Duration.zero, (sum, phase) => sum + phase.duration);

  /// The state at [elapsed]. Pure — the same input always gives the same
  /// output, whatever the widget tree has been doing.
  BreathState stateAt(Duration elapsed) {
    if (phases.isEmpty) {
      throw StateError('A breath cycle needs at least one phase');
    }

    final clamped = elapsed < Duration.zero ? Duration.zero : elapsed;
    final totalDuration = total;

    if (clamped >= totalDuration) {
      final last = phases.last;
      return BreathState(
        phaseIndex: phases.length - 1,
        phase: last,
        progress: 1,
        scale: _scaleFor(last.shape, 1),
        secondsRemaining: 0,
        cycleProgress: 1,
        isComplete: true,
      );
    }

    var offset = Duration.zero;
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final end = offset + phase.duration;
      if (clamped < end) {
        final within = clamped - offset;
        final progress = phase.duration.inMicroseconds == 0
            ? 1.0
            : within.inMicroseconds / phase.duration.inMicroseconds;

        return BreathState(
          phaseIndex: i,
          phase: phase,
          progress: progress,
          scale: _scaleFor(phase.shape, progress),
          // Ceil so a phase reads "4" for its first instant and only hits 0 as
          // it ends — a floor would show "3" immediately and skip the count.
          secondsRemaining: ((phase.duration - within).inMilliseconds / 1000)
              .ceil(),
          cycleProgress: clamped.inMicroseconds / totalDuration.inMicroseconds,
          isComplete: false,
        );
      }
      offset = end;
    }

    throw StateError('unreachable');
  }

  /// Size, 0..1, for a shape at a point through it.
  ///
  /// Eased on the moving phases so the breath has the slow start and finish a
  /// real one does; flat on the still phases, because a hold that drifts is not
  /// a hold.
  static double _scaleFor(BreathShape shape, double progress) {
    final t = progress.clamp(0.0, 1.0);
    return switch (shape) {
      BreathShape.expand => _ease(t),
      BreathShape.hold => 1,
      BreathShape.contract => 1 - _ease(t),
      BreathShape.rest => 0,
    };
  }

  /// Ease-in-out. Matches the curve the circle used before, so the movement
  /// itself is unchanged — only which phases move.
  static double _ease(double t) =>
      t < 0.5 ? 2 * t * t : 1 - ((-2 * t + 2) * (-2 * t + 2)) / 2;
}
