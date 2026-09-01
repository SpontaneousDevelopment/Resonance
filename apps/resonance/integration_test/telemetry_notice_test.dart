import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resonance/app/app.dart';
import 'package:resonance/core/telemetry/telemetry_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_window.dart';

/// Proves the crash-reporting notice is a gate rather than a claim.
///
/// Deliberately asserts something in both build types, so it is meaningful
/// however it is run:
///
/// * Built with `--dart-define=RESONANCE_INTERNAL_BUILD=true`, the notice must
///   stand in front of the app and the skill tree must be unreachable until it
///   is answered. That is the difference between telling testers and being able
///   to point at where they were told.
/// * Built without it — a store build, and the default everywhere else — the
///   notice must never appear, because there telemetry is off until someone
///   turns it on themselves.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(keepTestWindowOnScreen);

  setUp(() async {
    // SharedPreferences survives between runs on a desktop build, so a previous
    // run that answered the notice would make this one pass without the gate
    // ever being shown. Found by running the whole suite rather than this file
    // alone, which is the only reason it was not a silently useless test.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('telemetry_notice_seen');
    await prefs.remove('telemetry_enabled');
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ResonanceApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the notice matches the build type', (tester) async {
    await launch(tester);

    if (TelemetrySettings.isInternalBuild) {
      expect(
        find.text('It sends crash reports.'),
        findsOneWidget,
        reason:
            'a test build must show the notice before collecting anything — '
            'a notice nobody has to acknowledge is not a notice',
      );
      expect(
        find.text('Foundations Check'),
        findsNothing,
        reason: 'the notice must gate the app, not sit beside it',
      );

      // Answering it lets the app through.
      await tester.tap(find.text('Not this time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Foundations Check'), findsOneWidget);
    } else {
      expect(
        find.text('It sends crash reports.'),
        findsNothing,
        reason:
            'a store build collects nothing until asked, so it has nothing to '
            'give notice about on first launch',
      );
      expect(find.text('Foundations Check'), findsOneWidget);
    }
  });
}
