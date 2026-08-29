import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/features/skill_tree/mastery_ring.dart';
import 'package:resonance/features/skill_tree/skill_tree_screen.dart';
import 'package:resonance/features/skill_tree/unit_node.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// These run against the **real compiled seed** in assets/, not a fixture.
/// That makes them a check on the content pipeline as well as the widgets: if
/// someone edits the YAML and forgets to recompile, or compiles something
/// malformed, these fail.
/// The seed, loaded once. Widget tests override the provider with this rather
/// than awaiting a real asset read mid-pump — an unresolved [FutureProvider]
/// leaves a [CircularProgressIndicator] spinning, and `pumpAndSettle` will
/// never return while an indefinite animation is running.
late final Curriculum seed;

Future<void> _pumpTree(
  WidgetTester tester, {
  Size size = const Size(900, 1600),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [curriculumProvider.overrideWith((ref) => seed)],
      child: MaterialApp(
        theme: ResTheme.light(),
        home: const SkillTreeScreen(),
      ),
    ),
  );
  // One frame to resolve the override, one to run the entry animation to
  // completion. No pumpAndSettle: see above.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });

  group('curriculum seed', () {
    test('loads and parses', () async {
      final curriculum = await const CurriculumRepository().load();

      expect(curriculum.version, 1);
      expect(curriculum.tiers, hasLength(1));
      expect(curriculum.tiers.first.title, 'Foundations');
      expect(curriculum.tiers.first.units, hasLength(8));
    });

    test('the MVP unit is fully authored', () async {
      final curriculum = await const CurriculumRepository().load();
      final unit = curriculum.unitById('t1u3-articulation');

      expect(unit, isNotNull);
      expect(unit!.title, 'Articulation & Diction');
      expect(unit.lessons, hasLength(5));
      expect(unit.isAuthored, isTrue);
      expect(unit.label, '1.3');
    });

    test('every authored lesson has the script its type requires', () async {
      final curriculum = await const CurriculumRepository().load();

      for (final lesson in curriculum.allLessons) {
        expect(
          lesson.script,
          isNotNull,
          reason: '${lesson.id} is a ${lesson.type.name} and needs a script',
        );
        expect(lesson.brief, isNotEmpty, reason: '${lesson.id} has no brief');
      }
    });

    test('no authored lesson requires the network', () async {
      // The MVP promise is that unit 1.3 works on a plane. This test is what
      // keeps that true when someone later adds an embed lesson to it.
      final curriculum = await const CurriculumRepository().load();
      final unit = curriculum.unitById('t1u3-articulation')!;

      for (final lesson in unit.lessons) {
        expect(
          lesson.requiresNetwork,
          isFalse,
          reason: '${lesson.id} would break the offline guarantee',
        );
      }
    });

    test('folded YAML scripts are collapsed to single paragraphs', () async {
      final curriculum = await const CurriculumRepository().load();
      final lesson = curriculum.lessonById('t1u3l1-plosive-precision')!;

      expect(lesson.script, isNot(contains('\n')));
      expect(lesson.script, startsWith('Peter picked a bitter batch'));
    });
  });

  group('skill tree', () {
    testWidgets('renders every unit in the tier', (tester) async {
      await _pumpTree(tester);

      expect(find.byType(UnitNode), findsNWidgets(8));
      expect(find.text('Articulation & Diction'), findsOneWidget);
      expect(find.text('Foundations Check'), findsOneWidget);
    });

    testWidgets('shows the tier header with open/total counts', (tester) async {
      await _pumpTree(tester);

      expect(find.text('TIER 1'), findsOneWidget);
      // One of eight units is authored.
      expect(find.text('1/8 open'), findsOneWidget);
    });

    testWidgets('unauthored units show their planned size, not zero', (
      tester,
    ) async {
      await _pumpTree(tester);

      // Unit 1.2 is unwritten but declares seven lessons.
      expect(find.text('7 lessons'), findsWidgets);
      expect(find.text('0 lessons'), findsNothing);
      expect(find.text('coming soon'), findsWidgets);
    });

    testWidgets('the gate unit is badged as a check', (tester) async {
      await _pumpTree(tester);
      expect(find.text('CHECK'), findsOneWidget);
    });

    testWidgets('every unit shows a mastery ring', (tester) async {
      await _pumpTree(tester);
      expect(find.byType(MasteryRing), findsNWidgets(8));
    });

    testWidgets('locked units are marked unavailable to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpTree(tester);

      final semantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'1\.2 Breath & Support')),
      );
      expect(semantics.label, contains('Locked'));
      handle.dispose();
    });
  });

  group('theme', () {
    testWidgets('renders in both light and dark without falling back to '
        'a default colour scheme', (tester) async {
      for (final (mode, expected) in [
        (Brightness.light, ResTheme.light()),
        (Brightness.dark, ResTheme.dark()),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: expected,
              home: Builder(
                builder: (context) {
                  final colors = context.colors;
                  // Would throw if the extension were missing.
                  expect(colors.tier(1), isNot(colors.tier(4)));
                  expect(colors.paper, isNot(const Color(0xFF000000)));
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(mode, isNotNull);
      }
    });
  });
}
