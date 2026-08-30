import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/progress/progress_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/progress/vocal_energy.dart';
import 'package:resonance/features/skill_tree/mastery_ring.dart';
import 'package:resonance/features/skill_tree/skill_tree_screen.dart';
import 'package:resonance/features/skill_tree/unit_node.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// Asserts the tree renders *persisted* progress, not a constant.
///
/// The gap this closes: the existing tree test asserted that eight mastery
/// rings exist. That passes whether the rings show real progress or the
/// hardcoded `Mastery.fresh()` they used to show — the same failure mode as the
/// plosive detector, where a test proved the code ran without proving it was
/// right.
///
/// These run against a **real in-memory database**, not an overridden provider,
/// so the whole path is exercised: Drift → repository → stream provider →
/// unlock evaluator → widget. Overriding the provider would prove the widget
/// renders what it is handed, which is the weaker claim and not the one that
/// was missing.
late Curriculum seed;

/// The header's own providers, stubbed.
///
/// Without these they resolve `databaseProvider`, which opens the real on-disk
/// database — leaving timers pending after the tree is disposed and failing the
/// test for a reason unrelated to what it asserts. The header has its own
/// coverage; these tests are about the tree.
final _headerOverrides = [
  streakProvider.overrideWith(
    (ref) => Stream.value(
      StreakRow(id: 0, currentStreak: 0, longestStreak: 0, freezesAvailable: 2),
    ),
  ),
  energyProvider.overrideWith((ref) => Stream.value(const VocalEnergy.full())),
  xpTodayProvider.overrideWith((ref) => 0),
];

Mastery at(MasteryLevel level) => Mastery(
  level: level,
  attempts: level.rank,
  bestScore: level.threshold ?? 0,
  lastPromotedOn: DateTime(2026, 9, 1),
);

