import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:resonance/core/audio/recording_session.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

/// A microphone that emits a fixed number of PCM frames per take.
///
/// Each take gets its own stream and its own file path, so the test can tell
/// them apart — which is the whole point: a session reused across takes must
/// not carry the previous one's audio into the next.
class ScriptedCapture implements AudioCapture {
  ScriptedCapture({required this.bytesPerTake});

  final int bytesPerTake;

  int startCount = 0;
  int stopCount = 0;
  final List<StreamController<Uint8List>> controllers = [];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startCount++;
    final controller = StreamController<Uint8List>();
    controllers.add(controller);
    // A distinct sample value per take, so audio from take 1 is identifiable
    // if it ever leaks into take 2.
    final value = (startCount * 1000).clamp(0, 30000);
    scheduleMicrotask(() {
      final bytes = Uint8List(bytesPerTake);
      final view = ByteData.view(bytes.buffer);
      for (var i = 0; i + 1 < bytesPerTake; i += 2) {
        view.setInt16(i, value, Endian.little);
      }
      controller.add(bytes);
    });
    return controller.stream;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    await controllers.last.close();
    return '/tmp/take_$stopCount.m4a';
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    for (final c in controllers) {
      if (!c.isClosed) await c.close();
    }
  }
}

/// Stands in for the native DSP, which has no symbols in the Dart VM.
///
/// The frame's first sample is echoed back through [FrameAnalysis.rms], so a
/// test can still tell one take's audio from another's without the real
/// analyser present.
class FakeAnalyser implements VoiceAnalyser {
  @override
  final int sampleRate = 48000;

  @override
  final int frameSize = 2048;

  @override
  double noiseFloorDb = -60;

  @override
  FrameAnalysis analyse(Float32List frame, {bool detectPitch = true}) =>
      FrameAnalysis(
        rms: frame.isEmpty ? 0 : frame.first.abs(),
        db: -20,
        peak: 0.5,
        pitchHz: 120,
        pitchConfidence: 0.9,
        isVoiced: true,
        isClipping: false,
      );

  @override
  double plosiveScore(Float32List frame) => 0;

  @override
  Float32List waveformEnvelope(Float32List samples, int bucketCount) =>
      Float32List(bucketCount);

  @override
  void reset() {}

  @override
  void dispose() {}
}

void main() {
  /// Three cycles on one session.
  ///
  /// A multi-take lesson records N times through the same [RecordingSession],
  /// and nothing until now exercised more than one. The failure this guards is
  /// specific and quiet: frames accumulating across takes, so take three
  /// contains all three recordings and scores against a transcript that never
  /// happened.
  test(
    'a session records three takes without carrying audio between them',
    () async {
      final capture = ScriptedCapture(bytesPerTake: 4096 * 2);
      final session = RecordingSession(
        capture: capture,
        analyser: FakeAnalyser(),
        frameSize: 2048,
      );
      addTearDown(session.dispose);

      final takes = <Take>[];
      for (var i = 0; i < 3; i++) {
        await session.start(path: '/tmp/take_$i.m4a');
        // Let the scripted frames arrive.
        await Future<void>.delayed(Duration.zero);
        takes.add(await session.stop());
      }

      expect(
        capture.startCount,
        3,
        reason: 'the recorder should start per take',
      );
      expect(capture.stopCount, 3);
      expect(takes, hasLength(3));

      // The invariant: each take holds its own audio, not a running total.
      final frameCounts = takes.map((t) => t.frames.length).toList();
      expect(
        frameCounts.toSet(),
        hasLength(1),
        reason:
            'takes contained different amounts of audio ($frameCounts) — frames '
            'are accumulating across takes rather than resetting',
      );
      expect(frameCounts.first, greaterThan(0));

      // And it is genuinely different audio, not the first take replayed.
      expect(takes[0].frames.first.first, isNot(takes[1].frames.first.first));
      expect(takes[1].frames.first.first, isNot(takes[2].frames.first.first));
    },
  );

  test('each take reports its own file', () async {
    final capture = ScriptedCapture(bytesPerTake: 4096 * 2);
    final session = RecordingSession(
      capture: capture,
      analyser: FakeAnalyser(),
      frameSize: 2048,
    );
    addTearDown(session.dispose);

    final paths = <String?>[];
    for (var i = 0; i < 3; i++) {
      await session.start(path: '/tmp/t$i.m4a');
      await Future<void>.delayed(Duration.zero);
      paths.add((await session.stop()).path);
    }

    expect(
      paths.toSet(),
      hasLength(3),
      reason: 'takes sharing one path would overwrite each other on disk',
    );
  });

  test('plosive scores reset with the frames', () async {
    // They are a parallel list; if one resets and the other does not, the two
    // fall out of alignment and every plosive lands on the wrong frame.
    final capture = ScriptedCapture(bytesPerTake: 4096 * 2);
    final session = RecordingSession(
      capture: capture,
      analyser: FakeAnalyser(),
      frameSize: 2048,
    );
    addTearDown(session.dispose);

    final pairs = <(int, int)>[];
    for (var i = 0; i < 3; i++) {
      await session.start(path: '/tmp/p$i.m4a');
      await Future<void>.delayed(Duration.zero);
      final take = await session.stop();
      pairs.add((take.frames.length, take.plosiveScores.length));
    }

    for (final (frames, plosives) in pairs) {
      expect(
        plosives,
        frames,
        reason: 'plosive scores and frames drifted apart: $pairs',
      );
    }
  });
}
