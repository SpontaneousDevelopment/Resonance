import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:resonance/app/app.dart';
import 'package:resonance/features/skill_tree/lesson_node.dart';

import 'test_window.dart';

/// End-to-end coverage of the path a user actually walks.
///
/// This file exists because two bugs in a row got through a green unit suite
/// and were found in the first minute of real use:
///
/// 1. The lesson route was never wired to the controller, so stopping a
///    recording went nowhere. Every screen passed its own tests.
/// 2. A missing `NSSpeechRecognitionUsageDescription` made the OS terminate the
///    process on Record — `SIGABRT`, no Dart error, nothing catchable.
///
/// Neither is reachable from a widget test. The first needs the real router;
/// the second needs the real app binary and the real permission system. Both
/// are trivially caught here.
///
/// Run with:
///   fvm flutter test integration_test -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(keepTestWindowOnScreen);

  /// Opens a unit and enters one of its lessons, which is now two taps rather
  /// than one — a unit expands in place, and the lesson is chosen from the list.
  Future<void> openLesson(WidgetTester tester, String lessonTitle) async {
    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text(lessonTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> launch(WidgetTester tester) async {
    // The real macOS window is whatever size it happens to be, and a short one
    // leaves the lower units of the tree unbuilt — a sliver list only builds
    // what is on screen, so `find` genuinely cannot see them. Pin a tall
    // viewport so the assertions are about the app, not the window.
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ResonanceApp()));
    // The curriculum loads from the bundle, so give it a real frame or two
    // rather than pumpAndSettle — the visualiser's ticker never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the tree renders from the bundled curriculum', (tester) async {
    await launch(tester);

    expect(find.text('Foundations'), findsWidgets);
    expect(find.text('Articulation & Diction'), findsOneWidget);
    expect(find.text('Foundations Check'), findsOneWidget);
  });

  testWidgets('an authored unit opens its first lesson', (tester) async {
    // Bug 1. In a widget test this path cannot be exercised at all — building
    // the lesson screen constructs the speech recogniser, which blocks forever
    // with no platform behind it. Here there is a platform.
    await launch(tester);

    // Expanding first. The unit card used to jump straight into its first
    // playable lesson; choosing a lesson is now a real step.
    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Plosive Precision'),
      findsOneWidget,
      reason: 'the unit should have expanded to list its lessons',
    );
    expect(
      find.text('Check my room'),
      findsNothing,
      reason: 'expanding a unit must not enter a lesson',
    );

    await tester.tap(find.text('Plosive Precision'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Plosive Precision'), findsWidgets);
    expect(find.text('Check my room'), findsOneWidget);
    // The script the user reads, not the direction.
    expect(find.textContaining('Peter picked a bitter batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the script contains no coaching direction', (tester) async {
    // Regression guard for the content bug: direction belongs in the brief.
    await launch(tester);
    await openLesson(tester, 'Plosive Precision');

    final script = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(
          (t) => t.contains('Peter picked a bitter batch'),
          orElse: () => '',
        );

    expect(script, isNotEmpty, reason: 'the script was not on screen');

    expect(script, isNot(contains('Keep the tempo')));
    expect(script, isNot(contains('Do not push')));
  });

  testWidgets('a locked unit does not open', (tester) async {
    await launch(tester);

    await tester.tap(find.text('Breath & Support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Still on the tree, and it did not expand either — a locked unit does not
    // reveal its lessons any more than it opens one.
    expect(find.text('Articulation & Diction'), findsOneWidget);
    expect(find.text('Check my room'), findsNothing);
    expect(find.byType(LessonNode), findsNothing);
  });

  testWidgets('back returns to the tree', (tester) async {
    await launch(tester);
    await openLesson(tester, 'Plosive Precision');
    expect(find.text('Check my room'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Foundations Check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
