import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

import 'dsp_library_fixture.dart';

/// These exercise the real native library through FFI. The C algorithms have
/// their own standalone harness; what these prove is the *binding* — struct
/// layout, buffer marshalling, and that nothing leaks or crashes across the
/// boundary.
const sampleRate = 48000;
const frameSize = 2048;

Float32List sine(double hz, {double amplitude = 0.8, int n = frameSize}) {
  return Float32List.fromList([
    for (var i = 0; i < n; i++)
      amplitude * math.sin(2 * math.pi * hz * i / sampleRate),
  ]);
}

Float32List noise({double amplitude = 0.5, int n = frameSize}) {
  final rng = math.Random(7);
  return Float32List.fromList([
    for (var i = 0; i < n; i++) amplitude * (rng.nextDouble() * 2 - 1),
  ]);
}

Float32List silence({int n = frameSize}) => Float32List(n);

void main() {
  late VoiceAnalyser analyser;

  setUpAll(loadNativeDspForTesting);

  setUp(() {
    analyser = VoiceAnalyser(sampleRate: sampleRate, frameSize: frameSize);
    analyser.noiseFloorDb = -60;
  });

  tearDown(() => analyser.dispose());

  group('struct marshalling', () {
    test('every field crosses the boundary populated', () {
      final result = analyser.analyse(sine(220));

      expect(result.rms, greaterThan(0));
      expect(result.db, lessThan(0));
      expect(result.peak, greaterThan(0));
      expect(result.pitchHz, closeTo(220, 3));
      expect(result.pitchConfidence, greaterThan(0.8));
      expect(result.isVoiced, isTrue);
      expect(result.isClipping, isFalse);
    });

    test('bools arrive as bools, not stray ints', () {
      final clipped = sine(220, amplitude: 1.0);
      clipped[100] = 1.0;
      final result = analyser.analyse(clipped);

      expect(result.isClipping, isTrue);
      expect(result.isVoiced, isTrue);
    });
  });

  group('pitch through FFI', () {
    test('tracks a tone across the vocal range', () {
      for (final hz in [90.0, 130.0, 200.0, 300.0, 440.0]) {
        final result = analyser.analyse(sine(hz));
        expect(
          result.pitchHz,
          closeTo(hz, hz * 0.02),
          reason: '$hz Hz read as ${result.pitchHz}',
        );
      }
    });

    test('reports no pitch rather than zero when unvoiced', () {
      final result = analyser.analyse(silence());

      // The distinction the visualiser depends on: a gap, not a line to zero.
      expect(result.hasPitch, isFalse);
      expect(result.pitchHz, kNoPitch);
      expect(result.pitchHz, isNot(0));
      expect(result.isVoiced, isFalse);
    });

    test('noise gets low confidence, not false certainty', () {
      final result = analyser.analyse(noise());
      expect(result.pitchConfidence, lessThan(0.6));
    });

    test('detectPitch: false skips YIN but still meters', () {
      final result = analyser.analyse(sine(220), detectPitch: false);

      expect(result.hasPitch, isFalse);
      expect(result.isVoiced, isTrue);
      expect(result.db, greaterThan(-30));
    });
  });

  group('noise floor gating', () {
    test('a quiet signal above a quiet floor is voiced', () {
      analyser.noiseFloorDb = -70;
      expect(analyser.analyse(sine(180, amplitude: 0.02)).isVoiced, isTrue);
    });

    test('the same signal under a loud floor is not', () {
      analyser.noiseFloorDb = -25;
      expect(analyser.analyse(sine(180, amplitude: 0.02)).isVoiced, isFalse);
    });
  });

  group('semitone conversion', () {
    test('an octave is twelve semitones', () {
      final low = analyser.analyse(sine(110)).semitonesAboveC0;
      final high = analyser.analyse(sine(220)).semitonesAboveC0;

      expect(high - low, closeTo(12, 0.2));
    });

    test('A440 lands on the right absolute pitch', () {
      // A4 is 57 semitones above C0.
      expect(analyser.analyse(sine(440)).semitonesAboveC0, closeTo(57, 0.3));
    });

    test('an unvoiced frame yields NaN, so charts skip it', () {
      expect(analyser.analyse(silence()).semitonesAboveC0.isNaN, isTrue);
    });
  });

  group('plosive detection', () {
    test('the priming frame scores zero', () {
      // There is nothing to compare a first frame against. Treating a zero
      // previous energy as a maximal onset made the first frame of every take
      // a false positive.
      analyser.reset();
      expect(analyser.plosiveScore(sine(80, amplitude: 0.9)), 0.0);
    });

    test('sustained speech-like content never reaches the threshold', () {
      // The bug that shipped: a low fundamental sits under the 200 Hz cutoff,
      // so "the low band dominates" describes an ordinary voice rather than a
      // pop. This asserts an absolute value against the production threshold,
      // which the original tests never did.
      analyser.reset();
      var worst = 0.0;
      for (var f = 0; f < 30; f++) {
        final level = 0.25 + 0.2 * math.sin(f * 0.7);
        final frame = Float32List(frameSize);
        for (var i = 0; i < frameSize; i++) {
          final t = (f * frameSize + i) / sampleRate;
          frame[i] =
              level *
              (math.sin(2 * math.pi * 110 * t) +
                  0.8 * math.sin(2 * math.pi * 330 * t) +
                  0.5 * math.sin(2 * math.pi * 700 * t));
        }
        final score = analyser.plosiveScore(frame);
        if (score > worst) worst = score;
      }
      expect(worst, lessThan(0.55), reason: 'worst frame scored $worst');
    });

    test('a sustained low note stays below the threshold', () {
      analyser.reset();
      var worst = 0.0;
      for (var f = 0; f < 15; f++) {
        final score = analyser.plosiveScore(sine(80, amplitude: 0.9));
        if (score > worst) worst = score;
      }
      expect(worst, lessThan(0.55));
    });

    test('a bright sound never scores', () {
      analyser.reset();
      var worst = 0.0;
      for (var f = 0; f < 6; f++) {
        final score = analyser.plosiveScore(sine(3000, amplitude: 0.4));
        if (score > worst) worst = score;
      }
      expect(worst, 0.0);
    });

    test('a burst above the running baseline is detected', () {
      analyser.reset();
      for (var f = 0; f < 4; f++) {
        analyser.plosiveScore(sine(75, amplitude: 0.04));
      }
      final burst = analyser.plosiveScore(sine(75, amplitude: 0.85));

      expect(burst, greaterThanOrEqualTo(0.55));
    });

    test('the score carries information above its minimum', () {
      // The original collapsed to the low-band ratio for any onset above 1x,
      // so a 24x burst and a 1.01x rise scored identically.
      double burstOf(double amplitude) {
        analyser.reset();
        for (var f = 0; f < 4; f++) {
          analyser.plosiveScore(sine(75, amplitude: 0.04));
        }
        return analyser.plosiveScore(sine(75, amplitude: amplitude));
      }

      expect(burstOf(0.85), greaterThan(burstOf(0.14)));
    });

    test('reset clears the baseline between takes', () {
      analyser.reset();
      for (var f = 0; f < 6; f++) {
        analyser.plosiveScore(sine(75, amplitude: 0.7));
      }
      analyser.reset();
      // First frame after a reset primes again, so it scores nothing.
      expect(analyser.plosiveScore(sine(75, amplitude: 0.7)), 0.0);
    });
  });

  group('waveform envelope', () {
    test('returns ordered min/max pairs', () {
      final envelope = analyser.waveformEnvelope(sine(220), 32);

      expect(envelope, hasLength(64));
      for (var i = 0; i < 32; i++) {
        expect(envelope[i * 2], lessThanOrEqualTo(envelope[i * 2 + 1]));
        expect(envelope[i * 2].abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('captures the full excursion of the signal', () {
      final envelope = analyser.waveformEnvelope(sine(220, amplitude: 0.9), 32);
      final lowest = envelope.where((_) => true).reduce(math.min);
      final highest = envelope.reduce(math.max);

      expect(lowest, lessThan(-0.8));
      expect(highest, greaterThan(0.8));
    });
  });

  group('lifecycle', () {
    test('rejects a frame of the wrong length', () {
      expect(() => analyser.analyse(Float32List(100)), throwsArgumentError);
    });

    test('throws rather than corrupting memory after dispose', () {
      final a = VoiceAnalyser(sampleRate: sampleRate, frameSize: frameSize);
      a.dispose();

      expect(() => a.analyse(sine(220)), throwsStateError);
    });

    test('dispose is idempotent', () {
      final a = VoiceAnalyser(sampleRate: sampleRate, frameSize: frameSize);
      a.dispose();
      expect(a.dispose, returnsNormally);
    });

    test('survives sustained use without leaking buffers', () {
      // Ten seconds of frames at ~23 fps. If the analyser allocated per frame
      // this is where it would show.
      final frame = sine(180);
      for (var i = 0; i < 240; i++) {
        analyser.analyse(frame);
      }
      expect(analyser.analyse(frame).pitchHz, closeTo(180, 4));
    });
  });

  plosiveGuardTests();

  group('free functions', () {
    test('rms of a full-scale sine is 1/sqrt(2)', () {
      expect(rms(sine(220, amplitude: 1.0)), closeTo(0.7071, 0.02));
    });

    test('toDb floors at -100 rather than negative infinity', () {
      expect(toDb(0), -100);
      expect(toDb(1), closeTo(0, 0.001));
      expect(toDb(0.5), closeTo(-6.02, 0.05));
    });
  });
}

/// Added after an audit found `plosiveScore` writing a caller-supplied length
/// into a buffer allocated for `frameSize`. `analyse` had the guard; this did
/// not. The overflow would corrupt whatever malloc placed after the buffer and
/// surface as a crash somewhere unrelated, much later — the worst kind to chase.
void plosiveGuardTests() {
  group('plosiveScore bounds', () {
    late VoiceAnalyser analyser;

    setUp(() {
      analyser = VoiceAnalyser(sampleRate: sampleRate, frameSize: frameSize);
    });
    tearDown(() => analyser.dispose());

    test('rejects a frame longer than frameSize', () {
      expect(
        () => analyser.plosiveScore(Float32List(frameSize * 2)),
        throwsArgumentError,
      );
    });

    test('rejects a frame shorter than frameSize', () {
      expect(
        () => analyser.plosiveScore(Float32List(frameSize ~/ 2)),
        throwsArgumentError,
      );
    });

    test('accepts an exact frame', () {
      expect(() => analyser.plosiveScore(sine(80)), returnsNormally);
    });

    test('a rejected frame leaves the analyser usable', () {
      expect(
        () => analyser.plosiveScore(Float32List(frameSize + 1)),
        throwsArgumentError,
      );
      // If the overflow had happened, this is where the corruption would show.
      expect(analyser.analyse(sine(220)).pitchHz, closeTo(220, 3));
    });
  });
}
