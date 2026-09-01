import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resonance/app/app.dart';
import 'package:resonance/features/rest/take_five_screen.dart';
import 'package:resonance/ui/charts/live_visualiser.dart';
import 'package:resonance/ui/tokens/theme.dart';

import 'test_window.dart';

/// The accessibility bar, asserted rather than declared.
///
/// Two kinds of check, because they fail differently.
///
/// The **guideline** tests are Flutter's own: contrast, tap-target size, and
/// whether every tappable node has a label at all. They sweep the whole tree
/// and catch the things that are easy to regress by accident.
///
/// The **label** tests name individual components and assert a screen reader
/// would be told the right thing. A label that exists in the source but is not
/// reachable is the tap-cue failure again in a different costume, so each of
/// these was confirmed to fail with its label removed rather than trusted for
/// being green.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(keepTestWindowOnScreen);

  Future<void> launch(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ResonanceApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Two taps now: a unit expands in place, and the lesson is chosen from the
  /// list it reveals.
  Future<void> openLesson(WidgetTester tester) async {
    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Plosive Precision'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('guidelines', () {
    testWidgets('the skill tree meets contrast, tap target and labelling', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launch(tester);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('an expanded unit meets contrast, tap target and labelling', (
      tester,
    ) async {
      // The lesson cards are new interactive surface, and a locked one still
      // has to be readable — it is the thing telling someone what to do next.
      final handle = tester.ensureSemantics();
      await launch(tester);
      await tester.tap(find.text('Articulation & Diction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('the lesson screen meets contrast and labelling', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launch(tester);
      await openLesson(tester);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });

  group('the lesson runner', () {
    testWidgets('the room check is reachable by what it does, not by icon', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launch(tester);
      await openLesson(tester);

      expect(find.bySemanticsLabel('Check my room'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the pitch trace is not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester);
      await openLesson(tester);

      // It is a moving graph with no text. Announced, it talks over the script
      // the user is trying to read.
      //
      // Scoped to the visualiser's own subtree on purpose: an earlier version
      // asserted `find.byType(ExcludeSemantics)` anywhere on screen, which
      // passed happily after the exclusion was removed from the visualiser
      // because something else in the tree still had one.
      expect(
        find.descendant(
          of: find.byType(LiveVisualiser),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
        reason: 'the live visualiser is no longer excluded from semantics',
      );
      handle.dispose();
    });
  });

  group('the breather', () {
    Future<void> pumpBreather(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1200, 2000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ResTheme.light(),
            home: TakeFiveScreen(onComplete: () {}, onSkip: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('the current instruction is announced, not just drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBreather(tester);

      // Done with the eyes closed. A phase that changes silently is the whole
      // exercise lost, so the instruction carries its detail and is a live
      // region.
      expect(
        find.bySemanticsLabel(RegExp('Breathe in')),
        findsWidgets,
        reason: 'the breathing instruction is not exposed to a screen reader',
      );
      handle.dispose();
    });

    testWidgets('the countdown says what it is counting', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBreather(tester);

      expect(
        find.bySemanticsLabel(RegExp(r'seconds left in this phase')),
        findsOneWidget,
        reason: 'the countdown reads as a bare number',
      );
      handle.dispose();
    });

    testWidgets('skipping is reachable and says it costs nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBreather(tester);

      expect(
        find.bySemanticsLabel(RegExp('Skip')),
        findsOneWidget,
        reason: 'the exercise is always skippable — including by screen reader',
      );
      handle.dispose();
    });
  });
}
