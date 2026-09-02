import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sensory/sensory_director.dart';
import '../../../domain/sensory/sensory_cue.dart';
import '../../../ui/tokens/motion.dart';
import '../../../ui/tokens/spacing.dart';
import '../../../ui/tokens/theme.dart';
import '../../../ui/tokens/typography.dart';

/// The brief, one beat at a time, before the exercise begins.
///
/// The brief used to be a paragraph of caption text above the script — present,
/// and therefore skipped. Reading it is the difference between practising a
/// thing and reading a passage aloud, so it gets the screen to itself and the
/// user has to tap through it.
///
/// Pacing is the whole design. One beat is on screen at a time in large type;
/// a tap brings the next; and only once the last one has landed does the
/// continue prompt fade in and blink. Chunking comes from the author's own
/// punctuation — see `briefChunks`.
///
/// **Reduced motion keeps the pacing and drops the movement.** The reveal is
/// immediate rather than faded and the prompt does not blink, but the taps are
/// unchanged: someone who needs reduced motion still decides when to move on.
/// Removing the taps would be taking the control away from precisely the person
/// most likely to want it.
class PreExerciseCards extends StatefulWidget {
  const PreExerciseCards({
    super.key,
    required this.title,
    required this.chunks,
    required this.sensory,
    required this.onDone,
    this.onBack,
  });

  final String title;
  final List<String> chunks;
  final SensoryDirector sensory;
  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<PreExerciseCards> createState() => _PreExerciseCardsState();
}

class _PreExerciseCardsState extends State<PreExerciseCards>
    with SingleTickerProviderStateMixin {
  static const _choreography = FeedbackChoreography();

  int _index = 0;
  bool _promptVisible = false;

  /// Held so it can be cancelled. A bare `Future.delayed` outlives the widget
  /// if the user backs out mid-brief, and fires into a disposed State.
  Timer? _promptTimer;

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: FeedbackChoreography.briefBlink,
  );

  bool get _onLastChunk => _index >= widget.chunks.length - 1;

  @override
  void initState() {
    super.initState();
    // A single-chunk brief is already on its last card. Deferred to the first
    // frame because arming reads MediaQuery, which is not available in
    // initState.
    if (_onLastChunk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _armPrompt();
      });
    }
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _blink.dispose();
    super.dispose();
  }

  /// Shows the continue prompt once the final card has had time to be read.
  void _armPrompt() {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final delay = reduced
        ? Duration.zero
        : FeedbackChoreography.briefPromptDelay;

    _promptTimer?.cancel();
    _promptTimer = Timer(delay, () {
      if (!mounted || _promptVisible) return;
      setState(() => _promptVisible = true);
      widget.sensory.play(_choreography.forBriefComplete());
      // The blink is motion, so reduced motion leaves the prompt simply
      // visible — the same end state, without the loop.
      if (!reduced) _blink.repeat(reverse: true);
    });
  }

  void _advance() {
    widget.sensory.syncWith(context);

    if (_onLastChunk) {
      widget.onDone();
      return;
    }

    widget.sensory.play(_choreography.forBriefAdvance());
    setState(() => _index++);
    if (_onLastChunk) _armPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reveal = ResMotion.duration(
      context,
      FeedbackChoreography.briefReveal,
    );

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        title: Text(widget.title, style: ResType.caption),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: SafeArea(
          child: Semantics(
            button: true,
            // The whole screen is the control, so it says what a tap does
            // rather than leaving a screen reader to infer it from a prompt
            // that is not there yet.
            label: _promptVisible
                ? '${widget.chunks[_index]} Tap to begin the exercise.'
                : '${widget.chunks[_index]} '
                      'Card ${_index + 1} of ${widget.chunks.length}. '
                      'Tap for the next.',
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: AnimatedSwitcher(
                      duration: reveal,
                      switchInCurve: ResMotion.enter,
                      switchOutCurve: ResMotion.exit,
                      // Fading only — no slide. The text is being read, and
                      // moving it while someone starts reading is worse than
                      // not animating at all.
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        widget.chunks[_index],
                        key: ValueKey(_index),
                        style: ResType.hero.copyWith(
                          color: colors.ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ResSpace.loose),
                  SizedBox(
                    height: 28,
                    child: _promptVisible
                        ? FadeTransition(
                            // Keyed so a test can read this opacity without
                            // also catching the card's own fade.
                            key: const ValueKey('continue-prompt-blink'),
                            opacity: _blink.drive(Tween(begin: 1.0, end: 0.35)),
                            child: Text(
                              'Tap to continue',
                              style: ResType.label.copyWith(
                                color: colors.accentInk,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  _Progress(
                    count: widget.chunks.length,
                    index: _index,
                    color: colors.accent,
                    rule: colors.ruleSoft,
                  ),
                  const SizedBox(height: ResSpace.loose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far through the brief the user is. Small, and not tappable — this is
/// orientation, not navigation.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.count,
    required this.index,
    required this.color,
    required this.rule,
  });

  final int count;
  final int index;
  final Color color;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: ResMotion.duration(context, ResMotion.control),
              width: i == index ? 22 : 8,
              height: 3,
              decoration: BoxDecoration(
                color: i <= index ? color : rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
