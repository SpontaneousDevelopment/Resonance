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

  /// How long a brief card takes to fade in.
  ///
  /// Slower than a control (180ms) and slower than a page (280ms), because the
  /// user is being asked to *read* rather than to notice. A reveal that lands
  /// before the eye has moved to it reads as a flicker; one that takes much
  /// longer than this reads as the app being slow to obey a tap.
  static const briefReveal = Duration(milliseconds: 300);

  /// The pause after the last card lands before the continue prompt appears.
  ///
  /// Deliberately long enough to read the final line first. A prompt that
  /// arrives with the text competes with it, and the last card is usually the
  /// one that says what to actually do.
  static const briefPromptDelay = Duration(milliseconds: 900);

  /// One full cycle of the continue prompt's blink.
  ///
  /// Slow. A fast blink is an alarm; this is an invitation, and it has to sit
  /// on screen for as long as someone takes to finish reading without becoming
  /// something they want to make stop.
  static const briefBlink = Duration(milliseconds: 1600);

  /// Advancing to the next brief card.
  ///
  /// Haptic only, and that is the point. This fires two to five times per
  /// lesson, every lesson; a click each time is the sound people turn off. The
  /// tap is confirmed in the hand, and the eye gets the reveal.
  List<SensoryCue> forBriefAdvance() => const [
    SensoryCue(at: Duration.zero, haptic: HapticCue.tap),
  ];

  /// The last card has landed and the exercise is ready to begin.
  ///
  /// The one audible moment in the sequence, because it marks a change of
  /// state rather than a step through one — reading is over, recording is next.
  List<SensoryCue> forBriefComplete() => const [
    SensoryCue(at: Duration.zero, haptic: HapticCue.tap, sound: SoundCue.tap),
  ];

  /// How long a lesson takes to rise into place, and to drop back out.
  ///
  /// Longer than a page push (280ms) because this is a modal gesture carrying
  /// the whole screen, and weight reads as time. Much beyond this and it starts
  /// to feel like waiting rather than arriving.
  static const lessonEnter = Duration(milliseconds: 340);

  /// How long the same screen takes to leave.
  ///
  /// Shorter than the entrance on purpose. Arriving is the app presenting
  /// something and can afford to be unhurried; leaving is the user's decision
  /// already made, and matching the entrance makes a dismissal feel reluctant.
  static const lessonExit = Duration(milliseconds: 260);

  /// How long the whole fan-out takes, first card to last settled.
  ///
  /// One gesture, not N animations. The figure is deliberately close to a page
  /// transition (280ms): the lessons are arriving from under the unit card, and
  /// anything much longer reads as the list being assembled in front of you.
  static const unitFanTotal = Duration(milliseconds: 360);

  /// Gap between one card starting and the next.
  ///
  /// Small on purpose. At 100ms a six-lesson unit reads as six separate cards
  /// queuing; at 45ms the eye follows a single edge travelling down the list,
  /// which is the thing being aimed at. See [unitFanStagger] for how this is
  /// compressed when a unit has many lessons.
  static const unitFanStep = Duration(milliseconds: 45);

  /// The stagger actually used for [count] cards.
  ///
  /// Capped so the last card always begins before the sequence is half over.
  /// Without this a nine-lesson unit would still be starting cards after the
  /// first ones had settled, and the gesture would come apart into a queue.
  static Duration unitFanStagger(int count) {
    if (count <= 1) return Duration.zero;
    // 0.35, not 0.5. At half the timeline a six-lesson unit put the last card's
    // start exactly on the first card's finish — zero overlap, which is the
    // definition of a queue rather than a wave. A third leaves every card
    // travelling while its neighbour is still moving.
    final evenly = unitFanTotal * 0.35 ~/ (count - 1);
    return evenly < unitFanStep ? evenly : unitFanStep;
  }

  /// Opening a unit to show its lessons.
  ///
  /// The same cue as any other press, because that is what it is — the unit
  /// card is a control and this is it responding. Kept as its own method rather
  /// than calling [forTap] at the screen, so the expand interaction has a named
  /// entry in the choreography like every other moment in the app, and its
  /// timing is a value a test can pin.
  List<SensoryCue> forUnitExpand() => const [
    SensoryCue(at: Duration.zero, haptic: HapticCue.tap, sound: SoundCue.tap),
  ];

  /// Closing it again.
  ///
  /// Haptic only. Closing is the undo of a thing the user just did, and it
  /// needs acknowledging rather than announcing; a second identical click on
  /// the way out is the kind of noise that makes people turn sound off.
  List<SensoryCue> forUnitCollapse() => const [
    SensoryCue(at: Duration.zero, haptic: HapticCue.tap),
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
