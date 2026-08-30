import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/haptics/haptic_engine.dart';
import 'package:resonance/core/sensory/sensory_director.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';

/// A clock the test advances instead of waiting.
///
/// Every recorded cue is stamped with it, so assertions are about *when*
/// something fired rather than only that it did. Asserting a haptic occurred
/// would pass on a schedule that fired everything simultaneously, which is
/// precisely the failure the choreography exists to prevent.
class VirtualClock {
  Duration now = Duration.zero;
}

class TimestampedHaptics implements HapticEngine {
  TimestampedHaptics(this.clock, {this.isSupported = true});

  final VirtualClock clock;

  @override
  final bool isSupported;

  final List<(Duration, HapticCue)> played = [];

  @override
  Future<void> play(HapticCue cue) async => played.add((clock.now, cue));

  Duration? whenPlayed(HapticCue cue) {
    for (final entry in played) {
      if (entry.$2 == cue) return entry.$1;
    }
    return null;
  }
}

class TimestampedPlayer implements SoundPlayer {
  TimestampedPlayer(this.clock);

  final VirtualClock clock;
  final List<(Duration, String)> played = [];

  @override
  Future<void> play(String assetPath) async =>
      played.add((clock.now, assetPath));

  @override
  Future<void> dispose() async {}

  Duration? whenPlayed(SoundCue cue) {
    final path = SoundPalette.assets[cue];
    for (final entry in played) {
      if (entry.$2 == path) return entry.$1;
    }
    return null;
  }
}

({
  SensoryDirector director,
  TimestampedHaptics haptics,
  TimestampedPlayer player,
  SoundPalette palette,
  VirtualClock clock,
})
build({bool hapticsSupported = true}) {
  final clock = VirtualClock();
  final haptics = TimestampedHaptics(clock, isSupported: hapticsSupported);
  final player = TimestampedPlayer(clock);
  final palette = SoundPalette(player: player);
  final director = SensoryDirector(
    haptics: haptics,
    sounds: palette,
    scheduler: (delay) async => clock.now += delay,
  );
  return (
    director: director,
    haptics: haptics,
    player: player,
    palette: palette,
    clock: clock,
  );
}

const cues = [
  SensoryCue(
    at: Duration.zero,
    haptic: HapticCue.correct,
    sound: SoundCue.correct,
  ),
  SensoryCue(at: Duration(milliseconds: 640), sound: SoundCue.levelUp),
  SensoryCue(at: Duration(milliseconds: 680), haptic: HapticCue.levelUp),
];

