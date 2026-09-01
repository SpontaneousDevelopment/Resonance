import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/progress/progress_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/curriculum/lesson_unlock.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/scoring/rubric.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';
import 'package:resonance/features/skill_tree/lesson_node.dart';
import 'package:resonance/features/skill_tree/skill_tree_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// The unit-detail interaction, driven the way a user drives it.
///
/// Runs against the **real compiled seed** and a **real database**. The attempt
/// in the middle of this is a real one: it goes through [ProgressRepository]
/// into Drift and comes back out through the mastery stream the tree already
/// watches. A test that stubbed the mastery map would prove the cards render
/// from a map, which is not the thing that was in doubt — what was in doubt is
/// whether finishing a lesson opens the next one.
late final Curriculum seed;

const aligner = TranscriptAligner();
const rubric = ScoredReadRubric();

/// A passing score, produced by the real rubric rather than hand-set, so this
/// cannot pass on a composite the app could never actually produce.
AttemptScore passingScoreFor(Lesson lesson) => rubric.score(
  AttemptMeasurements(
    alignment: aligner.align(
      script: lesson.script!,
      transcript: lesson.script!,
    ),
    durationSeconds: (lesson.script!.split(' ').length / 145) * 60,
    targetWpmMin: lesson.targetWpmMin ?? 130,
    targetWpmMax: lesson.targetWpmMax ?? 165,
    totalFrames: 100,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ResonanceDatabase db;
  late ProviderContainer container;

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });

  setUp(() => db = ResonanceDatabase(NativeDatabase.memory()));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Unit unitTitled(String title) =>
      seed.allUnits.firstWhere((u) => u.title == title);

  Unit articulation() => unitTitled('Articulation & Diction');

  Future<void> pumpTree(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 2600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        curriculumProvider.overrideWith((ref) => seed),
        databaseProvider.overrideWith((ref) => db),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ResTheme.light(),
          home: const SkillTreeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapUnit(
    WidgetTester tester, [
    String title = 'Articulation & Diction',
  ]) async {
    await tester.tap(find.text(title));
    await tester.pump();
    // Past the expand animation.
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Records a genuine attempt through the repository, then lets the mastery
  /// stream push it back into the tree.
  Future<void> completeLesson(WidgetTester tester, Lesson lesson) async {
    await container
        .read(progressRepositoryProvider)
        .recordAttempt(
          lesson: lesson,
          score: passingScoreFor(lesson),
          attemptId: '${lesson.id}-test',
          durationMs: 4000,
          now: DateTime(2026, 9, 2, 10),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a unit expands in place rather than opening a lesson', (
    tester,
  ) async {
    await pumpTree(tester);

    expect(
      find.byType(LessonNode),
      findsNothing,
      reason: 'lessons should not be listed until the unit is opened',
    );

    await tapUnit(tester);

    expect(
      find.byType(LessonNode),
      findsNWidgets(articulation().lessons.length),
      reason: 'every lesson in the unit should be listed',
    );
    // The tree is still on screen: this expanded, it did not navigate.
    expect(find.text('Foundations Check'), findsOneWidget);
    expect(find.text('Plosive Precision'), findsOneWidget);
  });

  testWidgets('tapping the unit again collapses it', (tester) async {
    await pumpTree(tester);
    await tapUnit(tester);
    expect(find.byType(LessonNode), findsWidgets);

    await tapUnit(tester);
    expect(find.byType(LessonNode), findsNothing);
  });

  testWidgets('only lesson 1 is enterable, and 2-6 are not', (tester) async {
    await pumpTree(tester);
    await tapUnit(tester);

    final nodes = tester
        .widgetList<LessonNode>(find.byType(LessonNode))
        .toList();
    expect(nodes, hasLength(6));

    expect(nodes.first.unlock.isOpen, isTrue);
    expect(nodes.first.onTap, isNotNull);

    for (final node in nodes.skip(1)) {
      expect(
        node.unlock.isOpen,
        isFalse,
        reason: '${node.lesson.title} should not be reachable yet',
      );
    }
  });

  testWidgets('completing lesson 1 opens lesson 2 and nothing further', (
    tester,
  ) async {
    await pumpTree(tester);
    await tapUnit(tester);

    expect(
      tester
          .widgetList<LessonNode>(find.byType(LessonNode))
          .elementAt(1)
          .unlock
          .isOpen,
      isFalse,
      reason: 'lesson 2 must start closed, or this test proves nothing',
    );

    await completeLesson(tester, articulation().lessons.first);

    final after = tester
        .widgetList<LessonNode>(find.byType(LessonNode))
        .toList();
    expect(
      after[1].unlock.isOpen,
      isTrue,
      reason: 'a passed attempt on lesson 1 should open lesson 2',
    );
    expect(
      after[2].unlock.isOpen,
      isFalse,
      reason: 'one attempt must not open the whole unit',
    );
  });

  testWidgets('lessons 1 to 5 open one after another, each by being passed', (
    tester,
  ) async {
    await pumpTree(tester);
    await tapUnit(tester);

    for (var i = 0; i < 5; i++) {
      final nodes = tester
          .widgetList<LessonNode>(find.byType(LessonNode))
          .toList();
      expect(
        nodes[i].unlock.isOpen,
        isTrue,
        reason: 'lesson ${i + 1} should be reachable by now',
      );
      expect(
        nodes[i].onTap,
        isNotNull,
        reason: 'lesson ${i + 1} is open but has no way in',
      );
      await completeLesson(tester, articulation().lessons[i]);
    }

    // All five scored reads are done and each was entered in turn.
    final finished = tester
        .widgetList<LessonNode>(find.byType(LessonNode))
        .toList();
    for (var i = 0; i < 5; i++) {
      expect(finished[i].mastery.everAttempted, isTrue);
      expect(finished[i].unlock.isOpen, isTrue);
    }
  });

  testWidgets('every lesson the sequence opens is actually playable', (
    tester,
  ) async {
    // Reachable and completable are different claims. A lesson the tree opens
    // onto a screen with no script is a dead end of exactly the kind this
    // project has shipped before, so the content is asserted too.
    await pumpTree(tester);
    await tapUnit(tester);

    for (var i = 0; i < 5; i++) {
      final lesson = articulation().lessons[i];
      expect(
        lesson.type,
        LessonType.scoredRead,
        reason: '${lesson.title} cannot be completed by recording a take',
      );
      expect(
        lesson.script,
        isNotNull,
        reason: '${lesson.title} has nothing to read aloud',
      );
      expect(lesson.script!.trim(), isNotEmpty);
      expect(
        lesson.brief.trim(),
        isNotEmpty,
        reason: '${lesson.title} gives no direction before recording',
      );
      expect(
        lesson.isBlockedOnSelection,
        isFalse,
        reason: '${lesson.title} is waiting on a clip nobody has chosen',
      );
      // And the rubric can actually produce a passing score for it.
      expect(passingScoreFor(lesson).composite, greaterThanOrEqualTo(60));
    }
  });

  testWidgets('lesson 6 stays blocked on content, not on progress', (
    tester,
  ) async {
    await pumpTree(tester);
    await tapUnit(tester);

    for (var i = 0; i < 5; i++) {
      await completeLesson(tester, articulation().lessons[i]);
    }

    final sixth = tester
        .widgetList<LessonNode>(find.byType(LessonNode))
        .elementAt(5);

    expect(sixth.lesson.title, 'Hear It Done Well');
    expect(sixth.unlock.isOpen, isFalse);
    expect(
      sixth.unlock.reason,
      LessonLockReason.awaitingContent,
      reason:
          'after finishing everything before it, the only thing still holding '
          'this lesson closed is a clip nobody has chosen',
    );
    // And it says so, rather than showing the same padlock as a lesson the
    // user simply has not reached.
    expect(find.text('Clip not chosen yet'), findsOneWidget);
  });

  group('Meet Your Voice', () {
    // The first unit a real user meets, and the one that was a planned count
    // with no lessons behind it until now. Reachability and completability are
    // asserted separately on purpose: a route that resolves onto a lesson with
    // nothing to read is not a completable lesson, and the two failures look
    // nothing alike.
    Unit meetYourVoice() => unitTitled('Meet Your Voice');

    testWidgets('expands to five real lessons, not an empty planned count', (
      tester,
    ) async {
      await pumpTree(tester);
      await tapUnit(tester, 'Meet Your Voice');

      expect(
        meetYourVoice().lessons,
        hasLength(5),
        reason: 'the unit should be authored, not a planned_lesson_count',
      );
      expect(find.byType(LessonNode), findsNWidgets(5));
      expect(find.text('Your Voice, Unedited'), findsOneWidget);
      expect(find.text('One Minute, No Edits'), findsOneWidget);
    });

    testWidgets('reachability: the five open one after another', (
      tester,
    ) async {
      await pumpTree(tester);
      await tapUnit(tester, 'Meet Your Voice');

      // Nothing unit-specific: this is the same LessonUnlockEvaluator that
      // gates Articulation & Diction.
      for (var i = 0; i < 5; i++) {
        final nodes = tester
            .widgetList<LessonNode>(find.byType(LessonNode))
            .toList();
        expect(
          nodes[i].unlock.isOpen,
          isTrue,
          reason: 'lesson ${i + 1} should be reachable by now',
        );
        expect(
          nodes[i].onTap,
          isNotNull,
          reason: 'lesson ${i + 1} is open but has no way in',
        );
        for (final later in nodes.skip(i + 1)) {
          expect(
            later.unlock.isOpen,
            isFalse,
            reason: '${later.lesson.title} should still be closed',
          );
        }
        await completeLesson(tester, meetYourVoice().lessons[i]);
      }

      final finished = tester
          .widgetList<LessonNode>(find.byType(LessonNode))
          .toList();
      for (var i = 0; i < 5; i++) {
        expect(finished[i].mastery.everAttempted, isTrue);
      }
    });

    test('completability: every lesson is content the rubric can score', () {
      for (final lesson in meetYourVoice().lessons) {
        expect(
          lesson.type,
          LessonType.scoredRead,
          reason:
              '${lesson.title} declares a type with no runtime path — the '
              'lesson screen dispatches on phase, so anything else renders the '
              'record view and is scored against its script anyway',
        );
        expect(
          lesson.script?.trim(),
          isNotEmpty,
          reason: '${lesson.title} has nothing to read aloud',
        );
        expect(
          lesson.brief.trim(),
          isNotEmpty,
          reason: '${lesson.title} gives no direction before recording',
        );
        expect(lesson.isBlockedOnSelection, isFalse);
        expect(
          lesson.targetWpmMin,
          isNotNull,
          reason: '${lesson.title} has no pace band, so pace goes unweighted',
        );
        expect(lesson.targetWpmMin! < lesson.targetWpmMax!, isTrue);

        // The real rubric, on a faithful read, must actually pass it. A lesson
        // nobody can score above Bronze would gate the whole unit behind it.
        final score = passingScoreFor(lesson);
        expect(
          score.composite,
          greaterThanOrEqualTo(60),
          reason:
              '${lesson.title} scores ${score.composite} on a perfect read, '
              'which would leave the lesson after it unreachable',
        );
      }
    });

    test('the pace band is chosen per lesson, not copied', () {
      // The band is a teaching instrument; identical bands across a unit are a
      // sign nobody decided. See Design.md, "Authoring a lesson".
      final bands = meetYourVoice().lessons
          .map((l) => '${l.targetWpmMin}-${l.targetWpmMax}')
          .toSet();
      expect(
        bands.length,
        greaterThan(3),
        reason: 'five lessons sharing one band means the number is decorative',
      );
    });
  });

  testWidgets('a lesson already opened is never taken away again', (
    tester,
  ) async {
    await pumpTree(tester);
    await tapUnit(tester);
    await completeLesson(tester, articulation().lessons.first);

    // Drop lesson 1's *level* below the bar that opened lesson 2, while
    // keeping the score it actually achieved — the exact shape a decay or a
    // restored backup leaves behind.
    final first = articulation().lessons.first;
    await db.saveMastery(
      lessonId: first.id,
      unitId: first.unitId,
      mastery: Mastery(
        level: MasteryLevel.locked,
        attempts: 1,
        bestScore: 78,
        lastPromotedOn: null,
        lastAttemptedOn: DateTime(2026, 9, 2),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester
          .widgetList<LessonNode>(find.byType(LessonNode))
          .elementAt(1)
          .unlock
          .isOpen,
      isTrue,
      reason: 'never re-lock something the user has already been given',
    );
  });
}
