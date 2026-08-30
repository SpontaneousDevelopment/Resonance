/// Real-time voice analysis over raw audio frames.
///
/// The native side is stateless and allocation-free; all buffer ownership lives
/// here in [VoiceAnalyser], which allocates once and reuses the same native
/// memory for every frame. Allocating per frame at 60 Hz would produce exactly
/// the kind of sawtooth GC pressure that shows up as visualiser stutter.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'resonance_dsp_bindings_generated.dart';

const String _libName = 'resonance_dsp';

ffi.DynamicLibrary? _override;

/// Points the bindings at an explicitly loaded library.
///
/// Exists for tests. Under `flutter test` the Dart VM is not the app binary, so
/// on Apple platforms — where the podspec links the DSP statically into the app
/// — [ffi.DynamicLibrary.process] finds none of these symbols. Tests build the
/// C into a standalone dylib and install it here. Production never calls this.
void debugOverrideDspLibrary(ffi.DynamicLibrary? library) {
  _override = library;
  _bindingsCache = null;
}

ffi.DynamicLibrary _openLibrary() {
  final override = _override;
  if (override != null) return override;

  if (Platform.isMacOS || Platform.isIOS) {
    // Statically linked into the app binary by the podspec, so the symbols are
    // already in this process.
    return ffi.DynamicLibrary.process();
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError(
    'resonance_dsp has no build for ${Platform.operatingSystem}',
  );
}

ResonanceDspBindings? _bindingsCache;

ResonanceDspBindings get _bindings =>
    _bindingsCache ??= ResonanceDspBindings(_openLibrary());

/// Sentinel for "no usable pitch in this frame".
///
/// Deliberately not zero and not null-in-a-double: the visualiser must draw a
/// *gap* for an unvoiced frame, and a 0 Hz reading would draw a line to the
/// bottom of the chart, which reads as a sudden pitch drop the speaker never
/// made.
const double kNoPitch = -1.0;

/// One frame's worth of analysis.
class FrameAnalysis {
  const FrameAnalysis({
    required this.rms,
    required this.db,
    required this.peak,
    required this.pitchHz,
    required this.pitchConfidence,
    required this.isVoiced,
    required this.isClipping,
  });

  const FrameAnalysis.silent()
    : rms = 0,
      db = -100,
      peak = 0,
      pitchHz = kNoPitch,
      pitchConfidence = 0,
      isVoiced = false,
      isClipping = false;

  /// Linear RMS level, 0..1.
  final double rms;

  /// Level in dBFS, floored at -100.
  final double db;

  /// Peak absolute sample. Catches short transients that RMS averages away.
  final double peak;

  /// Fundamental in Hz, or [kNoPitch].
  final double pitchHz;

  /// 0..1. The visualiser fades the trace by this rather than drawing a
  /// confident line through a breathy or creaky frame.
  final double pitchConfidence;

  final bool isVoiced;
  final bool isClipping;

  bool get hasPitch => pitchHz > 0;

  /// Pitch as a musical interval above C0, which is what the contour chart
  /// plots — a semitone axis makes an octave leap look like an octave leap,
  /// where a linear Hz axis squashes the bottom of the range flat.
  double get semitonesAboveC0 =>
      hasPitch ? 12 * (math.log(pitchHz / _c0Hz) / math.ln2) : double.nan;

  /// C0, the reference the semitone axis is measured from.
  static const _c0Hz = 16.351625;

  @override
  String toString() =>
      'FrameAnalysis(${db.toStringAsFixed(1)} dB, '
      '${hasPitch ? "${pitchHz.toStringAsFixed(1)} Hz @ ${(pitchConfidence * 100).round()}%" : "unvoiced"}'
      '${isClipping ? ", CLIPPING" : ""})';
}

/// Analyses successive frames of audio, reusing one set of native buffers.
///
/// Not thread-safe and not reentrant: create one per recording session, use it
/// from a single isolate, and [dispose] it when the session ends.
class VoiceAnalyser {
  VoiceAnalyser({this.sampleRate = 48000, this.frameSize = 2048})
    : assert(
        frameSize >= 256,
        'A frame below 256 samples cannot resolve a low fundamental',
      ),
      assert(
        frameSize & (frameSize - 1) == 0,
        'frameSize should be a power of two',
      ) {
    _samples = calloc<ffi.Float>(frameSize);
    _plosiveState = calloc<ResPlosiveState>();
    _bindings.res_plosive_init(_plosiveState);
    _scratch = calloc<ffi.Float>(frameSize ~/ 2);
    _result = calloc<ResFrameAnalysis>();
  }

  /// Samples per second of the incoming audio.
  final int sampleRate;

  /// Window length. 2048 at 48 kHz is ~43 ms — long enough for two periods of
  /// the lowest male fundamental, short enough to stay under a sixth of the
  /// 60 fps frame budget on desktop.
  final int frameSize;

  late final ffi.Pointer<ffi.Float> _samples;
  late final ffi.Pointer<ffi.Float> _scratch;
  late final ffi.Pointer<ResFrameAnalysis> _result;
  late final ffi.Pointer<ResPlosiveState> _plosiveState;

  bool _disposed = false;

  /// The room's measured noise floor in dBFS, used to gate voicing.
  ///
  /// Set from the pre-roll room check. Until that runs it stays at -100, which
  /// disables gating rather than guessing — a wrong floor is worse than none.
  double noiseFloorDb = -100;

  /// Analyses one frame.
  ///
  /// [frame] must hold exactly [frameSize] samples in [-1, 1]. Set
  /// [detectPitch] false for the level meter, where pitch is not drawn and the
  /// YIN pass would be wasted work.
  FrameAnalysis analyse(Float32List frame, {bool detectPitch = true}) {
    _assertUsable();
    if (frame.length != frameSize) {
      throw ArgumentError('Expected $frameSize samples, got ${frame.length}');
    }

    _samples.asTypedList(frameSize).setAll(0, frame);

    _bindings.res_analyse_frame(
      _samples,
      frameSize,
      sampleRate,
      noiseFloorDb,
      detectPitch ? _scratch : ffi.nullptr,
      _result,
    );

    final r = _result.ref;
    return FrameAnalysis(
      rms: r.rms,
      db: r.db,
      peak: r.peak,
      pitchHz: r.pitch_hz,
      pitchConfidence: r.pitch_confidence,
      isVoiced: r.is_voiced == 1,
      isClipping: r.is_clipping == 1,
    );
  }

  /// Plosive energy in this frame.
  ///
  /// Returns 0 when no plosive is present, and 0.55–1.0 when one is — that
  /// lower bound matches the production threshold, so comparing against it
  /// asks "did this qualify at all".
  ///
  /// Stateful across frames: the detector keeps a low-pass filter and a running
  /// baseline of this speaker's normal low-band level, because a plosive is a
  /// burst above the speaker's own level rather than above the previous frame.
  /// Call [reset] between takes.
  ///
  /// The first frame of a take always returns 0 — it primes the baseline, and
  /// there is nothing to compare it against.
  double plosiveScore(Float32List frame) {
    _assertUsable();
    if (frame.length != frameSize) {
      throw ArgumentError('Expected $frameSize samples, got ${frame.length}');
    }
    _samples.asTypedList(frameSize).setAll(0, frame);

    return _bindings.res_plosive_score(
      _samples,
      frameSize,
      sampleRate,
      _plosiveState,
    );
  }

  /// Reduces a buffer to [bucketCount] min/max pairs for waveform drawing.
  ///
  /// Returns a flat list of `bucketCount * 2` values: min then max per bucket.
  /// Min/max pairs rather than averaged magnitude, because an averaged envelope
  /// renders as a smooth blob that looks nothing like the take.
  Float32List waveformEnvelope(Float32List samples, int bucketCount) {
    _assertUsable();
    final input = calloc<ffi.Float>(samples.length);
    final output = calloc<ffi.Float>(bucketCount * 2);
    try {
      input.asTypedList(samples.length).setAll(0, samples);
      _bindings.res_waveform_envelope(
        input,
        samples.length,
        bucketCount,
        output,
      );
      return Float32List.fromList(output.asTypedList(bucketCount * 2));
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  /// Resets frame-to-frame state. Call between takes so the first frame of a
  /// new recording is not judged against the last frame of the previous one.
  void reset() {
    _bindings.res_plosive_init(_plosiveState);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    calloc.free(_samples);
    calloc.free(_scratch);
    calloc.free(_result);
    calloc.free(_plosiveState);
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('VoiceAnalyser used after dispose()');
    }
  }
}

/// Root-mean-square of a buffer. Allocation-light convenience for one-off use;
/// prefer [VoiceAnalyser.analyse] in the hot path.
double rms(Float32List samples) {
  final buffer = calloc<ffi.Float>(samples.length);
  try {
    buffer.asTypedList(samples.length).setAll(0, samples);
    return _bindings.res_rms(buffer, samples.length);
  } finally {
    calloc.free(buffer);
  }
}

/// Linear amplitude to dBFS, floored at -100.
double toDb(double linear) => _bindings.res_to_db(linear);
