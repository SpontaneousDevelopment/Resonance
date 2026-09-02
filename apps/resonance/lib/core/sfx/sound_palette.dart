import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/sensory/sensory_cue.dart';

/// Plays a short asset. Abstracted so the palette's behaviour can be asserted
/// against real playback rather than against its own bookkeeping.
abstract interface class SoundPlayer {
  /// Plays the asset, returning the duration reported when it was *loaded*, or
  /// null when it came from cache. The duration is what makes a swapped file
  /// observable: a replacement of a different length reports a different one.
  Future<Duration?> play(String assetPath);
  Future<void> dispose();

  /// Drops any cached decoding so the next [play] re-reads the asset.
  ///
  /// Exists for one reason: swapping a `.wav` on disk during development has no
  /// audible effect while a preloaded player still holds the old one, and the
  /// only way to hear a replacement was to kill the process. See
  /// [SoundPalette.reloadAssetsFromDisk].
  Future<void> evictCache();
}

/// Records every playback request. For tests.
///
/// The point of this existing: a test can assert the bus is *silent* during
/// capture by checking nothing reached the player, rather than checking that a
/// duck flag was set — which would pass even if the sound still played.
class RecordingSoundPlayer implements SoundPlayer {
  final List<String> played = [];

  final List<String> loads = [];

  @override
  Future<Duration?> play(String assetPath) async {
    // Mirrors the real player: a cache miss is a load, a hit is not.
    played.add(assetPath);
    if (_loaded.add(assetPath)) {
      loads.add(assetPath);
      return const Duration(milliseconds: 1);
    }
    return null;
  }

  final Set<String> _loaded = {};

  @override
  Future<void> evictCache() async => _loaded.clear();

  @override
  Future<void> dispose() async {}
}

/// The UI sound palette, and the mute rules around it.
///
/// Ducking is reference-counted. Both the recorder and reference playback duck
/// the bus, and they overlap during a shadow-read lesson — a boolean would let
/// whichever finished first unmute while the other was still capturing, and a
/// chime landing in the middle of a take is recorded by the microphone.
class SoundPalette {
  SoundPalette({SoundPlayer? player, this.enabled = true})
    : _player = player ?? _JustAudioPlayer();

  final SoundPlayer _player;

  /// User-facing sound setting. When false nothing plays, ever.
  bool enabled;

  int _duckDepth = 0;

  /// True while anything holds a duck. No sound reaches the player.
  bool get isDucked => _duckDepth > 0;

  /// True when a cue would actually be heard right now.
  bool get isAudible => enabled && !isDucked;

  /// Asset paths per cue. A manifest rather than a switch so the files can be
  /// replaced without touching code — see `assets/sfx/CREDITS.md`.
  static const assets = <SoundCue, String>{
    SoundCue.tap: 'assets/sfx/tap.wav',
    SoundCue.correct: 'assets/sfx/correct.wav',
    SoundCue.mistake: 'assets/sfx/mistake.wav',
    SoundCue.recordStart: 'assets/sfx/record_start.wav',
    SoundCue.recordStop: 'assets/sfx/record_stop.wav',
    SoundCue.streakSave: 'assets/sfx/streak_save.wav',
    SoundCue.levelUp: 'assets/sfx/level_up.wav',
    SoundCue.masteryUnlock: 'assets/sfx/mastery_unlock.wav',
  };

  /// Silences the bus while audio is being captured or a reference is playing.
  ///
  /// Returns a handle whose [DuckHandle.release] is idempotent. Callers should
  /// hold the handle and release it from every exit path rather than pairing
  /// bare `duck`/`unduck` calls: a pair separated by an early return, a throw,
  /// or a widget disposal leaks a duck, and because the palette outlives any
  /// one lesson the bus then stays muted for the rest of the app's life.
  DuckHandle duckForCapture() {
    _duckDepth++;
    return DuckHandle._(this);
  }

  /// Releases one duck. Prefer the handle returned by [duckForCapture].
  void unduck() {
    if (_duckDepth > 0) _duckDepth--;
  }

  /// Drops every outstanding duck. For teardown, where a leaked duck would
  /// leave the app permanently silent.
  void clearDucks() => _duckDepth = 0;

  /// Plays a cue, if anything should be heard.
  ///
  /// Returns early *before* reaching the player when muted or ducked — the bus
  /// is genuinely silent, not playing at zero volume where a stray unduck could
  /// expose it mid-take.
  Future<Duration?> play(SoundCue cue) async {
    if (!isAudible) return null;

    final path = assets[cue];
    if (path == null) return null;

    try {
      return await _player.play(path);
    } catch (error) {
      // A missing or unplayable asset must never break a lesson. Logged once
      // per cue so a missing file is visible in development without flooding.
      if (_warned.add(cue)) {
        debugPrint('Sound asset unavailable for ${cue.name} ($path): $error');
      }
      return null;
    }
  }

  final Set<SoundCue> _warned = {};

  Future<void> dispose() => _player.dispose();

  /// Drops the preloaded players so the next cue re-reads its asset.
  ///
  /// **Debug builds only, and a no-op in release** — not merely hidden behind a
  /// debug-only screen. A dev convenience that stays callable in production is
  /// one refactor away from becoming production behaviour, and this one would
  /// reintroduce load latency on every cue, putting a "correct" chime a beat
  /// behind the score it belongs to. The guard is here rather than at the call
  /// site so there is exactly one place it can be got wrong.
  Future<void> reloadAssetsFromDisk() async {
    if (!kDebugMode) return;

    // Three caches sit between a file on disk and a sound, and dropping any two
    // of them changes nothing audible. This was found by swapping a real file
    // rather than by reading the code: evicting only the players still played
    // the old sound, because just_audio had already extracted the asset and
    // Flutter had already cached its bytes.
    await _player.evictCache();
    for (final path in assets.values) {
      rootBundle.evict(path);
    }
    _warned.clear();
  }
}

/// One outstanding duck.
///
/// Releasing twice is a no-op rather than an error: an exit path that fires
/// both on failure and again on teardown is normal, and a double release that
/// silently opened the bus mid-take would be far worse than one ignored.
class DuckHandle {
  DuckHandle._(this._palette);

  final SoundPalette _palette;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    _palette.unduck();
  }
}

/// Real playback.
///
/// One player per cue, preloaded, so a cue fires without the load latency that
/// would put a "correct" chime a beat behind the score it belongs to.
class _JustAudioPlayer implements SoundPlayer {
  final Map<String, AudioPlayer> _players = {};

  @override
  Future<Duration?> play(String assetPath) async {
    final player = _players.putIfAbsent(assetPath, AudioPlayer.new);
    Duration? loaded;
    if (player.audioSource == null) {
      loaded = await player.setAsset(assetPath);
      if (kDebugMode) {
        // The signal that a swapped file actually took.
        debugPrint('sfx loaded $assetPath (${loaded?.inMilliseconds}ms)');
      }
    }
    await player.seek(Duration.zero);
    unawaited(player.play());
    return loaded;
  }

  @override
  Future<void> evictCache() async {
    // Disposing and clearing rather than calling setAsset again: just_audio
    // holds the decoded source on the player, and the map rebuilds lazily on
    // the next play, so this is self-healing rather than leaving a dead cache.
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    // And the copies just_audio extracted out of the bundle to play from.
    await AudioPlayer.clearAssetCache();
  }

  @override
  Future<void> dispose() => evictCache();
}

final soundPaletteProvider = Provider<SoundPalette>((ref) {
  final palette = SoundPalette();
  ref.onDispose(palette.dispose);
  return palette;
});
