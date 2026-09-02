import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/features/skill_tree/lesson_node.dart';
import 'package:resonance/features/skill_tree/skill_tree_screen.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// The unit fan-out, driven by tapping and read frame by frame.
///
/// The claim is not "the cards animate" but that they animate as **one
/// gesture**: a single edge travelling down the list, every card moving at the
/// same speed, each one starting while its neighbour is still moving. A test
/// that only checked the cards eventually appear would pass on all six
/// appearing at once, which is the thing being avoided.
late final Curriculum seed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ResonanceDatabase db;
  late ProviderContainer container;

  setUpAll(() async => seed = await const CurriculumRepository().load());
  setUp(() => db = ResonanceDatabase(NativeDatabase.memory()));
  tearDown(() async {
    // Order matters: the container holds drift's query streams, and closing the
    // database first leaves their cancellation timers pending at teardown.
    container.dispose();
    await db.close();
  });

  Future<void> pumpTree(WidgetTester tester, {bool reduced = false}) async {
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
          // Inside MaterialApp, so the app's own MediaQuery does not shadow it.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: const SkillTreeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapUnit(WidgetTester tester) async {
    await tester.tap(find.text('Articulation & Diction'));
    await tester.pump();
  }

  /// Every lesson card's current opacity, top to bottom.
  List<double> opacities(WidgetTester tester) {
    final cards = find.byType(LessonNode);
    return [
      for (var i = 0; i < cards.evaluate().length; i++)
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: cards.at(i), matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
    ];
  }

  group('expanding', () {
    testWidgets('the cards do not all arrive at once', (tester) async {
      await pumpTree(tester);
      await tapUnit(tester);

      // Part-way through the fan.
      await tester.pump(const Duration(milliseconds: 120));
      final mid = opacities(tester);

      expect(mid, isNotEmpty);
      expect(
        mid.toSet().length,
        greaterThan(1),
        reason:
            'every card had the same opacity ($mid) — they are appearing '
            'together rather than fanning out',
      );
      // And in order: earlier cards are further along than later ones.
      for (var i = 1; i < mid.length; i++) {
        expect(
          mid[i],
          lessThanOrEqualTo(mid[i - 1] + 0.001),
          reason: 'card $i is ahead of the one above it: $mid',
        );
      }
    });

    testWidgets('it reads as one gesture, not a queue', (tester) async {
      // The last card must start moving before the first has settled. This is
      // the mechanical form of "one edge travelling down the list"; without the
      // overlap the cards arrive one after another with gaps between.
      await pumpTree(tester);
      await tapUnit(tester);

      final count = seed.allUnits
          .firstWhere((u) => u.title == 'Articulation & Diction')
          .lessons
          .length;
      final stagger = FeedbackChoreography.unitFanStagger(count);
      final total = FeedbackChoreography.unitFanTotal;
      final lastStarts = stagger * (count - 1);
      final firstEnds = total - lastStarts;

      expect(
        lastStarts.inMilliseconds,
        lessThan(firstEnds.inMilliseconds),
        reason:
            'the last card starts at ${lastStarts.inMilliseconds}ms but the '
            'first finishes at ${firstEnds.inMilliseconds}ms — no overlap, so '
            'the cards queue instead of fanning',
      );

      // Observed rather than only computed: at the moment the last card begins,
      // the first is still on its way.
      await tester.pump(lastStarts + const Duration(milliseconds: 4));
      final at = opacities(tester);
      expect(
        at.first,
        lessThan(1.0),
        reason: 'the first card had settled: $at',
      );
      expect(at.last, lessThan(at.first));
    });

    testWidgets('every card ends fully visible and in place', (tester) async {
      await pumpTree(tester);
      await tapUnit(tester);
      await tester.pump(FeedbackChoreography.unitFanTotal);
      await tester.pump(const Duration(milliseconds: 50));

      expect(opacities(tester), everyElement(1.0));
      for (final t in tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(LessonNode),
          matching: find.byType(Transform),
        ),
      )) {
        expect(t.transform.getTranslation().y, 0);
      }
    });
  });

  group('collapsing', () {
    testWidgets('runs the same wave backwards', (tester) async {
      await pumpTree(tester);
      await tapUnit(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacities(tester), everyElement(1.0));

      await tapUnit(tester);
      await tester.pump(const Duration(milliseconds: 120));
      final mid = opacities(tester);

      expect(
        mid.toSet().length,
        greaterThan(1),
        reason: 'the cards vanished together instead of folding back: $mid',
      );
      // Folding back the way it came out: the last card leads on the way in.
      for (var i = 1; i < mid.length; i++) {
        expect(mid[i], lessThanOrEqualTo(mid[i - 1] + 0.001));
      }
    });

    testWidgets('ends with the cards gone, not merely invisible', (
      tester,
    ) async {
      await pumpTree(tester);
      await tapUnit(tester);
      await tester.pump(const Duration(milliseconds: 500));

      await tapUnit(tester);
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byType(LessonNode),
        findsNothing,
        reason:
            'a clipped-but-present card is still reachable by a screen reader',
      );
    });
  });

  group('reduced motion', () {
    testWidgets('reaches the same end state with no travel', (tester) async {
      await pumpTree(tester, reduced: true);
      await tapUnit(tester);
      // One frame. No waiting for a fan that should not be running.
      await tester.pump();

      final o = opacities(tester);
      expect(o, isNotEmpty);
      expect(
        o,
        everyElement(1.0),
        reason: 'cards should be fully present immediately: $o',
      );
      expect(
        find.byType(LessonNode),
        findsNWidgets(
          seed.allUnits
              .firstWhere((u) => u.title == 'Articulation & Diction')
              .lessons
              .length,
        ),
      );
    });

    testWidgets('collapsing is immediate too', (tester) async {
      await pumpTree(tester, reduced: true);
      await tapUnit(tester);
      await tester.pump();

      await tapUnit(tester);
      await tester.pump();

      expect(find.byType(LessonNode), findsNothing);
    });

    testWidgets('with motion enabled the cards are genuinely mid-flight', (
      tester,
    ) async {
      // The inverse of the first test, so it cannot pass by the fan never
      // running at all.
      await pumpTree(tester);
      await tapUnit(tester);
      await tester.pump();

      final o = opacities(tester);
      expect(
        o.any((v) => v < 1.0),
        isTrue,
        reason: 'nothing was animating one frame in: $o',
      );
    });
  });
}
