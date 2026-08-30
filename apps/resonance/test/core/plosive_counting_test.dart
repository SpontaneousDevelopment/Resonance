import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/scoring/attempt_scorer.dart';

/// Counting policy, separate from detection.
///
/// The bug this covers: every frame clearing the threshold was counted as its
/// own pop. Measured on recorded audio with five injected pops at known times,
/// three of them produced two consecutive qualifying frames — eight counted
/// events for five physical pops, a 60% over-count. On a noisier real
/// microphone that compounds into rates like the 284 per minute reported.
const frame = Duration(milliseconds: 43);

List<double> frames(String pattern) =>
    pattern.split('').map((c) => c == 'X' ? 0.9 : 0.0).toList();

int count(String pattern) =>
    AttemptScorer.countPlosiveEvents(frames(pattern), frameDuration: frame);

void main() {
  group('one pop, however many frames it spans', () {
    test('a single frame is one event', () {
      expect(count('..X..........'), 1);
    });

    test('two consecutive frames are still one event', () {
      // The measured real-audio case.
      expect(count('..XX.........'), 1);
    });

    test('three consecutive frames are still one event', () {
      expect(count('..XXX........'), 1);
    });

    test('a frame within the refractory window does not count', () {
      // 43 ms frames, 200 ms window — the next four frames are suppressed.
      expect(count('X.X..........'), 1);
      expect(count('X..X.........'), 1);
      expect(count('X...X........'), 1);
    });
  });

  group('genuinely separate pops', () {
    test('are counted separately once the window passes', () {
      // Five frames apart is 215 ms — beyond the window.
      expect(count('X....X.......'), 2);
    });

    test('a realistic run of speech with three pops', () {
      expect(count('..X.......XX........X....'), 3);
    });

    test('the window is shorter than the fastest human articulation', () {
      // Nobody can produce consecutive plosives faster than ~200 ms, so a real
      // pop is never swallowed. Pops 250 ms apart must both register.
      expect(count('X......X'), 2);
    });
  });

  group('degenerate input', () {
    test('no frames means no events', () {
      expect(count(''), 0);
    });

    test('no qualifying frames means no events', () {
      expect(count('........'), 0);
    });

    test('every frame qualifying is still bounded by the window', () {
      // A pathological take where the detector fires constantly must not
      // report one event per frame — that is precisely the reported bug.
      final all = List.filled(100, 0.9);
      final events = AttemptScorer.countPlosiveEvents(
        all,
        frameDuration: frame,
      );
      // 100 frames at 43 ms is 4.3 s; at one per 200 ms that is at most 22.
      expect(events, lessThanOrEqualTo(22));
      expect(events, greaterThan(0));
    });

    test('a zero frame duration is refused rather than dividing by zero', () {
      expect(
        AttemptScorer.countPlosiveEvents([
          0.9,
          0.9,
        ], frameDuration: Duration.zero),
        0,
      );
    });
  });

  group('threshold', () {
    test('scores below the threshold never count', () {
      expect(
        AttemptScorer.countPlosiveEvents([
          0.54,
          0.4,
          0.0,
          0.549,
        ], frameDuration: frame),
        0,
      );
    });

    test('a score exactly at the threshold counts', () {
      // The detector returns exactly 0.55 for a frame meeting every minimum
      // condition, so the boundary must be inclusive or those are lost.
      expect(AttemptScorer.countPlosiveEvents([0.55], frameDuration: frame), 1);
    });
  });
}
