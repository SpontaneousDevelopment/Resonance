import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/curriculum/lesson_unlock.dart';
import 'package:resonance/domain/curriculum/mastery.dart';

/// Lesson-level gating, tested the way unit-level gating is: pure, with no
/// database and no widget, against hand-built units whose shape is visible in
/// the test.
Lesson _lesson(String id, {bool awaiting = false}) => Lesson(
  id: id,
  unitId: 'u',
  title: id,
  type: LessonType.scoredRead,
  brief: '',
  reference: awaiting
      ? const LessonReference(
          source: ReferenceSource.embed,
          awaitingSelection: true,
        )
      : null,
);

Unit _unit(List<Lesson> lessons) => Unit(
  id: 'u',
  tierNumber: 1,
  index: 1,
  title: 'Unit',
  summary: '',
  lessons: lessons,
);

Mastery _at(MasteryLevel level, {int attempts = 1}) => Mastery(
  level: level,
  attempts: attempts,
  bestScore: level.threshold ?? 0,
  lastPromotedOn: DateTime(2026, 9, 1),
  lastAttemptedOn: DateTime(2026, 9, 1),
);

void main() {
  const evaluator = LessonUnlockEvaluator();

  final unit = _unit([_lesson('l1'), _lesson('l2'), _lesson('l3')]);

  Map<String, LessonUnlockState> evaluate(
    Map<String, Mastery> mastery, {
    Unit? on,
    bool unitIsOpen = true,
  }) => evaluator.evaluate(
    unit: on ?? unit,
    unitIsOpen: unitIsOpen,
    mastery: mastery,
  );

  group('a fresh open unit', () {
    test('lesson 1 is always reachable', () {
      expect(evaluate(const {})['l1']!.isOpen, isTrue);
    });

    test('everything after it is not, and names what is blocking', () {
      final states = evaluate(const {});
      expect(states['l2']!.isOpen, isFalse);
      expect(states['l2']!.reason, LessonLockReason.previousLessonIncomplete);
      expect(
        states['l2']!.blockingLessonId,
        'l1',
        reason: 'the UI should be able to say which lesson opens this one',
      );
      expect(states['l3']!.isOpen, isFalse);
    });
  });

  group('progression', () {
    test('passing a lesson opens exactly the next one', () {
      final states = evaluate({'l1': _at(MasteryLevel.bronze)});

      expect(states['l2']!.isOpen, isTrue);
      expect(
        states['l3']!.isOpen,
        isFalse,
        reason: 'passing one lesson must not open the whole unit',
      );
    });

    test('Bronze is enough — the unit gate asks for more, this does not', () {
      expect(
        LessonUnlockEvaluator.requiredLevel,
        MasteryLevel.bronze,
        reason: 'sequencing inside a unit is a lower bar than entering one',
      );
      expect(evaluate({'l1': _at(MasteryLevel.bronze)})['l2']!.isOpen, isTrue);
    });

    test('an attempt that did not pass does not open the next lesson', () {
      // Attempted, scored, still at locked: the take did not reach Bronze.
      final failed = Mastery(
        level: MasteryLevel.locked,
        attempts: 3,
        bestScore: 41,
        lastPromotedOn: null,
        lastAttemptedOn: DateTime(2026, 9, 1),
      );
      expect(evaluate({'l1': failed})['l2']!.isOpen, isFalse);
    });
  });

  group('never re-locking', () {
    test('a lesson already practised stays open even if nothing else has', () {
      // l2 has been played, but l1 shows no pass — the state a decay or a data
      // repair could produce. Taking l2 away again would be the app removing
      // something the user had already been given.
      final states = evaluate({'l2': _at(MasteryLevel.bronze)});
      expect(states['l2']!.isOpen, isTrue);
    });

    test('a decayed previous lesson does not close the next one', () {
      // Decay lowers the level but never the best score. Reading the level
      // here would take lesson 2 away from someone who had already opened it,
      // for having been away a fortnight.
      final decayed = Mastery(
        level: MasteryLevel.locked,
        attempts: 4,
        bestScore: 78,
        lastPromotedOn: DateTime(2026, 8, 1),
        lastAttemptedOn: DateTime(2026, 8, 1),
      );
      expect(evaluate({'l1': decayed})['l2']!.isOpen, isTrue);
    });

    test('an attempted-but-failed lesson stays open', () {
      final scraped = Mastery(
        level: MasteryLevel.locked,
        attempts: 1,
        bestScore: 30,
        lastPromotedOn: null,
        lastAttemptedOn: DateTime(2026, 9, 1),
      );
      expect(evaluate({'l2': scraped})['l2']!.isOpen, isTrue);
    });
  });

  group('a lesson awaiting its clip', () {
    final withGap = _unit([
      _lesson('l1'),
      _lesson('l2', awaiting: true),
      _lesson('l3'),
    ]);

    test('reports awaiting content, not a padlock', () {
      final states = evaluate(const {}, on: withGap);
      expect(states['l2']!.reason, LessonLockReason.awaitingContent);
      expect(
        states['l2']!.reason,
        isNot(LessonLockReason.previousLessonIncomplete),
        reason: 'waiting on an editorial decision is not the user being behind',
      );
    });

    test('says so from the first launch, not only once reached', () {
      // It is a fact about the lesson, so it does not change with progress.
      final early = evaluate(const {}, on: withGap)['l2']!.reason;
      final later = evaluate({
        'l1': _at(MasteryLevel.gold),
      }, on: withGap)['l2']!.reason;
      expect(early, later);
    });

    test('does not wall off the lessons behind it', () {
      // Unopenable content gating real content is the same mistake as an
      // unauthored unit blocking the tree.
      final states = evaluate({'l1': _at(MasteryLevel.bronze)}, on: withGap);
      expect(
        states['l3']!.isOpen,
        isTrue,
        reason: 'l3 should follow l1, skipping the lesson nobody can open',
      );
    });
  });

  group('a closed unit', () {
    test('locks every lesson, including the first', () {
      final states = evaluate(const {}, unitIsOpen: false);
      for (final id in ['l1', 'l2', 'l3']) {
        expect(states[id]!.isOpen, isFalse);
        expect(states[id]!.reason, LessonLockReason.unitLocked);
      }
    });

    test('the reason is the unit, not the lesson before it', () {
      // Otherwise the UI tells someone to finish a lesson they cannot open.
      final states = evaluate({
        'l1': _at(MasteryLevel.gold),
      }, unitIsOpen: false);
      expect(states['l2']!.reason, LessonLockReason.unitLocked);
    });
  });
}
