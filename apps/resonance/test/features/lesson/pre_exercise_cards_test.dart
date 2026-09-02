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
    // Past the 300ms reveal, so the outgoing card has actually left.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Past the prompt delay and a blink or two.
  Future<void> settlePrompt(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('pacing', () {
    testWidgets('only the first chunk is on screen to begin with', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('First beat.'), findsOneWidget);
      expect(
        find.text('Second beat.'),
        findsNothing,
        reason: 'the whole brief must not arrive at once',
      );
      expect(find.text('Third and last beat.'), findsNothing);
    });

    testWidgets('each tap advances exactly one chunk', (tester) async {
      await pump(tester);

      await tapThrough(tester);
      expect(find.text('Second beat.'), findsOneWidget);
      expect(find.text('First beat.'), findsNothing);

      await tapThrough(tester);
      expect(find.text('Third and last beat.'), findsOneWidget);
      expect(find.text('Second beat.'), findsNothing);
    });

    testWidgets('nothing advances on its own', (tester) async {
      await pump(tester);
      // Well past every duration in the choreography.
      await tester.pump(const Duration(seconds: 5));

      expect(
        find.text('First beat.'),
        findsOneWidget,
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
      expect(find.text('Third and last beat.'), findsOneWidget);
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
      expect(find.text('First beat.'), findsOneWidget);
      await tapThrough(tester);
      expect(find.text('Second beat.'), findsOneWidget);
      await tapThrough(tester);
      expect(find.text('Third and last beat.'), findsOneWidget);

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
        find.text('First beat.'),
        findsOneWidget,
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
}
