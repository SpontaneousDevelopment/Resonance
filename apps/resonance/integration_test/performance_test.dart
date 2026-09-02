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

  /// What a pump costs with nothing on screen — the harness floor.
  ///
  /// This exists to tell two failures apart, because they had looked identical
  /// and one of them wasted most of a session. A pump here is dominated by
  /// waiting for a real frame from the compositor, not by widget work, so an
  /// empty page costs about the same as the breather does. That makes the floor
  /// a control:
  ///
  /// * **Floor normal, subject slow** → the app got slower. A real regression.
  /// * **Floor slow too** → frames are not being delivered at the usual rate,
  ///   and every measurement in the file is meaningless. That is the
  ///   environment, and it is reported as the environment rather than as the
  ///   breather having regressed by 50x.
  ///
  /// Comparing against the floor also normalises out machine speed, so these
  /// thresholds do not need re-tuning per runner.
  Future<double> harnessFloor(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await msPerFrame(tester, 10);
    return msPerFrame(tester, 30);
  }

  /// Fails with the right diagnosis when the harness itself is not delivering
  /// frames at a usable rate.
  void requireUsableHarness(double floor) {
    expect(
      floor,
      lessThan(120.0),
      reason:
          'the frame harness is delivering a pump every ${floor.round()}ms '
          'against a normal 25-35ms, so nothing measured in this file means '
          'anything. This is the environment, not the app: frames arrive only '
          'as fast as the window is serviced. Re-run; if it persists, see the '
          'backgrounded-window note in CLAUDE.md.',
    );
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
    final floor = await harnessFloor(tester);
    requireUsableHarness(floor);

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
    final floor = await harnessFloor(tester);
    requireUsableHarness(floor);

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
      lessThan(floor * 2.5),
      reason:
          '${steady}ms per animated frame during the breather against a '
          '${floor.round()}ms harness floor. Measured against the floor rather '
          'than an absolute number so a slow machine moves both together and '
          'only a real regression moves them apart',
    );
  });

  testWidgets('opening a lesson does not blow the build budget', (
    tester,
  ) async {
    final floor = await harnessFloor(tester);
    requireUsableHarness(floor);

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
      // 600ms of this is the settle pump the test itself asks for, which is
      // wall-clock regardless; the rest scales with the harness floor so a slow
      // runner does not read as a slow lesson screen.
      lessThan(600 + floor * 30),
      reason:
          '${elapsed}ms to open the lesson screen against a ${floor.round()}ms '
          'harness floor; measured 717ms clean',
    );
  });
}
