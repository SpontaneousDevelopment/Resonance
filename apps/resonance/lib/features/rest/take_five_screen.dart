import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/sensory/breath_cycle.dart';

import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// Offered when Vocal Energy runs out.
///
/// A real exercise rather than a countdown, because the meter is a vocal-health
/// signal and a bare timer would expose it as a gate wearing a health costume.
/// This is box breathing plus a semi-occluded vocal tract exercise — a
/// straw-phonation hum — which is standard practice for resetting a tired voice
/// and something a working actor uses between takes.
///
/// **Always skippable.** Practice is never blocked; that is the whole design.
class TakeFiveScreen extends StatefulWidget {
  const TakeFiveScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  /// Called when the full cycle finishes. Restores energy.
  final VoidCallback onComplete;

  /// Called if the user leaves early. Restores nothing, blocks nothing.
  final VoidCallback onSkip;

  @override
  State<TakeFiveScreen> createState() => _TakeFiveScreenState();
}

class _TakeFiveScreenState extends State<TakeFiveScreen>
    with SingleTickerProviderStateMixin {
  /// Four rounds of box breathing, then a hum, then a swallow-and-rest.
  ///
  /// Roughly ninety seconds. Long enough for the larynx to actually settle and
  /// short enough that someone mid-session will do it rather than skip.
  /// Four rounds of box breathing, a hum, then a swallow and rest.
  ///
  /// Each phase declares what the circle does. Previously that was inferred by
  /// string-matching the label, which had no case for *hold* — so hold shrank.
  static const _cycle = BreathCycle([
    BreathPhase(
      label: 'Breathe in',
      seconds: 4,
      shape: BreathShape.expand,
      detail: 'Through the nose. Let the belly move, not the chest.',
    ),
    BreathPhase(
      label: 'Hold',
      seconds: 4,
      shape: BreathShape.hold,
      detail: 'Stay relaxed. No squeezing in the throat.',
    ),
    BreathPhase(
      label: 'Breathe out',
      seconds: 6,
      shape: BreathShape.contract,
      detail: 'Slow and even, as if through a straw.',
    ),
    BreathPhase(
      label: 'Rest',
      seconds: 2,
      shape: BreathShape.rest,
      detail: 'Do nothing at all.',
    ),
    BreathPhase(
      label: 'Breathe in',
      seconds: 4,
      shape: BreathShape.expand,
      detail: 'Softer this time.',
    ),
    BreathPhase(
      label: 'Hold',
      seconds: 4,
      shape: BreathShape.hold,
      detail: 'Jaw loose. Tongue heavy.',
    ),
    BreathPhase(
      label: 'Breathe out',
      seconds: 6,
      shape: BreathShape.contract,
      detail: 'Longer than the breath in.',
    ),
    BreathPhase(label: 'Rest', seconds: 2, shape: BreathShape.rest),
    BreathPhase(
      label: 'Hum, quietly',
      seconds: 10,
      shape: BreathShape.hold,
      detail:
          'Lips lightly closed, the gentlest sound you can make. This takes '
          'the pressure off your vocal folds while keeping them moving.',
    ),
    BreathPhase(
      label: 'Rest',
      seconds: 4,
      shape: BreathShape.rest,
      detail: 'Let the hum fade. Do not clear your throat.',
    ),
    BreathPhase(
      label: 'Hum, quietly',
      seconds: 10,
      shape: BreathShape.hold,
      detail: 'A little higher. Still gentle.',
    ),
    BreathPhase(
      label: 'Swallow, then rest',
      seconds: 8,
      shape: BreathShape.rest,
      detail:
          'A swallow resets the muscles around the larynx better than a cough, '
          'which only irritates them further.',
    ),
    BreathPhase(
      label: 'Breathe in',
      seconds: 4,
      shape: BreathShape.expand,
      detail: 'Last round.',
    ),
    BreathPhase(
      label: 'Breathe out',
      seconds: 6,
      shape: BreathShape.contract,
      detail: 'All the way to the end of the breath.',
    ),
  ]);

  /// Elapsed time, advanced by a ticker.
  ///
  /// The single source of truth. Everything visible is derived from it, so a
  /// rebuild — from a coach note, a theme change, anything — recomputes the
  /// same state rather than restarting an animation mid-cycle.
  Duration _elapsed = Duration.zero;
  Ticker? _ticker;
  bool _finished = false;

  BreathState get _state => _cycle.stateAt(_elapsed);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _finished) return;
    setState(() => _elapsed = elapsed);

    if (_elapsed >= _cycle.total) {
      _finished = true;
      _ticker?.stop();
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = _state;
    final phase = state.phase;

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: ResSpace.loose),
              Text(
                'TAKE FIVE',
                style: ResType.label.copyWith(color: colors.inkFaint),
              ),
              const SizedBox(height: ResSpace.tight),
              Text(
                'Your voice has been working hard.',
                style: ResType.title.copyWith(color: colors.ink),
              ),
              const SizedBox(height: ResSpace.tight),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  'Ninety seconds of this will do more for your next take than '
                  'another attempt would.',
                  style: ResType.body.copyWith(color: colors.inkMuted),
                ),
              ),

              Expanded(
                child: Center(
                  child: _BreathCircle(
                    // Size is a value, not a tween target — the widget draws
                    // exactly what the model says for this instant.
                    scale: state.scale,
                    color: phase.shape == BreathShape.hold
                        ? colors.tier2
                        : colors.accent,
                    label: '${state.secondsRemaining}',
                  ),
                ),
              ),

              Text(
                phase.label,
                textAlign: TextAlign.center,
                style: ResType.heading.copyWith(color: colors.ink),
              ),
              const SizedBox(height: ResSpace.tight),
              SizedBox(
                height: 56,
                child: Text(
                  phase.detail,
                  textAlign: TextAlign.center,
                  style: ResType.caption.copyWith(color: colors.inkMuted),
                ),
              ),

              const SizedBox(height: ResSpace.base),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: state.cycleProgress,
                  minHeight: 3,
                  backgroundColor: colors.ruleSoft,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              ),
              const SizedBox(height: ResSpace.base),

              // Never a hard block. The wording matters: this is an offer the
              // user is declining, not a paywall they are escaping.
              TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip — I want to keep going'),
              ),
              const SizedBox(height: ResSpace.base),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle that expands on the in-breath and contracts on the out.
///
/// The animation *is* the instruction — people follow a moving shape more
/// reliably than a number, and it means the exercise works with the phone at
/// arm's length or in peripheral vision.
/// Draws the circle at a given scale.
///
/// No implicit animation. The previous version used an [AnimatedContainer]
/// whose target was a boolean and whose duration was the phase length, which
/// meant "hold" animated *towards the small size* for four seconds. Size is now
/// whatever the model says for this instant, and smoothness comes from the
/// ticker rebuilding every frame.
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({
    required this.scale,
    required this.color,
    required this.label,
  });

  /// 0 at rest, 1 fully expanded.
  final double scale;
  final Color color;
  final String label;

  static const _minSize = 130.0;
  static const _maxSize = 240.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = _minSize + (_maxSize - _minSize) * scale.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: ResType.metricLarge.copyWith(color: colors.ink),
          ),
        ),
      ),
    );
  }
}
