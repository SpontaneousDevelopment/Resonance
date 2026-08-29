import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/audio/frame_buffer.dart';

Uint8List pcm16(List<double> samples) {
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(i * 2, (samples[i] * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  group('re-chunking', () {
    test('a callback smaller than a frame produces nothing yet', () {
      final buffer = FrameBuffer(frameSize: 512);
      expect(buffer.addSamples(Float32List(100)), isEmpty);
      expect(buffer.addSamples(Float32List(100)), isEmpty);
    });

    test('emits exactly when the frame fills', () {
      final buffer = FrameBuffer(frameSize: 512);

      expect(buffer.addSamples(Float32List(511)), isEmpty);
      final frames = buffer.addSamples(Float32List(1));
      expect(frames, hasLength(1));
      expect(frames.single, hasLength(512));
    });

    test('a large callback yields several frames', () {
      final buffer = FrameBuffer(frameSize: 512);
      expect(buffer.addSamples(Float32List(512 * 3)), hasLength(3));
    });

    test('carries the remainder across callbacks', () {
      final buffer = FrameBuffer(frameSize: 4);

      expect(buffer.addSamples(Float32List.fromList([1, 2, 3])), isEmpty);
      final frames = buffer.addSamples(Float32List.fromList([4, 5, 6, 7, 8]));

      expect(frames, hasLength(2));
      expect(frames[0], [1, 2, 3, 4]);
      expect(frames[1], [5, 6, 7, 8]);
    });

    test('loses not one sample across ragged callbacks', () {
      // The bug this guards: dropping a few milliseconds per callback puts the
      // pitch contour progressively out of sync with the audio it describes.
      final buffer = FrameBuffer(frameSize: 64);
      final rng = math.Random(3);

      final sent = <double>[];
      final received = <double>[];
      var next = 0.0;

      for (var callback = 0; callback < 200; callback++) {
        final size = 1 + rng.nextInt(300);
        final chunk = Float32List(size);
        for (var i = 0; i < size; i++) {
          chunk[i] = next;
          sent.add(next);
          next += 1;
        }
        for (final frame in buffer.addSamples(chunk)) {
          received.addAll(frame);
        }
      }

      final tail = buffer.flush();
      final tailLength = sent.length - received.length;
      if (tail != null) {
        received.addAll(tail.take(tailLength));
      }

      expect(received, sent, reason: 'samples were dropped or reordered');
      expect(buffer.samplesConsumed, sent.length);
    });

    test('emitted frames are copies, not views of shared state', () {
      final buffer = FrameBuffer(frameSize: 4);
      final first = buffer
          .addSamples(Float32List.fromList([1, 2, 3, 4]))
          .single;
      buffer.addSamples(Float32List.fromList([9, 9, 9, 9]));

      // If the buffer handed out a view of its internal frame, the next
      // callback would silently rewrite a frame the caller is still holding.
      expect(first, [1, 2, 3, 4]);
    });
  });

  group('pcm16 conversion', () {
    test('maps full scale into [-1, 1]', () {
      final buffer = FrameBuffer(frameSize: 4);
      final frame = buffer.addPcm16(pcm16([1.0, -1.0, 0.5, 0.0])).single;

      expect(frame[0], closeTo(1.0, 0.001));
      expect(frame[1], closeTo(-1.0, 0.001));
      expect(frame[2], closeTo(0.5, 0.001));
      expect(frame[3], 0.0);
    });

    test('a full-scale negative sample does not exceed -1.0', () {
      // Dividing by 32767 instead of 32768 makes int16 minimum read as
      // -1.00003, which then registers as clipping on audio that never clipped.
      final buffer = FrameBuffer(frameSize: 1);
      final bytes = ByteData(2)..setInt16(0, -32768, Endian.little);

      final frame = buffer.addPcm16(bytes.buffer.asUint8List()).single;
      expect(frame[0], greaterThanOrEqualTo(-1.0));
      expect(frame[0], closeTo(-1.0, 0.0001));
    });

    test('an odd trailing byte is ignored rather than misread', () {
      final buffer = FrameBuffer(frameSize: 2);
      final bytes = Uint8List.fromList([0x00, 0x40, 0x00]);

      expect(buffer.addPcm16(bytes), isEmpty);
      expect(buffer.samplesConsumed, 1);
    });

    test('an empty callback is a no-op', () {
      final buffer = FrameBuffer(frameSize: 4);
      expect(buffer.addPcm16(Uint8List(0)), isEmpty);
      expect(buffer.samplesConsumed, 0);
    });
  });

  group('flush', () {
    test('zero-pads the tail to a full frame', () {
      final buffer = FrameBuffer(frameSize: 4);
      buffer.addSamples(Float32List.fromList([1, 2]));

      final tail = buffer.flush();
      expect(tail, isNotNull);
      expect(tail, hasLength(4));
      expect(tail![0], 1);
      expect(tail[1], 2);
      expect(tail[2], 0);
      expect(tail[3], 0);
    });

    test('returns null when nothing is pending', () {
      final buffer = FrameBuffer(frameSize: 4);
      buffer.addSamples(Float32List(4));
      expect(buffer.flush(), isNull);
    });

    test('is not repeatable', () {
      final buffer = FrameBuffer(frameSize: 4);
      buffer.addSamples(Float32List.fromList([1, 2]));

      expect(buffer.flush(), isNotNull);
      expect(buffer.flush(), isNull);
    });
  });

  group('elapsed time', () {
    test('counts every sample accepted, including incomplete frames', () {
      final buffer = FrameBuffer(frameSize: 1024);
      buffer.addSamples(Float32List(500));

      // The elapsed readout comes from the audio clock, so a partial frame
      // still has to count — otherwise the timer visibly lags the waveform.
      expect(buffer.samplesConsumed, 500);
    });

    test('reset clears both the tail and the count', () {
      final buffer = FrameBuffer(frameSize: 4);
      buffer.addSamples(Float32List(6));
      buffer.reset();

      expect(buffer.samplesConsumed, 0);
      expect(buffer.flush(), isNull);
    });
  });
}
