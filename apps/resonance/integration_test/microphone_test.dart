import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resonance/app/app.dart';

/// Tests that touch the microphone and the speech recogniser.
///
/// **These require permissions to already be granted, and cannot run in CI.**
/// The first access raises a modal system dialog; with nobody to click it the
/// app blocks and the harness kills the run — which then takes down every test
/// that would have run after it. Hence a separate file.
///
/// Grant once by launching the app and pressing "Check my room", then:
///   fvm flutter test integration_test/microphone_test.dart -d macos
///
/// If permissions were reset (`tccutil reset SpeechRecognition app.resonance`)
/// this will hang on the dialog until someone answers it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openLesson(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ResonanceApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('checking the room does not terminate the app', (tester) async {
    // Bug 2. This is the assertion that matters: a missing usage description
    // kills the process outright, so simply *reaching the next line* is the
    // proof. The room check is also where the speech probe now runs, which is
    // exactly the call that used to be fatal.
    await openLesson(tester);

    await tester.tap(find.text('Check my room'));
    await tester.pump();
    // Long enough for the two-second listen plus the speech probe.
    await tester.pump(const Duration(seconds: 4));

    // Whatever the verdict — good room, noisy room, or permission denied — the
    // app must still be alive and rendering.
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
