import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sensory/sensory_cue.dart';
import '../haptics/haptic_engine.dart';
import '../sfx/sound_palette.dart';

/// Plays a choreographed sequence.
///
/// Timing is delegated to an injectable scheduler so tests can assert the
/// *offsets* a sequence fires at rather than only that it fired. A director
/// that called `Future.delayed` directly would be testable for content and
/// untestable for choreography, which is the half that decides whether this
/// feels designed.
typedef CueScheduler = Future<void> Function(Duration delay);

Future<void> _realDelay(Duration delay) =>
    delay <= Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

class SensoryDirector {
  SensoryDirector({
    required this.haptics,
    required this.sounds,
    this.choreography = const FeedbackChoreography(),
    CueScheduler? scheduler,
  }) : _wait = scheduler ?? _realDelay;

  final HapticEngine haptics;
  final SoundPalette sounds;
  final FeedbackChoreography choreography;
  final CueScheduler _wait;

  /// When true, every cue in a sequence fires at once rather than in sequence.
  ///
  /// Reduced motion removes *pacing*, not *feedback*: a user who cannot see the
  /// ring fill still gets told they levelled up. The end state is identical —
  /// the same cues, in the same order, without the choreography between them.
  bool reduceMotion = false;

  Timer? _running;

  /// Plays a sequence. Cancels anything already in flight, so a user tapping
  /// through two results quickly does not hear them overlap.
  Future<void> play(List<SensoryCue> cues) async {
    cancel();
    if (cues.isEmpty) return;

    var elapsed = Duration.zero;
    for (final cue in cues) {
      final wait = reduceMotion ? Duration.zero : cue.at - elapsed;
      if (wait > Duration.zero) {
        await _wait(wait);
        elapsed = cue.at;
      }
      await _fire(cue);
    }
  }

  Future<void> _fire(SensoryCue cue) async {
    final sound = cue.sound;
    if (sound != null) await sounds.play(sound);

    final haptic = cue.haptic;
    // Asking an unsupported engine is harmless, but skipping keeps the intent
    // explicit: macOS plays nothing and gets nothing in its place.
    if (haptic != null && haptics.isSupported) await haptics.play(haptic);
  }

  void cancel() {
    _running?.cancel();
    _running = null;
  }

  /// Reads the platform's reduced-motion setting.
  void syncWith(BuildContext context) {
    reduceMotion = MediaQuery.disableAnimationsOf(context);
  }
}

final sensoryDirectorProvider = Provider<SensoryDirector>((ref) {
  return SensoryDirector(
    haptics: ref.watch(hapticEngineProvider),
    sounds: ref.watch(soundPaletteProvider),
  );
});
