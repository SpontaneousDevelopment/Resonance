import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/haptics/haptic_engine.dart';
import 'package:resonance/core/progress/progress_repository.dart';
import 'package:resonance/core/sensory/sensory_director.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/core/speech/speech_recogniser.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/features/lesson/runner/lesson_controller.dart';

// ignore: dart_io_import_in_test — needed for the mocked temp directory.
import 'dart:io';

/// Duck accounting must balance on **every** exit from a capture, not just the
/// happy one. A leaked duck is permanent for the life of the app — the palette
/// is a long-lived provider — and presents as "the sounds stopped working"
/// long after the take that caused it.
const lesson = Lesson(
  id: 't1u3l1-plosive-precision',
  unitId: 't1u3-articulation',
  title: 'Plosive Precision',
  type: LessonType.scoredRead,
  brief: 'Read steadily.',
  script: 'Peter picked a bitter batch of pickled peppers',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Without this `startRecording` throws at the directory lookup — *before* it
  // ducks — and every test below would pass without exercising the leak it
  // names. With it, the controller reaches the duck and then fails opening the
  // recorder, which is the real shape of a permission or device failure.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  late ResonanceDatabase db;
  late RecordingSoundPlayer player;
  late SoundPalette palette;
  late SensoryDirector sensory;
  late LessonController controller;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    player = RecordingSoundPlayer();
    palette = SoundPalette(player: player);
    sensory = SensoryDirector(
      haptics: RecordingHaptics(),
      sounds: palette,
      scheduler: (_) async {},
    );
    controller = LessonController(
      lesson: lesson,
      recogniser: FakeSpeechRecogniser(transcript: ''),
      progress: ProgressRepository(db),
      sensory: sensory,
    );
  });

  tearDown(() async => db.close());

  /// Proves the bus is genuinely open by playing through it.
  Future<bool> soundReachesPlayer() async {
    player.played.clear();
    await palette.play(SoundCue.correct);
    return player.played.isNotEmpty;
  }

  group('a capture that fails to start', () {
    test('releases its duck', () async {
      // startRecording ducks, then opens the recorder. In this environment that
      // throws — no platform, no DSP — which is exactly the shape of a real
      // failure: permission revoked, device busy, another app holding the mic.
      // The duck must not survive it.
      await expectLater(controller.startRecording(), throwsA(anything));

      expect(
        palette.isDucked,
        isFalse,
        reason: 'duck leaked on a failed start',
      );
      expect(await soundReachesPlayer(), isTrue);
    });

    test('two failed starts do not stack ducks', () async {
      await expectLater(controller.startRecording(), throwsA(anything));
      await expectLater(controller.startRecording(), throwsA(anything));

      expect(palette.isDucked, isFalse);
      expect(await soundReachesPlayer(), isTrue);
    });
  });

  group('teardown after a failed capture', () {
    // Each of these first drives a capture that ducks and then fails, so the
    // controller is genuinely the owner of the duck being released.
    Future<void> failedStart() =>
        expectLater(controller.startRecording(), throwsA(anything));

    test('dispose leaves nothing outstanding', () async {
      await failedStart();
      controller.dispose();

      expect(palette.isDucked, isFalse);
      expect(await soundReachesPlayer(), isTrue);
    });

    test('cancel leaves nothing outstanding', () async {
      await failedStart();
      await controller.cancel();

      expect(palette.isDucked, isFalse);
      expect(await soundReachesPlayer(), isTrue);
    });

    test('reset leaves nothing outstanding', () async {
      // "Again" can be pressed from a take that never reached stopAndScore.
      await failedStart();
      controller.reset();

      expect(palette.isDucked, isFalse);
      expect(await soundReachesPlayer(), isTrue);
    });

    test('releasing twice cannot open the bus for someone else', () async {
      // A double release that decremented twice would unmute a duck another
      // holder still needs — worse than leaking one.
      final other = palette.duckForCapture();
      await failedStart();
      // The failed start already released; dispose releases again. A second
      // decrement would steal the duck the other holder is relying on.
      controller.dispose();

      expect(
        palette.isDucked,
        isTrue,
        reason: 'the other holder still needs it',
      );
      other.release();
      expect(palette.isDucked, isFalse);
    });
  });

  group('recording boundary cues are actually audible', () {
    test('recordStart is not swallowed by the duck it precedes', () async {
      // The cue announcing that recording began was played *after* ducking, so
      // it could never be heard. Ducking exists to keep sound out of the
      // microphone; the start cue fires before capture opens.
      await expectLater(controller.startRecording(), throwsA(anything));

      expect(
        player.played,
        contains(SoundPalette.assets[SoundCue.recordStart]),
        reason: 'the start cue must play before the bus is ducked',
      );
    });
  });

  group('the existing guarantee still holds', () {
    test('an active duck still silences everything', () async {
      // The property the whole mechanism exists for. Fixing the leak must not
      // weaken this.
      palette.duckForCapture();

      await sensory.play(const [
        SensoryCue(at: Duration.zero, sound: SoundCue.levelUp),
        SensoryCue(at: Duration.zero, sound: SoundCue.correct),
      ]);

      expect(player.played, isEmpty);
    });
  });
}
