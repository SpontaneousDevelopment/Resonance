import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';
import 'package:resonance/features/lesson/feedback/feedback_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

const script = 'Peter picked a bitter batch of pickled peppers';
const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

AttemptScore scoreFor(String transcript, {double seconds = 3.6}) {
  return rubric.score(
    AttemptMeasurements(
      alignment: aligner.align(script: script, transcript: transcript),
      durationSeconds: seconds,
      targetWpmMin: 130,
      targetWpmMax: 165,
      totalFrames: 100,
    ),
  );
}

Future<void> pump(
  WidgetTester tester, {
  required AttemptScore score,
  required PromotionResult promotion,
  String? coachNote,
  bool pending = false,
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
        score: score,
        promotion: promotion,
        coachNote: coachNote,
        coachNotePending: pending,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('shows the composite score', (tester) async {
    final score = scoreFor(script);
    await pump(
      tester,
      score: score,
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
    );

    // A clean read scores 100 on the composite *and* every component, so the
    // finder has to target the headline by its type scale rather than by text.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == '${score.composite}' &&
            w.style?.fontSize == 40,
      ),
      findsOneWidget,
    );
  });

  testWidgets('celebrates a promotion', (tester) async {
    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.bronze,
        after: MasteryLevel.silver,
      ),
    );

    expect(find.textContaining('Levelled up to Silver'), findsOneWidget);
  });

  testWidgets('explains the once-per-day block as protection, not denial', (
    tester,
  ) async {
    // The wording here is the whole point: a user who just did well and was
    // not promoted needs to understand why, or the rule feels like a bug.
    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.silver,
        after: MasteryLevel.silver,
        block: PromotionBlock.alreadyPromotedToday,
      ),
    );

    expect(
      find.textContaining('already levelled this up today'),
      findsOneWidget,
    );
    expect(find.textContaining('tomorrow'), findsOneWidget);
  });

  testWidgets('names the next level when the score fell short', (tester) async {
    await pump(
      tester,
      score: scoreFor('peter picked'),
      promotion: const PromotionResult(
        before: MasteryLevel.bronze,
        after: MasteryLevel.bronze,
        block: PromotionBlock.scoreTooLow,
      ),
    );

    expect(find.textContaining('Silver'), findsOneWidget);
  });

  testWidgets('renders every weighted component with a detail line', (
    tester,
  ) async {
    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
    );

    expect(find.text('Clarity'), findsOneWidget);
    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('Plosive control'), findsOneWidget);
    expect(find.text('Every word landed.'), findsOneWidget);
  });

  testWidgets('shows a pending state for the coach note, then the note', (
    tester,
  ) async {
    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
      pending: true,
    );
    expect(find.text('Listening back…'), findsOneWidget);

    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
      coachNote: 'You rushed the turn on "packed". Hold that beat a moment.',
    );
    expect(find.textContaining('rushed the turn'), findsOneWidget);
  });

  testWidgets('the screen is complete without a coach note', (tester) async {
    // Its absence must never block the score — that is the whole reason the
    // qualitative pass is separate from the numeric one.
    await pump(
      tester,
      score: scoreFor(script),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
    );

    expect(find.text('Listening back…'), findsNothing);
    expect(find.text('Clarity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the script back to the user', (tester) async {
    await pump(
      tester,
      score: scoreFor('peter picked a bitter bat of pickled peppers'),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.bronze,
      ),
    );

    expect(find.byType(RichText), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a zero-length attempt', (tester) async {
    await pump(
      tester,
      score: scoreFor('', seconds: 0),
      promotion: const PromotionResult(
        before: MasteryLevel.locked,
        after: MasteryLevel.locked,
        block: PromotionBlock.scoreTooLow,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
