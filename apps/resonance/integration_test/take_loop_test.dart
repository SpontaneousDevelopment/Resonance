import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:resonance/core/audio/recording_session.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/speech/platform_speech_recogniser.dart';
import 'package:resonance/core/speech/speech_recogniser.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/features/lesson/lesson_screen.dart';
import 'package:resonance/features/lesson/runner/pre_exercise_cards.dart';
import 'package:resonance/ui/tokens/theme.dart';

import 'test_window.dart';

/// The assembled take loop, driven through the real screen.
///
/// The state machine, the gate and the aggregator each have their own tests.
/// This is the thing those tests cannot prove: that the screen actually wires
/// them together — that a failing take produces a Re-record button, that three
/// failures produce a Continue, and that finishing three takes commits one
/// attempt with three take rows and a composite from the worst of them.
///
/// Runs as an integration test because the lesson screen builds a recording
/// session, which needs a platform. The recogniser is injected, which is how a
/// failing take is reachable at all without a microphone and a bad read.
late final Curriculum seed;

/// A recogniser whose transcript can change between takes, so one run can pass,
/// then fail, then pass again.
class ScriptedRecogniser implements SpeechRecogniser {
  ScriptedRecogniser(this.transcripts);

  /// One entry per stop(), consumed in order. The last repeats.
  final List<String> transcripts;
  int _index = 0;

  String get _current => transcripts[_index.clamp(0, transcripts.length - 1)];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> start({String? localeId, String? contextHint}) async {}

  @override
  Future<Transcript> stop() async {
    final text = _current;
    _index++;
    return Transcript(text: text, meanConfidence: 0.9, isFinal: true);
  }

  @override
  Stream<Transcript> get results => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// A microphone that always works and always has something to say.
///
/// The real one cannot be used here: an app launched from a VS Code shell is
/// killed by TCC the moment it touches capture, which is the documented reason
/// microphone_test is excluded from CI. Faking the capture is what lets the
/// assembled loop — the thing most worth testing — actually run.
class ScriptedCapture implements AudioCapture {
  final List<StreamController<Uint8List>> _controllers = [];
  int _streams = 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    final controller = StreamController<Uint8List>();
    _controllers.add(controller);

    // The first stream is the room check, which measures a noise floor and
    // refuses to let recording start above -45 dBFS. A synthetic tone loud
    // enough to be a *take* reads as a loud room and disables the very button
    // this test needs, so the pre-roll is near-silent and the takes are not.
    final isRoomCheck = _streams == 0;
    _streams++;
    final amplitude = isRoomCheck ? 0 : 6000;

