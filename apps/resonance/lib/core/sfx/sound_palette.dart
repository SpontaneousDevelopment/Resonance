import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/sensory/sensory_cue.dart';

/// Plays a short asset. Abstracted so the palette's behaviour can be asserted
/// against real playback rather than against its own bookkeeping.
abstract interface class SoundPlayer {
  Future<void> play(String assetPath);
  Future<void> dispose();
}

/// Records every playback request. For tests.
///
/// The point of this existing: a test can assert the bus is *silent* during
/// capture by checking nothing reached the player, rather than checking that a
/// duck flag was set — which would pass even if the sound still played.
class RecordingSoundPlayer implements SoundPlayer {
  final List<String> played = [];

  @override
  Future<void> play(String assetPath) async => played.add(assetPath);

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
  Future<void> play(SoundCue cue) async {
    if (!isAudible) return;

    final path = assets[cue];
    if (path == null) return;

    try {
      await _player.play(path);
    } catch (error) {
      // A missing or unplayable asset must never break a lesson. Logged once
      // per cue so a missing file is visible in development without flooding.
      if (_warned.add(cue)) {
        debugPrint('Sound asset unavailable for ${cue.name} ($path): $error');
      }
    }
  }

  final Set<SoundCue> _warned = {};

  Future<void> dispose() => _player.dispose();
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
  Future<void> play(String assetPath) async {
    final player = _players.putIfAbsent(assetPath, AudioPlayer.new);
    if (player.audioSource == null) {
      await player.setAsset(assetPath);
    }
    await player.seek(Duration.zero);
    unawaited(player.play());
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

final soundPaletteProvider = Provider<SoundPalette>((ref) {
  final palette = SoundPalette();
  ref.onDispose(palette.dispose);
  return palette;
});