void main() {
  group('timing', () {
    test('each cue fires at its scheduled offset, not all at once', () async {
      final t = build();
      await t.director.play(cues);

      expect(t.player.whenPlayed(SoundCue.correct), Duration.zero);
      expect(
        t.player.whenPlayed(SoundCue.levelUp),
        const Duration(milliseconds: 640),
      );
      expect(
        t.haptics.whenPlayed(HapticCue.levelUp),
        const Duration(milliseconds: 680),
      );
    });

    test('the level-up haptic lands after its sound', () async {
      final t = build();
      await t.director.play(cues);

      final sound = t.player.whenPlayed(SoundCue.levelUp)!;
      final haptic = t.haptics.whenPlayed(HapticCue.levelUp)!;
      expect(haptic - sound, const Duration(milliseconds: 40));
    });

    test('waits are relative, so total elapsed matches the last cue', () async {
      // A director that waited `cue.at` each time rather than the difference
      // would take 1320 ms to play a 680 ms sequence.
      final t = build();
      await t.director.play(cues);

      expect(t.clock.now, const Duration(milliseconds: 680));
    });
  });

  group('reduced motion', () {
    test('reaches the same end state with no waiting', () async {
      // Reduced motion removes pacing, not feedback. Every cue still fires, in
      // the same order — a user who cannot see the ring fill is still told they
      // levelled up.
      final paced = build();
      await paced.director.play(cues);

      final instant = build();
      instant.director.reduceMotion = true;
      await instant.director.play(cues);

      expect(
        instant.player.played.map((e) => e.$2).toList(),
        paced.player.played.map((e) => e.$2).toList(),
      );
      expect(
        instant.haptics.played.map((e) => e.$2).toList(),
        paced.haptics.played.map((e) => e.$2).toList(),
      );

      expect(instant.clock.now, Duration.zero);
      expect(paced.clock.now, const Duration(milliseconds: 680));
    });
  });

  group('ducking during capture', () {
    test('a ducked bus plays nothing at all', () async {
      // The assertion that matters: nothing reaches the player. Checking a duck
      // flag would pass even while a chime was being recorded by the mic.
      final t = build();
      t.palette.duckForCapture();

      await t.director.play(cues);

      expect(t.player.played, isEmpty);
      expect(t.palette.isDucked, isTrue);
      expect(t.palette.isAudible, isFalse);
    });

    test('haptics still fire while ducked', () async {
      // Ducking exists because the microphone hears sound. It does not hear
      // haptics, and silencing them would lose the recording-stop confirmation
      // the user relies on while looking at a script.
      final t = build();
      t.palette.duckForCapture();

      await t.director.play(cues);

      expect(t.haptics.played, isNotEmpty);
    });

    test('sound returns after the duck is released', () async {
      final t = build();
      t.palette.duckForCapture();
      await t.director.play(cues);
      expect(t.player.played, isEmpty);

      t.palette.unduck();
      await t.director.play(cues);
      expect(t.player.played, isNotEmpty);
    });

    test('overlapping ducks do not unmute early', () async {
      // The recorder and reference playback both duck, and they overlap during
      // a shadow read. A boolean would let the first to finish unmute the bus
      // while the other was still capturing.
      final t = build();
      t.palette.duckForCapture();
      t.palette.duckForCapture();

      t.palette.unduck();
      expect(t.palette.isDucked, isTrue, reason: 'one duck still held');
      await t.director.play(cues);
      expect(t.player.played, isEmpty);

      t.palette.unduck();
      expect(t.palette.isDucked, isFalse);
      await t.director.play(cues);
      expect(t.player.played, isNotEmpty);
    });

    test('an unbalanced unduck cannot drive the count negative', () async {
      // Otherwise a stray unduck banks credit and the next real duck fails to
      // silence anything.
      final t = build();
      t.palette.unduck();
      t.palette.unduck();

      t.palette.duckForCapture();
      await t.director.play(cues);
      expect(t.player.played, isEmpty);
    });

    test('clearDucks releases everything', () async {
      final t = build();
      t.palette.duckForCapture();
      t.palette.duckForCapture();
      t.palette.clearDucks();

      await t.director.play(cues);
      expect(t.player.played, isNotEmpty);
    });
  });

  group('the sound setting', () {
    test('disabled means nothing plays, ducked or not', () async {
      final t = build();
      t.palette.enabled = false;

      await t.director.play(cues);
      expect(t.player.played, isEmpty);
      expect(t.haptics.played, isNotEmpty, reason: 'haptics are separate');
    });
  });

  group('platforms without haptics', () {
    test('macOS plays sound and nothing else, with no substitute', () async {
      // The accepted tradeoff: macOS feedback is flatter. Nothing stands in for
      // the missing layer, and the schedule is not forked to compensate.
      final t = build(hapticsSupported: false);
      await t.director.play(cues);

      expect(t.haptics.played, isEmpty);
      expect(t.player.played, isNotEmpty);
    });

    test('the schedule is identical whether or not haptics exist', () async {
      final withHaptics = build();
      final without = build(hapticsSupported: false);

      await withHaptics.director.play(cues);
      await without.director.play(cues);

      // Same sounds, same timings — one choreography, played by whatever the
      // platform has.
      expect(without.player.played, withHaptics.player.played);
      expect(without.clock.now, withHaptics.clock.now);
    });

    test('NoHaptics reports itself unsupported and does nothing', () async {
      const engine = NoHaptics();
      expect(engine.isSupported, isFalse);
      await expectLater(engine.play(HapticCue.levelUp), completes);
    });
  });

  group('the tap cue', () {
    test('is audible outside a take', () async {
      final t = build();
      await t.director.tap();

      expect(t.player.played.map((e) => e.$2), [
        SoundPalette.assets[SoundCue.tap],
      ]);
      expect(t.haptics.played.map((e) => e.$2), [HapticCue.tap]);
    });

    test('is silent during a take, but still felt', () async {
      // A tap can happen mid-recording — Stop is on screen. The microphone is
      // open, so the sound must not play; the haptic is not heard by a
      // microphone and stays, which is the same rule the other cues follow.
      final t = build();
      t.palette.duckForCapture();

      await t.director.tap();

      expect(t.player.played, isEmpty);
      expect(t.haptics.played.map((e) => e.$2), [HapticCue.tap]);
    });

    test('returns after the take ends', () async {
      final t = build();
      final duck = t.palette.duckForCapture();
      await t.director.tap();
      expect(t.player.played, isEmpty);

      duck.release();
      await t.director.tap();
      expect(t.player.played, isNotEmpty);
    });

    test('fires immediately — a delayed tap reads as lag', () async {
      final t = build();
      await t.director.tap();

      expect(t.clock.now, Duration.zero);
    });
  });

  group('overlapping sequences', () {
    test('an empty schedule is a no-op', () async {
      final t = build();
      await t.director.play(const []);

      expect(t.player.played, isEmpty);
      expect(t.haptics.played, isEmpty);
      expect(t.clock.now, Duration.zero);
    });
  });
}
