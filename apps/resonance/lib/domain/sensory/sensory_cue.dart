/// The sensory vocabulary and its timing.
///
/// Pure Dart, deliberately. A choreography that only exists as a sequence of
/// `await Future.delayed` calls inside a widget cannot be tested for *timing* —
/// only for "something fired". Producing a schedule as data means a test can
/// assert that the level-up haptic lands as the ring finishes filling rather
/// than at the same moment as the score, which is the difference between this
/// feeling designed and feeling like three effects triggered at once.
library;

import '../curriculum/mastery.dart';
import '../progress/streak.dart';
import '../progress/vocal_energy.dart';

/// Physical feedback. Mapped per platform by the haptic engine; macOS has no
/// haptic hardware and plays none of these.
enum HapticCue {
  /// A light tick. Buttons, selection.
  tap,

  /// A passing attempt. Light — success should feel like confirmation, not
  /// applause, because it happens many times a session.
  correct,

  /// A low-scoring attempt. Deliberately soft: on this app a poor score is as
  /// often vocal fatigue or a harsh grading call as a real mistake, and the cue
  /// should not imply more fault than that.
  mistake,

  recordStart,
  recordStop,

  /// A streak saved by a freeze. Warm rather than triumphant — the user did not
  /// achieve something, they were caught.
  streakSave,

  /// A mastery promotion.
  levelUp,

  /// A unit gate opening. The rarest event in the product.
  masteryUnlock,
}

/// UI sound. Every file is replaceable without touching code — see the sound
/// manifest under `assets/sfx/`.
enum SoundCue {
  tap,
  correct,
  mistake,
  recordStart,
  recordStop,
  streakSave,
  levelUp,
  masteryUnlock,
}

/// One scheduled moment.
class SensoryCue {
  const SensoryCue({required this.at, this.haptic, this.sound});

  /// Offset from the start of the sequence.
  final Duration at;

  final HapticCue? haptic;
  final SoundCue? sound;

  @override
  String toString() =>
      '${at.inMilliseconds}ms${haptic == null ? '' : ' h:${haptic!.name}'}'
      '${sound == null ? '' : ' s:${sound!.name}'}';

  @override
  bool operator ==(Object other) =>
      other is SensoryCue &&
      other.at == at &&
      other.haptic == haptic &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(at, haptic, sound);
}

/// Builds the sequence for a moment.
///
/// Every method returns a schedule rather than performing anything, so the
/// timing is a value that can be asserted.
class FeedbackChoreography {
  const FeedbackChoreography();

  /// How long the mastery ring takes to fill. Matches `ResMotion.celebrate`;
  /// duplicated here rather than imported because this library stays free of
  /// Flutter, and a mismatch is caught by a test that pins them together.
  static const ringFill = Duration(milliseconds: 640);

  /// How far the sound leads its haptic.
  ///
  /// A deliberate sequencing choice, not a perceptual claim: the sound
  /// announces the moment and the haptic confirms it a beat later. Firing both
  /// at once reads as a single undifferentiated event.
  static const hapticLag = Duration(milliseconds: 40);

  /// The extra beat before a mastery unlock, so it does not collide with the
  /// level-up it always follows.
  static const unlockBeat = Duration(milliseconds: 260);

  /// A button press.
  ///
  /// Kept here rather than played ad hoc at each call site so every cue in the
  /// palette is reachable from one place — `tap` shipped with an asset, an
  /// entry in both registries and no caller at all, which nothing detected
  /// because nothing asserted that a declared cue is reachable.
  ///
  /// Taps go through the normal duck gate, so one during a take is silent. That
  /// is correct rather than incidental: the microphone is open, and the only
  /// button on screen mid-take is Stop.
  List<SensoryCue> forTap() => const [
    SensoryCue(at: Duration.zero, haptic: HapticCue.tap, sound: SoundCue.tap),
  ];

  List<SensoryCue> forRecordingStart() => const [
    SensoryCue(
      at: Duration.zero,
      haptic: HapticCue.recordStart,
      sound: SoundCue.recordStart,
    ),
  ];

  List<SensoryCue> forRecordingStop() => const [
    SensoryCue(
      at: Duration.zero,
      haptic: HapticCue.recordStop,
      sound: SoundCue.recordStop,
    ),
  ];

  /// The feedback screen's sequence.
  ///
  /// Ordering is the product decision: the score lands immediately, the ring
  /// fills, and any celebration arrives *as the ring completes* — so the
  /// physical confirmation is the resolution of the animation rather than
  /// something happening over the top of it.
  List<SensoryCue> forAttempt({
    required int score,
    required PromotionResult promotion,
    required EnergyEvent energyEvent,
    required StreakEvent streakEvent,
    bool unlockedUnit = false,
  }) {
    final cues = <SensoryCue>[];

    // The verdict, immediately. Soft either way.
    final passed = score >= VocalEnergy.lowScoreThreshold;
    cues.add(
      SensoryCue(
        at: Duration.zero,
        haptic: passed ? HapticCue.correct : HapticCue.mistake,
        sound: passed ? SoundCue.correct : SoundCue.mistake,
      ),
    );

    // A promotion resolves as the ring finishes.
    if (promotion.promoted) {
      cues.add(SensoryCue(at: ringFill, sound: SoundCue.levelUp));
      cues.add(SensoryCue(at: ringFill + hapticLag, haptic: HapticCue.levelUp));
    }

    // A unit opening is rarer than a promotion and always follows one, so it
    // gets its own beat rather than stacking.
    if (unlockedUnit) {
      final at = promotion.promoted
          ? ringFill + hapticLag + unlockBeat
          : ringFill;
      cues.add(SensoryCue(at: at, sound: SoundCue.masteryUnlock));
      cues.add(SensoryCue(at: at + hapticLag, haptic: HapticCue.masteryUnlock));
    }

    // A freeze being spent is news the user did not ask for, so it comes last —
    // after the score has been read, not competing with it.
    if (streakEvent == StreakEvent.savedByFreeze) {
      final at = cues.last.at + unlockBeat;
      cues.add(SensoryCue(at: at, sound: SoundCue.streakSave));
      cues.add(SensoryCue(at: at + hapticLag, haptic: HapticCue.streakSave));
    }

    // Running out of energy is deliberately silent. The rest offer is an
    // invitation; announcing it with a sound would make it feel like a penalty,
    // which is the one reading the whole mechanic is designed to avoid.
    return cues;
  }
}
