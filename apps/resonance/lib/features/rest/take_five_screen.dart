import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// One phase of the rest cycle.
class _Phase {
  const _Phase(this.label, this.seconds, this.detail);

  final String label;
  final int seconds;

  /// Why this phase exists. Shown quietly beneath the count — a user who
  /// understands what a phase is for will actually do it, and this is a
  /// technique they should end up using in a booth without the app.
  final String detail;
}

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

class _TakeFiveScreenState extends State<TakeFiveScreen> {
  /// Four rounds of box breathing, then a hum, then a swallow-and-rest.
  ///
  /// Roughly ninety seconds. Long enough for the larynx to actually settle and
  /// short enough that someone mid-session will do it rather than skip.
  static const _cycle = <_Phase>[
    _Phase(
      'Breathe in',
      4,
      'Through the nose. Let the belly move, not the chest.',
    ),
    _Phase('Hold', 4, 'Stay relaxed. No squeezing in the throat.'),
    _Phase('Breathe out', 6, 'Slow and even, as if through a straw.'),
    _Phase('Rest', 2, 'Do nothing at all.'),
    _Phase('Breathe in', 4, 'Softer this time.'),
    _Phase('Hold', 4, 'Jaw loose. Tongue heavy.'),
    _Phase('Breathe out', 6, 'Longer than the breath in.'),
    _Phase('Rest', 2, ''),
    _Phase(
      'Hum, quietly',
      10,
      'Lips lightly closed, the gentlest sound you can make. This takes the '
          'pressure off your vocal folds while keeping them moving.',
    ),
    _Phase('Rest', 4, 'Let the hum fade. Do not clear your throat.'),
    _Phase('Hum, quietly', 10, 'A little higher. Still gentle.'),
    _Phase(
      'Swallow, then rest',
      8,
      'A swallow resets the muscles around the larynx better than a cough, '
          'which only irritates them further.',
    ),
    _Phase('Breathe in', 4, 'Last round.'),
    _Phase('Breathe out', 6, 'All the way to the end of the breath.'),
  ];

  int _index = 0;
  int _remaining = _cycle.first.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_remaining > 1) {
        _remaining--;
        return;
      }
      if (_index >= _cycle.length - 1) {
        _timer?.cancel();
        widget.onComplete();
        return;
      }
      _index++;
      _remaining = _cycle[_index].seconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _progress {
    final done = _cycle.take(_index).fold<int>(0, (s, p) => s + p.seconds);
    final total = _cycle.fold<int>(0, (s, p) => s + p.seconds);
    final elapsed = done + (_cycle[_index].seconds - _remaining);
    return elapsed / total;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phase = _cycle[_index];
    final isBreathIn = phase.label.startsWith('Breathe in');
    final isHum = phase.label.startsWith('Hum');

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
                    expanded: isBreathIn || isHum,
                    seconds: phase.seconds,
                    color: isHum ? colors.tier2 : colors.accent,
                    label: '$_remaining',
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
                  value: _progress,
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
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({
    required this.expanded,
    required this.seconds,
    required this.color,
    required this.label,
  });

  final bool expanded;
  final int seconds;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      // Matches the phase length so the circle finishes moving exactly as the
      // phase ends. With reduced motion it snaps and the number carries it.
      duration: reduceMotion ? Duration.zero : Duration(seconds: seconds),
      curve: Curves.easeInOut,
      width: expanded ? 240 : 130,
      height: expanded ? 240 : 130,
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
    );
  }
}
