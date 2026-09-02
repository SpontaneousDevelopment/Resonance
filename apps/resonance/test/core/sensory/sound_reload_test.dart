import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';

/// The debug-only asset reload.
///
/// Two things have to hold, and they are different claims. The mechanism must
/// actually drop the cache — a reload that returns without evicting anything is
/// the shape of check this project keeps catching. And it must be inert in
/// release, because a dev convenience left callable in production is one
/// refactor from becoming production behaviour: here it would reintroduce the
/// load latency the preload cache exists to remove.
void main() {
  late RecordingSoundPlayer player;
  late SoundPalette palette;

  setUp(() {
    player = RecordingSoundPlayer();
    palette = SoundPalette(player: player);
  });

  test('the cache means a repeated cue loads once', () async {
    // Establishes the production behaviour the reload has to work around.
    await palette.play(SoundCue.tap);
    await palette.play(SoundCue.tap);
    await palette.play(SoundCue.tap);

    expect(player.played, hasLength(3));
    expect(
      player.loads,
      hasLength(1),
      reason: 'the preload cache should load each asset once',
    );
  });

  test('reloading makes the next play read the asset again', () async {
    await palette.play(SoundCue.tap);
    expect(player.loads, hasLength(1));

    await palette.reloadAssetsFromDisk();
    await palette.play(SoundCue.tap);

    expect(
      player.loads,
      hasLength(2),
      reason:
          'after a reload the same cue must load from disk again, or a swapped '
          'file is still inaudible',
    );
    expect(player.loads, ['assets/sfx/tap.wav', 'assets/sfx/tap.wav']);
  });

  test('it drops every cached asset, not just the last one played', () async {
    await palette.play(SoundCue.tap);
    await palette.play(SoundCue.levelUp);
    expect(player.loads, hasLength(2));

    await palette.reloadAssetsFromDisk();
    await palette.play(SoundCue.tap);
    await palette.play(SoundCue.levelUp);

    expect(player.loads, hasLength(4));
  });

  test('the palette still works normally afterwards', () async {
    await palette.reloadAssetsFromDisk();
    await palette.play(SoundCue.correct);

    expect(player.played, [
      'assets/sfx/correct.wav',
    ], reason: 'evicting must be self-healing, not leave a dead cache');
  });

  test('ducking is unaffected by a reload', () async {
    final duck = palette.duckForCapture();
    await palette.reloadAssetsFromDisk();
    await palette.play(SoundCue.tap);

    expect(
      player.played,
      isEmpty,
      reason: 'a reload must not open the bus mid-take',
    );
    duck.release();
  });

  test('it is inert in a release build', () async {
    // The guard lives in the palette rather than at the call site, so this is
    // the one place it can be got wrong. In a release build `kDebugMode` is a
    // compile-time false and the eviction is unreachable.
    await palette.play(SoundCue.tap);
    await palette.reloadAssetsFromDisk();
    await palette.play(SoundCue.tap);

    if (kDebugMode) {
      expect(player.loads, hasLength(2));
    } else {
      expect(
        player.loads,
        hasLength(1),
        reason: 'release builds must keep the preload cache intact',
      );
    }
  });
}
