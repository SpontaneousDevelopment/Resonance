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
    test('a sudden low burst scores higher than a bright sound', () {
      analyser.reset();
      final bright = analyser.plosiveScore(sine(3000, amplitude: 0.3));

      analyser.reset();
      final thump = analyser.plosiveScore(sine(80, amplitude: 0.9));

      expect(thump, greaterThan(bright));
      expect(thump, greaterThan(0.3));
    });

    test('state carries between frames, and reset clears it', () {
      analyser.reset();
      final first = analyser.plosiveScore(sine(80, amplitude: 0.9));
      final sustained = analyser.plosiveScore(sine(80, amplitude: 0.9));

      // Second identical frame is a continuation, not a new onset.
      expect(sustained, lessThan(first));

      analyser.reset();
      expect(
        analyser.plosiveScore(sine(80, amplitude: 0.9)),
        closeTo(first, 0.01),
      );
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
