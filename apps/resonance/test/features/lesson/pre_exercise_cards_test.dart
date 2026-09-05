import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/haptics/haptic_engine.dart';
import 'package:resonance/core/sensory/sensory_director.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/curriculum/brief_chunks.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';
import 'package:resonance/features/lesson/runner/pre_exercise_cards.dart';
import 'package:resonance/ui/tokens/theme.dart';

/// The pre-exercise cards, driven by tapping rather than inspected.
///
/// The claims that matter are about *pacing*: that a chunk only advances when
/// the user asks, that the continue prompt is genuinely absent until the last
/// chunk is showing, and that reduced motion reaches the same end state rather
/// than a different one. A test that only checked the widget builds would pass
/// on a flow that showed every chunk at once.
class _NullHaptics implements HapticEngine {
  final List<HapticCue> played = [];

  @override
  bool get isSupported => true;

  @override
  Future<void> play(HapticCue cue) async => played.add(cue);
}

void main() {
  const chunks = ['First beat.', 'Second beat.', 'Third and last beat.'];

  late RecordingSoundPlayer sounds;
  late _NullHaptics haptics;
  late SensoryDirector director;
  var done = 0;

  setUp(() {
    sounds = RecordingSoundPlayer();
    haptics = _NullHaptics();
    director = SensoryDirector(
      haptics: haptics,
      sounds: SoundPalette(player: sounds),
      scheduler: (_) async {},
    );
    done = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
    List<String> text = chunks,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ResTheme.light(),
        // Inside MaterialApp on purpose: wrapping the app instead leaves its
        // own MediaQuery in front, and the reduced-motion tests then silently
        // exercise the standard path.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: PreExerciseCards(
          title: 'A lesson',
          chunks: text,
          sensory: director,
          onDone: () => done++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapThrough(WidgetTester tester) async {
    await tester.tap(find.byType(PreExerciseCards));
    await tester.pump();
    // Past the card switch and the word reveal, so the outgoing card has left
    // and the incoming one has fully landed.
    await tester.pump(const Duration(milliseconds: 1200));
  }

  /// Past the word reveal, the prompt delay, and a blink or two.
  ///
  /// The prompt is now timed from the last word landing rather than from the
  /// card appearing, so this has to cover both.
  Future<void> settlePrompt(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// The line currently on screen, reassembled from its words.
  ///
  /// The card renders one Text per word so they can fade in individually, so
  /// `find.text('First beat.')` no longer matches anything.
  String visibleChunk(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(PreExerciseCards),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      // The screen's own chrome: the app-bar title and the continue prompt are
      // Text widgets inside this subtree too.
      .where((t) => t != 'Tap to continue' && t != 'A lesson')
      .join()
      .trim();

  group('pacing', () {
    testWidgets('only the first chunk is on screen to begin with', (
      tester,
    ) async {
      await pump(tester);

      expect(visibleChunk(tester), 'First beat.');
      expect(
        visibleChunk(tester),
        isNot(contains('Second')),
        reason: 'the whole brief must not arrive at once',
      );
    });

    testWidgets('each tap advances exactly one chunk', (tester) async {
      await pump(tester);

      await tapThrough(tester);
      expect(visibleChunk(tester), 'Second beat.');

      await tapThrough(tester);
      expect(visibleChunk(tester), 'Third and last beat.');
    });

    testWidgets('nothing advances on its own', (tester) async {
      await pump(tester);
      // Well past every duration in the choreography.
      await tester.pump(const Duration(seconds: 5));

      expect(
        visibleChunk(tester),
        'First beat.',
        reason: 'the user sets the pace, not a timer',
      );
    });
  });

  group('the continue prompt', () {
    testWidgets('is absent until the last chunk is showing', (tester) async {
      await pump(tester);
      await settlePrompt(tester);
      expect(
        find.text('Tap to continue'),
        findsNothing,
        reason: 'the prompt appeared while there was still brief to read',
      );

      await tapThrough(tester);
      await settlePrompt(tester);
      expect(
        find.text('Tap to continue'),
        findsNothing,
        reason: 'still not the last chunk',
      );

      await tapThrough(tester);
      await settlePrompt(tester);
      expect(find.text('Tap to continue'), findsOneWidget);
    });

    testWidgets('does not appear the instant the last chunk lands', (
      tester,
    ) async {
      await pump(tester);
      await tapThrough(tester);
      await tapThrough(tester);

      // On the last chunk, but only just.
      expect(visibleChunk(tester), 'Third and last beat.');
      expect(
        find.text('Tap to continue'),
        findsNothing,
        reason:
            'a prompt arriving with the text competes with it — the last card '
            'is usually the one that says what to do',
      );

      await settlePrompt(tester);
      expect(find.text('Tap to continue'), findsOneWidget);
    });

    testWidgets('a single-chunk brief still gets a prompt', (tester) async {
      await pump(tester, text: const ['Only one thing to say.']);
      await settlePrompt(tester);

      expect(find.text('Tap to continue'), findsOneWidget);
      await tapThrough(tester);
      expect(done, 1);
    });

    testWidgets('tapping on the last chunk begins the exercise', (
      tester,
    ) async {
      await pump(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      await settlePrompt(tester);
      expect(done, 0);

      await tapThrough(tester);
      expect(done, 1, reason: 'the last tap should start the lesson');
    });
  });

  group('reduced motion', () {
    testWidgets('reaches the same end state as the standard path', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);

      // Same chunks, same order, same taps.
      expect(visibleChunk(tester), 'First beat.');
      await tapThrough(tester);
      expect(visibleChunk(tester), 'Second beat.');
      await tapThrough(tester);
      expect(visibleChunk(tester), 'Third and last beat.');

      await settlePrompt(tester);
      expect(
        find.text('Tap to continue'),
        findsOneWidget,
        reason: 'the prompt must still arrive without motion',
      );

      await tapThrough(tester);
      expect(done, 1);
    });

    testWidgets('keeps the tap-to-advance pacing', (tester) async {
      await pump(tester, reduceMotion: true);
      await tester.pump(const Duration(seconds: 5));

      expect(
        visibleChunk(tester),
        'First beat.',
        reason:
            'reduced motion must not auto-advance — that would take the pacing '
            'control away from the person most likely to want it',
      );
    });

    testWidgets('the prompt does not blink', (tester) async {
      await pump(tester, reduceMotion: true);
      await tapThrough(tester);
      await tapThrough(tester);
      await settlePrompt(tester);

      final opacities = <double>[];
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 260));
        opacities.add(
          tester
              .widget<FadeTransition>(
                find.byKey(const ValueKey('continue-prompt-blink')),
              )
              .opacity
              .value,
        );
      }

      expect(
        opacities.toSet(),
        hasLength(1),
        reason: 'the prompt opacity changed over time: $opacities',
      );
      expect(opacities.first, 1.0);
    });

    testWidgets('the prompt does blink with motion enabled', (tester) async {
      // The inverse, so the test above cannot pass by the blink never working.
      await pump(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      await settlePrompt(tester);

      final opacities = <double>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 260));
        opacities.add(
          tester
              .widget<FadeTransition>(
                find.byKey(const ValueKey('continue-prompt-blink')),
              )
              .opacity
              .value,
        );
      }

      expect(
        opacities.length,
        greaterThan(1),
        reason: 'the prompt should be looping its opacity',
      );
    });
  });

  group('chunking comes from the author', () {
    test('sentences become beats', () {
      expect(briefChunks('One thing. Then another. Then a third.'), [
        'One thing.',
        'Then another.',
        'Then a third.',
      ]);
    });

    test('paragraphs outrank sentences', () {
      expect(briefChunks('One. Two.\n\nThree. Four.'), [
        'One. Two.',
        'Three. Four.',
      ]);
    });

    test('a brief with no sentence break is one beat, not a forced split', () {
      final long = 'A single unbroken instruction ${'that runs on ' * 12}';
      expect(
        briefChunks(long),
        hasLength(1),
        reason: 'length must never decide where an idea ends',
      );
    });

    test('empty is empty rather than one blank card', () {
      expect(briefChunks('   '), isEmpty);
    });
  });

  group('the word-by-word reveal', () {
    testWidgets('words arrive one at a time, not all at once', (tester) async {
      await pump(tester, text: const ['One two three four five six seven.']);
      // Mid-reveal.
      await tester.pump(const Duration(milliseconds: 120));

      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(PreExerciseCards),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .toList();

      expect(opacities, isNotEmpty);
      expect(
        opacities.toSet().length,
        greaterThan(1),
        reason:
            'every word had the same opacity ($opacities) — the line '
            'arrived as a block',
      );
      // In reading order: earlier words are further along.
      for (var i = 1; i < opacities.length; i++) {
        expect(opacities[i], lessThanOrEqualTo(opacities[i - 1] + 0.001));
      }
    });

    testWidgets('the prompt waits for the words, not for the card', (
      tester,
    ) async {
      // A long card: the words take well over a second to land, so a prompt
      // timed from the card appearing would arrive while they were still
      // coming.
      const long =
          'One two three four five six seven eight nine ten eleven twelve '
          'thirteen fourteen fifteen sixteen seventeen eighteen.';
      await pump(tester, text: const [long]);

      final settled = FeedbackChoreography.briefWordsSettled(
        long.split(' ').length,
      );
      // Just after the words land, but before the prompt delay has run.
      await tester.pump(settled + const Duration(milliseconds: 200));
      expect(
        find.text('Tap to continue'),
        findsNothing,
        reason: 'the prompt should still be waiting out its delay',
      );

      await tester.pump(FeedbackChoreography.briefPromptDelay);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Tap to continue'), findsOneWidget);
    });

    testWidgets('reduced motion puts every word up at once', (tester) async {
      await pump(
        tester,
        reduceMotion: true,
        text: const ['One two three four five six seven.'],
      );
      await tester.pump();

      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(PreExerciseCards),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .toList();

      expect(opacities, isNotEmpty);
      expect(
        opacities,
        everyElement(1.0),
        reason: 'words should be present immediately: $opacities',
      );
    });
  });
}
