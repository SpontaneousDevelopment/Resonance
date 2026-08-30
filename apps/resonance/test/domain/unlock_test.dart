import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/curriculum/mastery.dart';
import 'package:resonance/domain/curriculum/unlock.dart';

const evaluator = UnlockEvaluator();

/// Runs against the real compiled seed, so the gating is tested against the
/// actual Tier 1 prerequisite graph rather than a convenient fixture.
late Curriculum seed;

Mastery atLevel(MasteryLevel level) => Mastery(
  level: level,
  attempts: level.rank,
  bestScore: level.threshold ?? 0,
  lastPromotedOn: DateTime(2026, 9, 1),
);

void main() {
  // Loading the seed goes through rootBundle, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });

  group('a fresh user', () {
    test('the first unit is open, later ones are not', () {
      final states = evaluator.evaluate(curriculum: seed, mastery: {});

      // Unit 1.1 has no prerequisites — but it is unwritten, so it reports
      // "not yet authored" rather than pretending to be enterable.
      expect(states['t1u1-meet-your-voice']!.reason, LockReason.notYetAuthored);

      // 1.3 is authored but sits behind 1.2, which is unwritten and therefore
      // cannot gate anything — so 1.3 opens.
      expect(states['t1u3-articulation']!.isOpen, isTrue);
    });

    test('every unit gets a state', () {
      final states = evaluator.evaluate(curriculum: seed, mastery: {});
      expect(states.length, seed.allUnits.length);
    });
  });

  group('the gate', () {
    test('an authored prerequisite below Silver holds the next unit shut', () {
      // 1.4 sits behind 1.3, which is authored. With no progress, 1.4 is shut.
      final states = evaluator.evaluate(curriculum: seed, mastery: {});
      final pitch = states['t1u4-pitch-resonance']!;

      expect(pitch.reason, LockReason.prerequisitesIncomplete);
      expect(pitch.blockingUnitIds, contains('t1u3-articulation'));
      expect(pitch.lessonsRemaining, greaterThan(0));
    });

    test('Bronze is not enough — Silver is the bar', () {
      // Bronze means passed once, which can be a single lucky take. Silver
      // means passed again on a later day, which is the first evidence of
      // retention.
      final unit = seed.unitById('t1u3-articulation')!;
      final bronze = {
        for (final l in unit.lessons) l.id: atLevel(MasteryLevel.bronze),
      };

      final states = evaluator.evaluate(curriculum: seed, mastery: bronze);
      expect(
        states['t1u4-pitch-resonance']!.reason,
        LockReason.prerequisitesIncomplete,
      );
    });

    test('80% at Silver opens the next unit', () {
      final unit = seed.unitById('t1u3-articulation')!;
      final mastery = <String, Mastery>{};
      final needed = (unit.lessons.length * UnlockEvaluator.requiredProportion)
          .ceil();
      for (var i = 0; i < needed; i++) {
        mastery[unit.lessons[i].id] = atLevel(MasteryLevel.silver);
      }

      final states = evaluator.evaluate(curriculum: seed, mastery: mastery);
      expect(
        states['t1u4-pitch-resonance']!.isOpen,
        isFalse,
        reason: '1.4 is unauthored, so it cannot be "open"',
      );
      expect(
        states['t1u4-pitch-resonance']!.reason,
        LockReason.notYetAuthored,
        reason: 'the gate is satisfied; only missing content remains',
      );
    });

    test('one stubborn lesson does not wall off the tree', () {
      // 80%, not 100% — a single lesson someone cannot crack must not end
      // their progress through the whole curriculum.
      final unit = seed.unitById('t1u3-articulation')!;
      final mastery = {
        for (final l in unit.lessons) l.id: atLevel(MasteryLevel.gold),
      };
      mastery[unit.lessons.last.id] = const Mastery.fresh();

      final states = evaluator.evaluate(curriculum: seed, mastery: mastery);
      expect(states['t1u4-pitch-resonance']!.reason, LockReason.notYetAuthored);
    });

    test('remaining count shrinks as lessons are mastered', () {
      final unit = seed.unitById('t1u3-articulation')!;

      final none = evaluator.evaluate(curriculum: seed, mastery: {});
      final some = evaluator.evaluate(
        curriculum: seed,
        mastery: {unit.lessons.first.id: atLevel(MasteryLevel.silver)},
      );

      expect(
        some['t1u4-pitch-resonance']!.lessonsRemaining,
        lessThan(none['t1u4-pitch-resonance']!.lessonsRemaining),
      );
    });
  });

  group('robustness', () {
    test('an unwritten prerequisite cannot gate anything', () {
      // Otherwise unwritten content would silently wall off everything behind
      // it, which looks identical to a bug.
      final states = evaluator.evaluate(curriculum: seed, mastery: {});
      expect(states['t1u3-articulation']!.blockingUnitIds, isEmpty);
    });

    test('the gate unit lists all seven units as prerequisites', () {
      final check = seed.unitById('t1u8-foundations-check')!;
      expect(check.prerequisiteUnitIds, hasLength(7));

      // Only the authored one can actually block it today.
      final states = evaluator.evaluate(curriculum: seed, mastery: {});
      expect(states['t1u8-foundations-check']!.blockingUnitIds, [
        't1u3-articulation',
      ]);
    });
  });
}
