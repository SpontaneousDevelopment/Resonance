import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/progress/streak.dart';
import 'package:resonance/domain/progress/vocal_energy.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/ui/tokens/motion.dart';

const choreo = FeedbackChoreography();

const promoted = PromotionResult(
  before: MasteryLevel.bronze,
  after: MasteryLevel.silver,
);
const notPromoted = PromotionResult(
  before: MasteryLevel.bronze,
  after: MasteryLevel.bronze,
  block: PromotionBlock.scoreTooLow,
);

List<SensoryCue> attempt({
  int score = 80,
  PromotionResult promotion = notPromoted,
  EnergyEvent energy = EnergyEvent.unchanged,
  StreakEvent streak = StreakEvent.extended,
  bool unlocked = false,
}) => choreo.forAttempt(
  score: score,
  promotion: promotion,
  energyEvent: energy,
  streakEvent: streak,
  unlockedUnit: unlocked,
);

Duration whenHaptic(List<SensoryCue> cues, HapticCue cue) =>
    cues.firstWhere((c) => c.haptic == cue).at;

Duration whenSound(List<SensoryCue> cues, SoundCue cue) =>
    cues.firstWhere((c) => c.sound == cue).at;

void main() {
  group('the verdict lands immediately', () {
    test('a passing attempt cues correct at zero', () {
      final cues = attempt(score: 80);
      expect(cues.first.at, Duration.zero);
      expect(cues.first.haptic, HapticCue.correct);
      expect(cues.first.sound, SoundCue.correct);
    });

    test('a low score cues mistake at zero', () {
      final cues = attempt(score: 30);
      expect(cues.first.haptic, HapticCue.mistake);
      expect(cues.first.sound, SoundCue.mistake);
    });

    test('the pass boundary is the Bronze threshold', () {
      // An attempt good enough to promote must never sound like a failure.
      expect(
        attempt(score: VocalEnergy.lowScoreThreshold).first.sound,
        SoundCue.correct,
      );
      expect(
        attempt(score: VocalEnergy.lowScoreThreshold - 1).first.sound,
        SoundCue.mistake,
      );
    });
  });

  group('a promotion resolves as the ring completes', () {
    test('level-up sound lands exactly at the end of the ring fill', () {
      // The whole point of the timing: the celebration is the resolution of the
      // animation, not something happening over the top of it.
      final cues = attempt(promotion: promoted);
      expect(whenSound(cues, SoundCue.levelUp), FeedbackChoreography.ringFill);
    });

    test('the haptic follows its sound, it does not coincide with it', () {
      final cues = attempt(promotion: promoted);
      final sound = whenSound(cues, SoundCue.levelUp);
      final haptic = whenHaptic(cues, HapticCue.levelUp);

      expect(haptic, greaterThan(sound));
      expect(haptic - sound, FeedbackChoreography.hapticLag);
    });

    test('the ring duration matches the animation token', () {
      // These are defined separately — the choreography stays free of Flutter —
      // so a divergence would silently put the celebration mid-animation.
      expect(FeedbackChoreography.ringFill, ResMotion.celebrate);
    });

    test('no promotion means no level-up cue at all', () {
      final cues = attempt(promotion: notPromoted);
      expect(cues.any((c) => c.sound == SoundCue.levelUp), isFalse);
      expect(cues.any((c) => c.haptic == HapticCue.levelUp), isFalse);
    });
  });

  group('a unit unlock gets its own beat', () {
    test('it never collides with the level-up it follows', () {
      final cues = attempt(promotion: promoted, unlocked: true);
      final levelUp = whenHaptic(cues, HapticCue.levelUp);
      final unlock = whenSound(cues, SoundCue.masteryUnlock);

      expect(unlock, greaterThan(levelUp));
      expect(unlock - levelUp, FeedbackChoreography.unlockBeat);
    });

    test('without a promotion it takes the ring slot', () {
      final cues = attempt(promotion: notPromoted, unlocked: true);
      expect(
        whenSound(cues, SoundCue.masteryUnlock),
        FeedbackChoreography.ringFill,
      );
    });
  });

  group('a saved streak comes last', () {
    test('after the score has been read, not competing with it', () {
      final cues = attempt(
        promotion: promoted,
        streak: StreakEvent.savedByFreeze,
      );
      final save = whenSound(cues, SoundCue.streakSave);

      expect(save, greaterThan(whenHaptic(cues, HapticCue.levelUp)));
    });

    test('an ordinary extended streak is silent', () {
      // Every session extends the streak. A cue for it would fire constantly
      // and mean nothing.
      final cues = attempt(streak: StreakEvent.extended);
      expect(cues.any((c) => c.sound == SoundCue.streakSave), isFalse);
    });
  });

  group('running out of energy is silent', () {
    test('depletion adds no cue', () {
      // The rest offer is an invitation. Announcing it would make it read as a
      // penalty, which is the one interpretation the mechanic exists to avoid.
      final quiet = attempt(energy: EnergyEvent.unchanged);
      final depleted = attempt(energy: EnergyEvent.depleted);

      expect(depleted.length, quiet.length);
      expect(depleted, quiet);
    });
  });

  group('ordering', () {
    test('cues are always in non-decreasing time order', () {
      // The director plays them in list order and waits on the difference; an
      // out-of-order schedule would produce a negative wait and fire instantly.
      for (final cues in [
        attempt(),
        attempt(promotion: promoted),
        attempt(promotion: promoted, unlocked: true),
        attempt(
          score: 20,
          promotion: promoted,
          unlocked: true,
          streak: StreakEvent.savedByFreeze,
        ),
      ]) {
        for (var i = 1; i < cues.length; i++) {
          expect(
            cues[i].at,
            greaterThanOrEqualTo(cues[i - 1].at),
            reason: 'out of order at $i in $cues',
          );
        }
      }
    });
  });

  group('recording boundaries', () {
    test('start and stop are immediate and distinct', () {
      expect(choreo.forRecordingStart().single.at, Duration.zero);
      expect(choreo.forRecordingStop().single.at, Duration.zero);
      expect(
        choreo.forRecordingStart().single.haptic,
        isNot(choreo.forRecordingStop().single.haptic),
      );
    });
  });
}
