import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resonance/app/app.dart';
import 'package:resonance/features/rest/take_five_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

import 'test_window.dart';

/// Frame-cost guards for the paths that actually paint.
///
/// The DSP's own budget is asserted in C, where the algorithm lives. This
/// covers the Flutter side: the two `CustomPainter`s — the mastery rings on the
/// tree and the breathing circle — and the cost of building the lesson screen.
///
/// **Wall-clock per frame, not `FrameTiming`.** The obvious implementation
/// collects `FrameTiming` from `addTimingsCallback` and asserts on
/// `buildDuration`. That was tried and thrown away: timings are delivered
/// asynchronously, and slow frames were still in flight when the measuring
/// window closed. A regression that made one test take five and a half minutes
/// instead of seven seconds passed every `FrameTiming` assertion — a check
/// reporting success while measuring nothing. Wall-clock across a fixed number
/// of pumps cannot miss the work, because the work is what it is waiting for.
///
/// **These run in debug and the thresholds say so.** A debug build carries
/// assertions, unoptimised widget code and no AOT, so it is several times
/// slower than what ships; asserting 16.67 ms here would fail constantly and
/// teach everyone to ignore it. Each threshold below is derived from a measured
/// value recorded in its `reason`, with headroom for a loaded CI runner. That
/// makes these guards against *regression*, not proof of 60 fps on a device —
/// that proof needs a profile-mode run on real hardware and is not claimed.
///
/// **What they can and cannot catch.** The floor here is the live binding's own
/// per-pump cost (~25 ms), so these detect roughly an 80% slowdown or worse.
/// Verified, not assumed: a 200M-iteration loop in the breathing circle's build
/// takes the frame from 25 ms to 219 ms and fails the assertion, while a 20M
/// one costs ~20 ms and passes. They are a tripwire for a cliff, not a
/// regression budget for a few per cent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(keepTestWindowOnScreen);

  /// Average wall-clock milliseconds per pump across [frames] frames.
  Future<double> msPerFrame(WidgetTester tester, int frames) async {
    final clock = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    clock.stop();
    return clock.elapsedMilliseconds / frames;
  }

  Future<void> launch(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ResonanceApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the skill tree scrolls without a frame cost cliff', (
    tester,
  ) async {
    await launch(tester);

    // Warm up, so first-paint of the rings is not counted as steady state.
    await msPerFrame(tester, 10);

    final clock = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 16));
    }
    clock.stop();
    final perDrag = clock.elapsedMilliseconds / 10;

    // 21 mastery rings, each a CustomPainter. A ring that starts allocating or
    // recomputing per frame shows up here immediately.
    expect(
      perDrag,
      lessThan(60.0),
      reason: '${perDrag}ms per scroll step on the tree; measured 31.5ms clean',
    );
  });

  testWidgets('the breathing circle holds its cost for a full cycle', (
    tester,
  ) async {
    // The one screen that animates continuously for ninety seconds, rebuilding
    // every frame by design — and the screen a user is told to close their eyes
    // and breathe with, so a stutter here is felt rather than seen.
    tester.view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // The screen reads design tokens off the theme; a bare MaterialApp
          // has none and it throws on build.
          theme: ResTheme.light(),
          home: TakeFiveScreen(onComplete: () {}, onSkip: () {}),
        ),
      ),
    );
    await tester.pump();
    await msPerFrame(tester, 20);

    final steady = await msPerFrame(tester, 120);

    expect(
      steady,
      lessThan(45.0),
      reason:
          '${steady}ms per animated frame during the breather; measured 25ms clean',
    );
  });

  testWidgets('opening a lesson does not blow the build budget', (
    tester,
  ) async {
    await launch(tester);

    final clock = Stopwatch()..start();
    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    clock.stop();
    final elapsed = clock.elapsedMilliseconds;

    // This builds the speech recogniser and the visualiser. A cliff here is
    // work that should have been deferred off the first frame.
    expect(
      elapsed,
      lessThan(1500),
      reason:
          '${elapsed}ms to open the lesson screen; measured 717ms clean, of which '
          '600ms is the settle pump this test itself asks for',
    );
  });
}
