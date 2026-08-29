import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';
import 'package:resonance/features/lesson/feedback/feedback_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// The gap these cover: every screen worked on its own, but nothing asserted
/// that stopping a recording actually *reaches* the feedback screen. Unit tests
/// on each piece cannot catch a route that was never wired.
const script = 'Peter picked a bitter batch of pickled peppers';
const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

AttemptScore scoreFor(String transcript, {double seconds = 3.6}) =>
    rubric.score(
      AttemptMeasurements(
        alignment: aligner.align(script: script, transcript: transcript),
        durationSeconds: seconds,
        targetWpmMin: 130,
        targetWpmMax: 165,
        totalFrames: 100,
      ),
    );

Future<void> pumpFeedback(
  WidgetTester tester, {
  required bool clarityUnavailable,
  VoidCallback? onRetry,
  VoidCallback? onContinue,
}) async {
  tester.view
    ..physicalSize = const Size(900, 1800)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ResTheme.light(),
      home: FeedbackScreen(
        lessonTitle: 'Plosive Precision',
        script: script,
        score: scoreFor(script),
        promotion: const PromotionResult(
          before: MasteryLevel.locked,
          after: MasteryLevel.bronze,
        ),
        clarityUnavailable: clarityUnavailable,
        onRetry: onRetry,
        onContinue: onContinue,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('feedback actions', () {
    testWidgets('Again is wired', (tester) async {
      var retried = 0;
      await pumpFeedback(
        tester,
        clarityUnavailable: false,
        onRetry: () => retried++,
      );

      await tester.tap(find.text('Again'));
      await tester.pump();

      expect(retried, 1);
    });

    testWidgets('Continue is wired', (tester) async {
      var continued = 0;
      await pumpFeedback(
        tester,
        clarityUnavailable: false,
        onContinue: () => continued++,
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(continued, 1);
    });
  });

  group('clarity unavailable', () {
    testWidgets('says the score covers less than usual', (tester) async {
      // Silently showing a normal-looking score computed without a transcript
      // would teach the user to distrust the number once they noticed.
      await pumpFeedback(tester, clarityUnavailable: true);

      expect(find.textContaining('could not hear your words'), findsOneWidget);
      expect(
        find.textContaining('pace and mic technique only'),
        findsOneWidget,
      );
    });

    testWidgets('stays quiet when clarity was measured', (tester) async {
      await pumpFeedback(tester, clarityUnavailable: false);
      expect(find.textContaining('could not hear your words'), findsNothing);
    });
  });

  group('route resolution', () {
    // The full tree-tap-to-lesson path is deliberately NOT a widget test.
    // Building LessonScreen constructs the speech recogniser, which blocks
    // forever under `flutter test` with no platform behind it. That path is
    // covered by the integration test instead — which is also the only place
    // the microphone and recogniser are meaningfully exercised.
    //
    // What IS testable here is the logic that was actually broken: resolving a
    // lesson id against the bundled curriculum.
    late Curriculum seed;

    setUpAll(() async {
      seed = await const CurriculumRepository().load();
    });

    test('the first lesson of the authored unit resolves by id', () {
      final unit = seed.unitById('t1u3-articulation');
      expect(unit, isNotNull);

      final first = unit!.lessons.first;
      expect(seed.lessonById(first.id), isNotNull);
      expect(seed.lessonById(first.id)!.title, 'Plosive Precision');
    });

    test('every authored lesson is reachable by the path the tree builds', () {
      for (final lesson in seed.allLessons) {
        expect(Routes.lessonPath(lesson.id), '/lesson/${lesson.id}');
        expect(
          seed.lessonById(lesson.id),
          isNotNull,
          reason: '${lesson.id} is in the tree but would not resolve',
        );
      }
    });

    test('an unknown id resolves to null rather than throwing', () {
      expect(seed.lessonById('t9u9l9-does-not-exist'), isNull);
    });

    test('every lesson the tree can open has a script to show', () {
      // The tree opens `unit.lessons.first`. If that lesson had no script the
      // record screen would render an empty page.
      for (final unit in seed.allUnits.where((u) => u.isAuthored)) {
        final first = unit.lessons.first;
        expect(
          first.script,
          isNotNull,
          reason: '${unit.id} opens ${first.id}, which has no script',
        );
        expect(first.script, isNotEmpty);
      }
    });
  });
}
