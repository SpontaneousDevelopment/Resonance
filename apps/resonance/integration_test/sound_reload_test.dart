import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';

import 'test_window.dart';

/// Confirms the debug reload against a real file swap.
///
/// The unit test proves the cache is dropped. It cannot prove a *replaced file
/// is heard*, which is the thing the workflow actually needs — and the first
/// implementation passed the unit test while still playing the old sound,
/// because two further caches sit behind the one it dropped: just_audio
/// extracts assets to its own cache directory, and Flutter caches the bundle
/// bytes. Finding that took swapping a real file; reading the code did not.
///
/// So this swaps a `.wav` inside the running app's own bundle, mid-session,
/// and asserts the loaded duration changes. `tap.wav` is 20ms and `level_up.wav`
/// is 539ms, so the two cannot be confused, and the reported duration is an
/// objective stand-in for "you would hear the difference".
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(keepTestWindowOnScreen);

  /// The asset as it exists in the bundle this test is running out of.
  File bundledAsset(String name) => File(
    '${File(Platform.resolvedExecutable).parent.path}'
    '/../Frameworks/App.framework/Resources/flutter_assets/assets/sfx/$name',
  );

  testWidgets('a swapped file is heard without restarting the app', (
    tester,
  ) async {
    // The swap is performed by `scripts/verify_sound_reload.sh`, from outside
    // the app, because the macOS build is sandboxed and cannot write its own
    // bundle. That is also closer to the real workflow: a developer replaces a
    // file with an editor while the app keeps running.
    final tap = bundledAsset('tap.wav');
    expect(
      tap.existsSync(),
      isTrue,
      reason: 'the bundle layout changed; expected the asset at ${tap.path}',
    );

    final palette = SoundPalette();
    addTearDown(palette.dispose);

    // Warm the cache exactly as ordinary use would.
    final before = await palette.play(SoundCue.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(before, isNotNull, reason: 'the first play should have loaded');
    expect(
      before!.inMilliseconds,
      lessThan(100),
      reason:
          'tap.wav is a 20ms click; ${before.inMilliseconds}ms means the '
          'harness started from an already-swapped bundle',
    );

    // Without a reload the cue does not load again — the problem being fixed.
    final cached = await palette.play(SoundCue.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      cached,
      isNull,
      reason: 'a cached cue must not reload; that is what makes a swap silent',
    );

    // Now wait for the file to change underneath, reloading each time. Polling
    // rather than sleeping a fixed time keeps this honest on a slow machine.
    Duration? after;
    for (var attempt = 0; attempt < 40; attempt++) {
      await palette.reloadAssetsFromDisk();
      after = await palette.play(SoundCue.tap);
      await tester.pump(const Duration(milliseconds: 250));
      if (after != null && after.inMilliseconds > 300) break;
    }

    expect(
      after,
      isNotNull,
      reason: 'after a reload the cue must load from disk again',
    );
    expect(
      after!.inMilliseconds,
      greaterThan(300),
      reason:
          'tap.wav should now hold level_up.wav (539ms) but loaded as '
          '${after.inMilliseconds}ms. Either the swap never happened — run this '
          'through scripts/verify_sound_reload.sh — or the reload drops fewer '
          'caches than it needs to.',
    );
  });
}