    scheduleMicrotask(() {
      // Six seconds at 48kHz, 16-bit mono. Long enough to clear the sanity
      // gate's 1.5s floor, and long enough that a sixteen-word script reads as
      // ~160 words a minute rather than pinning the plausible-pace ceiling.
      final bytes = Uint8List(48000 * 6 * 2);
      final view = ByteData.view(bytes.buffer);
      // A periodic waveform rather than noise, so the analyser reads the take
      // as voiced and it gets a real duration.
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        final t = (i ~/ 2) % 240;
        final value = (t < 120 ? amplitude : -amplitude);
        view.setInt16(i, value, Endian.little);
      }
      controller.add(bytes);
    });
    return controller.stream;
  }

  @override
  Future<String?> stop() async {
    await _controllers.last.close();
    return null;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    for (final c in _controllers) {
      if (!c.isClosed) await c.close();
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });
  setUpAll(keepTestWindowOnScreen);

  late ResonanceDatabase db;
  late ProviderContainer container;

  setUp(() => db = ResonanceDatabase(NativeDatabase.memory()));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Lesson lessonById(String id) =>
      seed.allUnits.expand((u) => u.lessons).firstWhere((l) => l.id == id);

  Future<void> open(
    WidgetTester tester,
    Lesson lesson,
    List<String> transcripts, {
    bool reduced = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1100, 2200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final recogniser = ScriptedRecogniser(transcripts);
    container = ProviderContainer(
      overrides: [
        curriculumProvider.overrideWith((ref) => seed),
        databaseProvider.overrideWith((ref) => db),
        speechRecogniserProvider.overrideWith(
          (ref) =>
              () => recogniser,
        ),
        recordingSessionProvider.overrideWith(
          (ref) =>
              () => RecordingSession(capture: ScriptedCapture()),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ResTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: LessonScreen(lesson: lesson),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Taps through one card sequence and stops.
  ///
  /// Keyed rather than "tap while any card is showing": the exercise brief and
  /// each take's intro are both PreExerciseCards, and an unkeyed loop taps
  /// straight through the take intro as well — which is how the first version
  /// of this test managed to be looking at the record screen while asserting
  /// the take had been introduced.
  Future<void> tapThrough(WidgetTester tester, Finder card) async {
    for (var i = 0; i < 14; i++) {
      if (card.evaluate().isEmpty) return;
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
    }
    fail('a card sequence never finished');
  }

  /// The lesson's own brief — the only card with no key.
  final briefCards = find.byWidgetPredicate(
    (w) => w is PreExerciseCards && w.key == null,
  );

  Finder takeIntro(int index) => find.byKey(ValueKey('take-intro-$index'));

  Future<void> settle(WidgetTester tester, [int ms = 1400]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
  }

  /// The room check, which has to happen before any record button exists.
  Future<void> checkRoom(WidgetTester tester) async {
    if (find.text('Check my room').evaluate().isNotEmpty) {
      await tester.tap(find.text('Check my room'));
      await settle(tester, 2500);
    }
  }

  /// One recording, ending in a judged take.
  Future<void> recordOnce(WidgetTester tester) async {
    await checkRoom(tester);
    final record = find.textContaining('Record Take');
    expect(record, findsOneWidget, reason: 'no record button on screen');
    await tester.tap(record);
    await settle(tester, 800);

    await tester.tap(find.text('Stop and score'));
    await settle(tester, 2500);
  }

  testWidgets('a three-take lesson runs start to finish', (tester) async {
    final ladder = lessonById('t1u3l4-tempo-ladder');
    expect(ladder.takes, hasLength(3));

    await open(tester, ladder, [
      ladder.script!,
      ladder.script!,
      ladder.script!,
    ]);

    // The exercise brief.
    await tapThrough(tester, briefCards);

    for (var take = 1; take <= 3; take++) {
      // Each take gets its own card before its recording.
      expect(
        takeIntro(take - 1),
        findsOneWidget,
        reason: 'take $take should be introduced before it is recorded',
      );
      await tapThrough(tester, takeIntro(take - 1));

      // The room check gates the record button, so it comes first.
      await checkRoom(tester);
      expect(
        find.textContaining('Record Take $take'),
        findsOneWidget,
        reason: 'the button should name which take it records',
      );
      await recordOnce(tester);
      // The celebration, then the loop moves on by itself.
      await settle(tester, 1600);
    }

    // One attempt, three take rows, committed together.
    final attempts = await db.select(db.attempts).get();
    expect(attempts, hasLength(1));
    final takes = await db.takesFor(attempts.single.id);
    expect(takes, hasLength(3));
    expect(takes.map((t) => t.label), ['Slow', 'Conversational', 'Fast']);
    expect(takes.every((t) => t.passedSanity), isTrue);

    // The composite is the worst take, not the last.
    final worst = takes.map((t) => t.score!).reduce((a, b) => a < b ? a : b);
    expect(
      attempts.single.score,
      worst,
      reason: 'the lesson should be graded on its weakest rung',
    );
  });

  testWidgets('a failed take offers a re-record and then recovers', (
    tester,
  ) async {
    final dial = lessonById('t1u3l5-over-articulation-dial');
    // Take one: silence. Then the real line twice.
    await open(tester, dial, ['', dial.script!, dial.script!]);

    await tapThrough(tester, briefCards);
    await tapThrough(tester, takeIntro(0));
    await recordOnce(tester);

    expect(
      find.text('Re-record'),
      findsOneWidget,
      reason: 'a take the gate refused should offer a re-record',
    );
    expect(
      find.textContaining('could not hear'),
      findsWidgets,
      reason: 'and say why, without implying the read was bad',
    );

    // Re-record, this time properly.
    await tester.tap(find.text('Re-record'));
    await settle(tester, 800);
    await tester.tap(find.text('Stop and score'));
    await settle(tester, 2500);

    expect(find.text('Re-record'), findsNothing);
    await settle(tester, 1600);

    // On to take two, with nothing banked from the refused attempt.
    expect(takeIntro(1), findsOneWidget);
  });

  testWidgets('three failures offer Continue, and it proceeds', (tester) async {
    final dial = lessonById('t1u3l5-over-articulation-dial');
    // Silence throughout: every take fails the gate.
    await open(tester, dial, ['']);

    await tapThrough(tester, briefCards);
    await tapThrough(tester, takeIntro(0));

    await recordOnce(tester);
    expect(find.text('Re-record'), findsOneWidget);

    for (var attempt = 2; attempt <= 3; attempt++) {
      await tester.tap(find.text(attempt == 3 ? 'Re-record' : 'Re-record'));
      await settle(tester, 800);
      await tester.tap(find.text('Stop and score'));
      await settle(tester, 2500);
    }

    expect(
      find.text('Continue'),
      findsOneWidget,
      reason: 'after three refusals the user must be offered a way past',
    );
    expect(
      find.text('Re-record'),
      findsNothing,
      reason: 'the third refusal replaces the retry rather than adding to it',
    );

    await tester.tap(find.text('Continue'));
    await settle(tester, 1600);

    // It proceeded with what was recorded, marked as not having passed.
    expect(takeIntro(1), findsOneWidget);
  });

  testWidgets('reduced motion reaches the same states without the travel', (
    tester,
  ) async {
    final dial = lessonById('t1u3l5-over-articulation-dial');
    await open(tester, dial, [dial.script!, dial.script!], reduced: true);

    await tapThrough(tester, briefCards);
    await tapThrough(tester, takeIntro(0));
    await checkRoom(tester);

    expect(find.textContaining('Record Take 1'), findsOneWidget);
    await recordOnce(tester);
    await settle(tester, 1600);

    expect(
      takeIntro(1),
      findsOneWidget,
      reason: 'the loop must advance identically without animation',
    );
  });
}
