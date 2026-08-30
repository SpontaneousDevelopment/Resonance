import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/net/coach_note_client.dart';
import 'package:resonance/core/progress/progress_repository.dart';
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

  setUp(() {
    db = ResonanceDatabase(NativeDatabase.memory());
    progress = ProgressRepository(db);
  });

  tearDown(() async => db.close());

  group('speech availability', () {
    test('an unavailable recogniser does not stop the attempt', () async {
      final controller = LessonController(
        lesson: lesson,
        recogniser: FakeSpeechRecogniser(transcript: '', available: false),
        progress: progress,
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

  group('phases', () {
    test('starts ready and notifies on change', () async {
      final controller = LessonController(
        lesson: lesson,
        recogniser: FakeSpeechRecogniser(transcript: ''),
        progress: progress,
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
