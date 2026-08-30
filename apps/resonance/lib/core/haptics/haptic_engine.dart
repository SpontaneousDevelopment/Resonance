import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sensory/sensory_cue.dart';

/// Plays haptics, or honestly reports that it cannot.
abstract interface class HapticEngine {
  /// Whether this device has haptic hardware at all.
  bool get isSupported;

  Future<void> play(HapticCue cue);
}

/// Chooses an engine for the platform.
///
/// macOS gets [NoHaptics] — desktop Macs have no haptic hardware, and a
/// trackpad is not where a user's attention is during a take. It is a genuine
/// no-op with **no substitute**: no sound or motion stands in for the missing
/// layer. macOS feedback is flatter than iOS as an accepted tradeoff, and the
/// choreography is not forked to compensate — one schedule, played by whatever
/// the platform actually has.
HapticEngine defaultHapticEngine() {
  if (Platform.isIOS || Platform.isAndroid) return const PlatformHaptics();
  return const NoHaptics();
}

/// Haptics via the platform's standard feedback API.
///
/// Maps each cue to light / medium / heavy impact or a selection click. These
/// are the four vocabularies both platforms expose without a plugin.
///
/// The upgrade path, when the palette is designed properly: Core Haptics AHAP
/// patterns on iOS and `VibrationEffect.startComposition` on Android, both of
/// which allow real envelopes rather than single impacts. That is a swap behind
/// this interface — nothing above it changes.
class PlatformHaptics implements HapticEngine {
  const PlatformHaptics();

  @override
  bool get isSupported => true;

  @override
  Future<void> play(HapticCue cue) {
    return switch (cue) {
      // Selection clicks are the lightest thing available and the right weight
      // for something that happens constantly.
      HapticCue.tap => HapticFeedback.selectionClick(),

      // Success is frequent, so it stays light — confirmation, not applause.
      HapticCue.correct => HapticFeedback.lightImpact(),

      // Soft on purpose. A poor score here is as often fatigue as fault.
      HapticCue.mistake => HapticFeedback.lightImpact(),

      // Recording boundaries need to be unmistakable without looking: the user
      // is watching a script, not the screen.
      HapticCue.recordStart => HapticFeedback.mediumImpact(),
      HapticCue.recordStop => HapticFeedback.mediumImpact(),

      HapticCue.streakSave => HapticFeedback.mediumImpact(),
      HapticCue.levelUp => HapticFeedback.heavyImpact(),

      // The rarest event in the product earns the strongest cue.
      HapticCue.masteryUnlock => HapticFeedback.heavyImpact(),
    };
  }
}

/// No haptic hardware. Every call is a no-op that completes.
class NoHaptics implements HapticEngine {
  const NoHaptics();

  @override
  bool get isSupported => false;

  @override
  Future<void> play(HapticCue cue) async {}
}

/// Records what it was asked to play. For tests.
class RecordingHaptics implements HapticEngine {
  RecordingHaptics({this.isSupported = true});

  @override
  final bool isSupported;

  final List<HapticCue> played = [];

  @override
  Future<void> play(HapticCue cue) async => played.add(cue);
}

final hapticEngineProvider = Provider<HapticEngine>(
  (ref) => defaultHapticEngine(),
);
