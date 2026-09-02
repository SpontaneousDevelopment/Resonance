import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/ui/tokens/motion.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// The modal gesture: a lesson rises from the bottom and drops back down.
///
/// Exercised on the real transition widgets rather than the whole app, because
/// the lesson screen cannot be built in a widget test — it constructs the
/// speech recogniser. The full path is covered in `integration_test/`; what is
/// asserted here is that the transition genuinely travels, that it settles in
/// place, and that reduced motion arrives at the same place without the travel.
void main() {
  /// The offset the page is currently drawn at, in fractions of its size.
  Offset offsetOf(WidgetTester tester) {
    // By key, not by type: macOS's default page transition is itself a
    // SlideTransition, and `.first` was reading Cupertino's rather than ours.
    final slide = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('modal-slide')),
    );
    return slide.position.value;
  }

  Widget host({required bool reduced, required Widget child}) => MaterialApp(
    theme: ResTheme.light(),
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: inner!,
    ),
    home: child,
  );

  /// A stand-in for the lesson page, using the same transition the router does.
  Widget slidingPage(AnimationController c) => SlideTransition(
    key: const ValueKey('modal-slide'),
    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: c,
        curve: ResMotion.enter,
        reverseCurve: ResMotion.exit,
      ),
    ),
    child: const Scaffold(body: Text('lesson')),
  );

  group('entering a lesson', () {
    testWidgets('rises from the bottom rather than appearing', (tester) async {
      late AnimationController c;
      await tester.pumpWidget(
        host(
          reduced: false,
          child: _Driver(
            duration: FeedbackChoreography.lessonEnter,
            build: (controller) {
              c = controller;
              return slidingPage(controller);
            },
          ),
        ),
      );

      expect(offsetOf(tester).dy, 1.0, reason: 'should start fully below');

      c.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final mid = offsetOf(tester).dy;
      expect(
        mid,
        greaterThan(0.0),
        reason: 'still travelling at 120ms, not already arrived',
      );
      expect(mid, lessThan(1.0), reason: 'it has started moving');

      await tester.pump(FeedbackChoreography.lessonEnter);
      expect(offsetOf(tester).dy, 0.0, reason: 'it must settle in place');
    });

    testWidgets('decelerates rather than moving linearly', (tester) async {
      // Weight reads as easing. A linear tween covers equal distance in equal
      // time; this should cover most of the distance early and settle.
      late AnimationController c;
      await tester.pumpWidget(
        host(
          reduced: false,
          child: _Driver(
            duration: FeedbackChoreography.lessonEnter,
            build: (controller) {
              c = controller;
              return slidingPage(controller);
            },
          ),
        ),
      );

      c.forward();
      await tester.pump();
      await tester.pump(FeedbackChoreography.lessonEnter ~/ 2);
      final halfway = 1.0 - offsetOf(tester).dy;

      expect(
        halfway,
        greaterThan(0.6),
        reason:
            'at the halfway point it had covered ${(halfway * 100).round()}% '
            'of the distance — that is close to linear, not decelerating',
      );
    });
  });

  group('leaving', () {
    testWidgets('drops back downward, the way it came', (tester) async {
      late AnimationController c;
      await tester.pumpWidget(
        host(
          reduced: false,
          child: _Driver(
            duration: FeedbackChoreography.lessonEnter,
            value: 1,
            build: (controller) {
              c = controller;
              return slidingPage(controller);
            },
          ),
        ),
      );
      expect(offsetOf(tester).dy, 0.0);

      c.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        offsetOf(tester).dy,
        greaterThan(0.0),
        reason: 'it should be heading down, not fading in place',
      );

      await tester.pump(FeedbackChoreography.lessonEnter);
      expect(offsetOf(tester).dy, 1.0);
    });

    testWidgets('leaves faster than it arrived', (tester) async {
      // Arriving is the app presenting something; leaving is a decision the
      // user has already made, and matching the two makes dismissal reluctant.
      expect(
        FeedbackChoreography.lessonExit,
        lessThan(FeedbackChoreography.lessonEnter),
      );
    });
  });

  group('reduced motion', () {
    testWidgets('arrives in place with no travel', (tester) async {
      late AnimationController c;
      await tester.pumpWidget(
        host(
          reduced: true,
          child: Builder(
            builder: (context) => _Driver(
              duration: ResMotion.duration(
                context,
                FeedbackChoreography.lessonEnter,
              ),
              build: (controller) {
                c = controller;
                return slidingPage(controller);
              },
            ),
          ),
        ),
      );

      c.forward();
      await tester.pump();

      expect(
        offsetOf(tester).dy,
        0.0,
        reason: 'the page should already be in place after one frame',
      );
    });

    testWidgets('with motion enabled one frame is not enough', (tester) async {
      // The inverse, so the test above cannot pass by the slide never running.
      late AnimationController c;
      await tester.pumpWidget(
        host(
          reduced: false,
          child: Builder(
            builder: (context) => _Driver(
              duration: ResMotion.duration(
                context,
                FeedbackChoreography.lessonEnter,
              ),
              build: (controller) {
                c = controller;
                return slidingPage(controller);
              },
            ),
          ),
        ),
      );

      c.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(offsetOf(tester).dy, greaterThan(0.0));
    });
  });
}

/// Hosts an [AnimationController] so a test can drive it directly.
class _Driver extends StatefulWidget {
  const _Driver({required this.duration, required this.build, this.value = 0});

  final Duration duration;
  final double value;
  final Widget Function(AnimationController) build;

  @override
  State<_Driver> createState() => _DriverState();
}

class _DriverState extends State<_Driver> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.value,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.build(_c);
}
