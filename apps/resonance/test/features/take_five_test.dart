import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/rest/take_five_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// Drives the breather and checks the circle's rendered size.
///
/// The regression: size came from a boolean derived by string-matching the
/// phase label, which had no case for *hold* — so the circle shrank through it.
/// These assert the four-part shape against what is actually painted.
double circleWidth(WidgetTester tester) {
  // The circle is the only SizedBox wrapping a DecoratedBox with a circular
  // shape, which is a stable way to find it without a test-only key.
  final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
  for (final box in boxes) {
    if (box.width != null && box.width == box.height && box.width! >= 130) {
      return box.width!;
    }
  }
  fail('circle not found');
}

Future<void> pumpBreather(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  tester.view
    ..physicalSize = const Size(900, 1800)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ResTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: TakeFiveScreen(onComplete: () {}, onSkip: () {}),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the circle follows the breath', () {
    testWidgets('starts small', (tester) async {
      await pumpBreather(tester);
      expect(circleWidth(tester), 130.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('expands through the inhale', (tester) async {
      await pumpBreather(tester);
      final start = circleWidth(tester);

      await tester.pump(const Duration(seconds: 2));
      final middle = circleWidth(tester);

      await tester.pump(const Duration(milliseconds: 1900));
      final end = circleWidth(tester);

      expect(middle, greaterThan(start));
      expect(end, greaterThan(middle));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('holds steady through the hold', (tester) async {
      // The actual bug. The old implementation shrank from full to small across
      // these four seconds.
      await pumpBreather(tester);
      await tester.pump(const Duration(milliseconds: 4100));

      final samples = <double>[circleWidth(tester)];
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        samples.add(circleWidth(tester));
      }

      expect(
        samples.toSet().length,
        1,
        reason: 'hold is not holding: $samples',
      );
      expect(samples.first, 240.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('contracts through the exhale', (tester) async {
      await pumpBreather(tester);
      await tester.pump(const Duration(milliseconds: 8100));
      final start = circleWidth(tester);

      await tester.pump(const Duration(seconds: 3));
      final later = circleWidth(tester);

      expect(later, lessThan(start));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('rebuilds cannot disturb it', () {
    testWidgets('a mid-cycle rebuild does not reset or jump', (tester) async {
      // The class of bug that caused the fanfare replay: state re-triggered by
      // a rebuild rather than following one continuous timeline. Size is a pure
      // function of elapsed time, so an extra rebuild changes nothing.
      await pumpBreather(tester);
      await tester.pump(const Duration(milliseconds: 2000));
      final before = circleWidth(tester);

      // Several rebuilds with no time passing.
      for (var i = 0; i < 5; i++) {
        await tester.pump(Duration.zero);
      }

      expect(circleWidth(tester), before, reason: 'a rebuild moved the circle');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the phase label survives rebuilds too', (tester) async {
      await pumpBreather(tester);
      await tester.pump(const Duration(milliseconds: 5000));
      expect(find.text('Hold'), findsOneWidget);

      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);

      expect(find.text('Hold'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('rebuild scope', () {
    testWidgets('the static chrome is not rebuilt every frame', (tester) async {
      // The exercise ticks for up to seventy seconds. Before this, setState
      // rebuilt the whole screen each frame — scaffold, headings, the intro
      // paragraph, the skip button — when only the circle, the phase text and
      // the progress bar change.
      //
      // Measured by element identity: a widget that is rebuilt gets a new
      // Widget instance, so holding the same instance across frames proves it
      // was not rebuilt.
      await pumpBreather(tester);

      Widget staticHeadline() =>
          tester.widget(find.text('Your voice has been working hard.'));
      Widget skipButton() => tester.widget(find.byType(TextButton));

      final headlineBefore = staticHeadline();
      final skipBefore = skipButton();

      // Thirty frames of animation.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        identical(staticHeadline(), headlineBefore),
        isTrue,
        reason: 'the headline was rebuilt during the animation',
      );
      expect(
        identical(skipButton(), skipBefore),
        isTrue,
        reason: 'the skip button was rebuilt during the animation',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the circle does still update every frame', (tester) async {
      // The other half: scoping the rebuild must not stop the thing that is
      // supposed to move.
      await pumpBreather(tester);

      final sizes = <double>{};
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        sizes.add(circleWidth(tester));
      }

      expect(
        sizes.length,
        greaterThan(5),
        reason: 'the circle stopped animating',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduced motion', () {
    // The rewrite from AnimatedContainer to a ticker dropped reduced-motion
    // support silently — the old circle collapsed its tween to zero, the new
    // one had no reference to the setting at all. These pin it to the new
    // mechanism specifically.
    testWidgets('the circle snaps rather than travelling', (tester) async {
      await pumpBreather(tester, reduceMotion: true);

      // A fifth of the way into the inhale, an animating circle is partway
      // between sizes; a snapped one is already at its destination.
      await tester.pump(const Duration(milliseconds: 800));
      expect(circleWidth(tester), 240.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it still holds through the hold', (tester) async {
      await pumpBreather(tester, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 4500));

      expect(circleWidth(tester), 240.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it still reaches the small size on the exhale', (
      tester,
    ) async {
      // Snapping must not mean "stuck expanded" — the phases still read.
      await pumpBreather(tester, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 8500));

      expect(circleWidth(tester), 130.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the countdown still carries the timing', (tester) async {
      // Reduced motion removes pacing, not information. With the movement gone
      // the number is the only thing left saying how long a phase has to run.
      await pumpBreather(tester, reduceMotion: true);
      expect(find.text('4'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('normal motion still animates smoothly', (tester) async {
      // The control: without the setting, the circle travels.
      await pumpBreather(tester);
      await tester.pump(const Duration(milliseconds: 800));

      final width = circleWidth(tester);
      expect(width, greaterThan(130.0));
      expect(width, lessThan(240.0), reason: 'it snapped when it should glide');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the exercise is always escapable', () {
    testWidgets('skip is offered from the first frame', (tester) async {
      await pumpBreather(tester);
      expect(find.textContaining('Skip'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