/// Pumps the tree over mastery that has made a real round-trip through Drift.
///
/// The write and read-back run in [WidgetTester.runAsync] — a widget test's
/// fake clock never advances drift's async work, so a live stream inside the
/// tree would hang forever. The map is then handed to the provider, which keeps
/// the assertion honest: these values came out of a database, not a literal.
///
/// The stream half is covered where fake-async is not in play, in
/// `test/core/progress_repository_test.dart`.
Future<void> withPersistedTree(
  WidgetTester tester,
  Map<String, Mastery> toPersist,
  Future<void> Function() body,
) async {
  tester.view
    ..physicalSize = const Size(900, 2200)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late Map<String, Mastery> readBack;
  await tester.runAsync(() async {
    final db = ResonanceDatabase(NativeDatabase.memory());
    final unit = seed.unitById('t1u3-articulation')!;
    for (final entry in toPersist.entries) {
      await db.saveMastery(
        lessonId: entry.key,
        unitId: unit.id,
        mastery: entry.value,
      );
    }
    readBack = await ProgressRepository(db).allMastery();
    await db.close();
  });

  await tester.pumpWidget(
    ProviderScope(
      // A fresh key per pump. Without it Riverpod reuses the existing container
      // when the same widget is pumped again, and a changed override silently
      // does not take — which would let a test comparing two states pass while
      // rendering the first one twice.
      key: UniqueKey(),
      overrides: [
        curriculumProvider.overrideWith((ref) => seed),
        masteryProvider.overrideWith((ref) => Stream.value(readBack)),
        ..._headerOverrides,
      ],
      child: MaterialApp(
        theme: ResTheme.light(),
        home: const SkillTreeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await body();
}

/// The level shown inside the ring on the Articulation unit's card.
///
/// Scoped to that card's own ring — a looser finder picks up the header's
/// streak and XP digits, which would make the assertion meaningless.
String ringLabel(WidgetTester tester) {
  final card = find.ancestor(
    of: find.text('Articulation & Diction'),
    matching: find.byType(UnitNode),
  );
  final ringText = find.descendant(
    of: find.descendant(of: card, matching: find.byType(MasteryRing)),
    matching: find.byType(Text),
  );
  final widgets = tester.widgetList<Text>(ringText);
  return widgets.isEmpty ? '(no ring)' : widgets.first.data ?? '(null)';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });

  group('the tree reflects persisted mastery', () {
    testWidgets('a fresh user sees no progress', (tester) async {
      await withPersistedTree(tester, const {}, () async {
        expect(ringLabel(tester), '–');
        expect(find.text('Articulation & Diction'), findsOneWidget);
      });
    });

    testWidgets('persisted Gold renders as Gold, not as fresh', (tester) async {
      final lesson = seed.unitById('t1u3-articulation')!.lessons.first;
      await withPersistedTree(
        tester,
        {lesson.id: at(MasteryLevel.gold)},
        () async {
          // Gold is rank 3. A hardcoded Mastery.fresh() renders an en-dash.
          expect(ringLabel(tester), '3');
        },
      );
    });

    testWidgets('different persisted state produces different output', (
      tester,
    ) async {
      // The assertion that distinguishes "reads state" from "returns a constant
      // that happens to match". One state proves nothing.
      final lesson = seed.unitById('t1u3-articulation')!.lessons.first;

      late String bronze;
      await withPersistedTree(
        tester,
        {lesson.id: at(MasteryLevel.bronze)},
        () async {
          bronze = ringLabel(tester);
        },
      );

      late String master;
      await withPersistedTree(
        tester,
        {lesson.id: at(MasteryLevel.master)},
        () async {
          master = ringLabel(tester);
        },
      );

      expect(bronze, '1');
      expect(master, '5');
      expect(bronze, isNot(master));
    });

    testWidgets('the ring shows the furthest lesson reached in the unit', (
      tester,
    ) async {
      // A unit-level ring summarising lesson-level data takes the maximum, so
      // one untouched lesson does not drag a strong unit down.
      final lessons = seed.unitById('t1u3-articulation')!.lessons;
      await withPersistedTree(
        tester,
        {
          lessons[0].id: at(MasteryLevel.bronze),
          lessons[1].id: at(MasteryLevel.diamond),
          lessons[2].id: at(MasteryLevel.silver),
        },
        () async {
          expect(ringLabel(tester), '4');
        },
      );
    });
  });

  group('gating reflects persisted mastery', () {
    testWidgets('the open count comes from the gate, not from authorship', (
      tester,
    ) async {
      await withPersistedTree(tester, const {}, () async {
        expect(find.text('1/8 open'), findsOneWidget);
      });
    });

    testWidgets('mastering an authored unit cannot open an unwritten one', (
      tester,
    ) async {
      final lessons = seed.unitById('t1u3-articulation')!.lessons;
      await withPersistedTree(
        tester,
        {for (final l in lessons) l.id: at(MasteryLevel.master)},
        () async {
          // 1.4 has no lessons, so the gate is satisfied but there is nothing to
          // enter. The tree must not imply otherwise.
          expect(find.text('1/8 open'), findsOneWidget);
          expect(find.text('Pitch & Resonance'), findsOneWidget);
        },
      );
    });
  });

  group('resilience', () {
    testWidgets('mastery for an unknown lesson id is ignored', (tester) async {
      // Progress outlives a curriculum edit that removes a lesson.
      await withPersistedTree(
        tester,
        {'t9u9l9-removed': at(MasteryLevel.master)},
        () async {
          expect(ringLabel(tester), '–');
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets('the tree paints before mastery resolves', (tester) async {
      // The stream is local and fast, so the tree renders immediately and the
      // rings fill in — a spinner here would flash and vanish.
      tester.view
        ..physicalSize = const Size(900, 2200)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumProvider.overrideWith((ref) => seed),
            masteryProvider.overrideWith(
              (ref) => const Stream<Map<String, Mastery>>.empty(),
            ),
            ..._headerOverrides,
          ],
          child: MaterialApp(
            theme: ResTheme.light(),
            home: const SkillTreeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Articulation & Diction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
