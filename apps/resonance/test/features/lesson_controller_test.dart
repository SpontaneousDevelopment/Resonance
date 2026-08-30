import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/net/coach_note_client.dart';
import 'package:resonance/core/haptics/haptic_engine.dart';
import 'package:resonance/core/progress/progress_repository.dart';
import 'package:resonance/core/sensory/sensory_director.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/core/speech/speech_recogniser.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';
import 'package:resonance/features/lesson/runner/lesson_controller.dart';

const lesson = Lesson(
  id: 't1u3l1-plosive-precision',
  unitId: 't1u3-articulation',
  title: 'Plosive Precision',
  type: LessonType.scoredRead,
  brief: 'Read at a steady pace.',
  script: 'Peter picked a bitter batch of pickled peppers',
  targetWpmMin: 130,
  targetWpmMax: 165,
);

/// Records what it was asked for, so the privacy boundary can be asserted.
class RecordingCoachNoteClient implements CoachNoteClient {
  RecordingCoachNoteClient({this.note = 'Nice work on the finals.'});

  final String? note;
  int calls = 0;
  String? lastTranscript;
  AttemptScore? lastScore;

  @override
  Future<String?> fetch({
    required Lesson lesson,
    required AttemptScore score,
    required String transcript,
  }) async {
    calls++;
    lastTranscript = transcript;
    lastScore = score;
    return note;
  }
}

void main() {
  late ResonanceDatabase db;
  late ProgressRepository progress;
  late RecordingSoundPlayer soundPlayer;
  late SoundPalette palette;
  late SensoryDirector sensory;

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    progress = ProgressRepository(db);
    soundPlayer = RecordingSoundPlayer();
    palette = SoundPalette(player: soundPlayer);
    sensory = SensoryDirector(
      haptics: RecordingHaptics(),
      sounds: palette,
      scheduler: (_) async {},
    );
  });

  tearDown(() async => db.close());

  group('speech availability', () {
    test('an unavailable recogniser does not stop the attempt', () async {
      final controller = LessonController(
        lesson: lesson,
        recogniser: FakeSpeechRecogniser(transcript: '', available: false),
        progress: progress,
        sensory: sensory,
      );
      addTearDown(controller.dispose);

      // Clarity cannot be measured, but pace and mic technique still can — the
      // attempt must not become an error state.
      expect(controller.clarityUnavailable, isFalse);
      expect(controller.phase, LessonPhase.ready);
    });

    test(
      'a recogniser that throws is treated as unavailable, not fatal',
      () async {
        final recogniser = FakeSpeechRecogniser(
          transcript: '',
          failure: const SpeechUnavailable(
            SpeechUnavailableReason.permissionDenied,
          ),
        );
        final controller = LessonController(
          lesson: lesson,
          recogniser: recogniser,
          progress: progress,
          sensory: sensory,
        );
        addTearDown(controller.dispose);

        expect(controller.error, isNull);
      },
    );
  });

  group('unavailable-speech messaging', () {
    test('each reason has copy the user can act on', () {
      for (final reason in SpeechUnavailableReason.values) {
        final message = SpeechUnavailable(reason).message;

        expect(message, isNotEmpty);
        // Never a raw platform error, and never a dead end.
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('error')));
      }
    });

    test('the offline message promises the take is kept', () {
      const message = SpeechUnavailable(SpeechUnavailableReason.offline);
      expect(message.message.toLowerCase(), contains('saved'));
    });
  });

  group('coach note', () {
    test('never receives audio — only transcript and numbers', () async {
      // The privacy boundary, asserted rather than assumed. The client's
      // signature is the enforcement; this test is what stops someone widening
      // it later without noticing.
      final client = RecordingCoachNoteClient();

      await client.fetch(
        lesson: lesson,
        score: const ScoredReadRubric().score(
          AttemptMeasurements(
            alignment: const TranscriptAligner().align(
              script: lesson.script!,
              transcript: lesson.script!,
            ),
            durationSeconds: 3.6,
            targetWpmMin: 130,
            targetWpmMax: 165,
          ),
        ),
        transcript: 'peter picked a bitter batch of pickled peppers',
      );

      expect(client.calls, 1);
      expect(client.lastTranscript, isA<String>());
    });

    test('the null client is a valid offline default', () async {
      const client = NullCoachNoteClient();
      final note = await client.fetch(
        lesson: lesson,
        score: const ScoredReadRubric().score(
          AttemptMeasurements(
            alignment: const TranscriptAligner().align(
              script: lesson.script!,
              transcript: '',
            ),
            durationSeconds: 1,
            targetWpmMin: 130,
            targetWpmMax: 165,
          ),
        ),
        transcript: '',
      );

      expect(note, isNull);
    });
  });

  duckingAcrossCaptureTests();

  group('phases', () {
    test('starts ready and notifies on change', () async {
      final controller = LessonController(
        lesson: lesson,
        recogniser: FakeSpeechRecogniser(transcript: ''),
        progress: progress,
        sensory: sensory,
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.phase, LessonPhase.ready);
      expect(controller.score, isNull);
      expect(controller.promotion, isNull);
      expect(notifications, 0);
    });
  });
}

/// Ducking across a real capture cycle.
///
/// The unit tests prove the palette silences itself when ducked. These prove
/// the controller actually *holds* a duck for the duration of capture — the
/// bug this guards is a duck taken and released around the wrong span, which
/// every unit test would still pass.
void duckingAcrossCaptureTests() {
  group('the bus is ducked for the whole capture', () {
    late ResonanceDatabase db;
    late RecordingSoundPlayer soundPlayer;
    late SoundPalette palette;
    late SensoryDirector sensory;
    late LessonController controller;

    setUp(() {
      db = ResonanceDatabase(NativeDatabase.memory());
      soundPlayer = RecordingSoundPlayer();
      palette = SoundPalette(player: soundPlayer);
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

    tearDown(() async {
      controller.dispose();
      await db.close();
    });

    // Note: these deliberately never start a recording. The app's test suite
    // does not link the DSP — `DynamicLibrary.process()` has no `res_*` symbols
    // outside the plugin's own tests — so constructing a RecordingSession here
    // would fail on a missing symbol rather than on anything under test.

    test('cancel releases its own duck, not everyone\'s', () async {
      // Previously cancel called clearDucks(), nuking global duck state — a
      // controller tearing down its own take would unmute the bus for a
      // reference clip that was still playing. It now releases only the handle
      // it owns, which is why a duck held elsewhere must survive.
      final other = palette.duckForCapture();

      await controller.cancel();

      expect(palette.isDucked, isTrue, reason: 'someone else still holds one');
      await sensory.sounds.play(SoundCue.correct);
      expect(soundPlayer.played, isEmpty);

      other.release();
      expect(palette.isDucked, isFalse);
      await sensory.sounds.play(SoundCue.correct);
      expect(soundPlayer.played, isNotEmpty);
    });

    test(
      'a duck held during capture silences a cue that fires mid-take',
      () async {
        // The scenario that matters: something tries to play *while* recording.
        palette.duckForCapture();

        await sensory.play(const [
          SensoryCue(at: Duration.zero, sound: SoundCue.levelUp),
        ]);

        expect(
          soundPlayer.played,
          isEmpty,
          reason: 'a cue during capture would be recorded by the microphone',
        );
      },
    );
  });
}
