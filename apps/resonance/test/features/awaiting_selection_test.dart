import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/curriculum_repository.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';

/// The embed lesson type is built; its clip is not chosen.
///
/// Choosing which performance is worth studying is an editorial judgement, so
/// no placeholder video id sits in the curriculum looking like a decision that
/// was made. These pin that the "unchosen" state is real and visible rather
/// than a comment someone can delete without noticing.
late Curriculum seed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    seed = await const CurriculumRepository().load();
  });

  test('the embed lesson exists and is marked as awaiting a clip', () {
    final lesson = seed.lessonById('t1u3l6-listen-and-analyse');

    expect(lesson, isNotNull);
    expect(lesson!.type, LessonType.listenAndAnalyse);
    expect(lesson.isBlockedOnSelection, isTrue);
  });

  test('it carries no video id — nothing was defaulted in', () {
    // The failure this guards: a placeholder id shipping and looking like a
    // choice. The compiler refuses both being set at once; this checks the
    // shipped seed.
    final lesson = seed.lessonById('t1u3l6-listen-and-analyse')!;

    expect(lesson.reference, isNotNull);
    expect(lesson.reference!.source, ReferenceSource.embed);
    expect(lesson.reference!.videoId, isNull);
  });

  test('every other authored lesson is playable', () {
    // Exactly one lesson is blocked. If a second appears, it should be a
    // deliberate addition rather than a slip.
    final blocked = seed.allLessons
        .where((l) => l.isBlockedOnSelection)
        .map((l) => l.id)
        .toList();

    expect(blocked, ['t1u3l6-listen-and-analyse']);
  });

  test('the unit still opens on a lesson that can be attempted', () {
    // The tree opens the first playable lesson. A unit whose first entry were
    // blocked must not dead-end the user.
    final unit = seed.unitById('t1u3-articulation')!;
    final firstPlayable = unit.lessons.firstWhere(
      (l) => !l.isBlockedOnSelection,
    );

    expect(firstPlayable.id, isNot('t1u3l6-listen-and-analyse'));
    expect(unit.lessons.where((l) => !l.isBlockedOnSelection), isNotEmpty);
  });

  test('a blocked lesson still requires the network, so gating is honest', () {
    // It is an embed either way; the tree greys it for the right reason.
    final lesson = seed.lessonById('t1u3l6-listen-and-analyse')!;
    expect(lesson.requiresNetwork, isTrue);
  });
}
