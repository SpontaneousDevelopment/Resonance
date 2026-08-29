import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

import 'frame_buffer.dart';

/// What the recorder is doing right now.
enum RecordingState {
  idle,

  /// Measuring the room before the take. See [RecordingSession.checkRoom].
  checkingRoom,

  recording,

  /// Stopped, holding a finished take.
  finished,
}

/// A verdict on the room, delivered *before* the user performs rather than
/// after.
///
/// Telling someone their take was unusable once they have already given it is
/// the fastest way to make an app feel punitive. This runs in the pre-roll.
class RoomCheck {
  const RoomCheck({
    required this.noiseFloorDb,
    required this.isAcceptable,
    required this.advice,
  });

  final double noiseFloorDb;
  final bool isAcceptable;

  /// One line the user can act on, or null when the room is fine.
  final String? advice;

  /// Studio-grade is below -60 dBFS. Below -45 is workable for practice; above
  /// that, scoring becomes guesswork and we say so instead of pretending.
  static const acceptableFloorDb = -45.0;
  static const goodFloorDb = -60.0;

  factory RoomCheck.from(double floorDb) {
    if (floorDb <= goodFloorDb) {
      return RoomCheck(noiseFloorDb: floorDb, isAcceptable: true, advice: null);
    }
    if (floorDb <= acceptableFloorDb) {
      return RoomCheck(
        noiseFloorDb: floorDb,
        isAcceptable: true,
        advice:
            'Your room is a little live. Scores will be fair, but soft '
            'consonants may be harder to hear.',
      );
    }
    return RoomCheck(
      noiseFloorDb: floorDb,
      isAcceptable: false,
      advice:
          'It is too loud here to score you fairly. Try closing a window, '
          'turning off a fan, or moving somewhere softer.',
    );
  }
}

/// Owns one take: microphone in, analysed frames out.
///
/// Deliberately not a Riverpod notifier — this is plumbing with a lifecycle,
/// and keeping it a plain object means it can be unit-tested with a fake
/// recorder and no container.
class RecordingSession {
  RecordingSession({
    AudioRecorder? recorder,
    this.sampleRate = 48000,
    this.frameSize = 2048,
  }) : _injectedRecorder = recorder,
       _frames = FrameBuffer(frameSize: frameSize),
       _analyser = VoiceAnalyser(sampleRate: sampleRate, frameSize: frameSize);

  final AudioRecorder? _injectedRecorder;

  /// Created on first use, not in the constructor.
  ///
  /// Constructing an [AudioRecorder] opens a platform channel, so building it
  /// eagerly meant that merely *listening* to [analysis] — which the visualiser
  /// does before the user has touched anything — reached for the microphone
  /// stack. In a widget test with no platform behind it, that blocks forever.
  AudioRecorder? _lazyRecorder;
  AudioRecorder get _recorder =>
      _lazyRecorder ??= _injectedRecorder ?? AudioRecorder();
  final int sampleRate;
  final int frameSize;

  final FrameBuffer _frames;
  final VoiceAnalyser _analyser;

  StreamSubscription<Uint8List>? _subscription;

  final _analysisController = StreamController<FrameAnalysis>.broadcast();
  final _stateController = StreamController<RecordingState>.broadcast();

  /// One event per completed frame — roughly 23 Hz at 2048 samples / 48 kHz,
  /// which is comfortably above what the eye reads as continuous motion once
  /// the visualiser interpolates between them.
  Stream<FrameAnalysis> get analysis => _analysisController.stream;
  Stream<RecordingState> get state => _stateController.stream;

  RecordingState _state = RecordingState.idle;
  RecordingState get currentState => _state;

  /// Every frame of the current take, kept for the post-take waveform and for
  /// the score pass.
  final List<Float32List> _takeFrames = [];

  /// Plosive energy per frame of the current take.
  ///
  /// Computed during recording rather than afterwards because the detector is
  /// stateful — it compares each frame's low-band energy against the previous
  /// one, since a plosive is a *sudden* low burst and a sustained low note is
  /// not. Replaying frames later would work, but doing it inline keeps one
  /// source of truth for the frame ordering.
  final List<double> _takePlosiveScores = [];

  /// Seconds of audio captured, measured on the audio clock.
  double get elapsedSeconds => _frames.samplesConsumed / sampleRate;

  double get noiseFloorDb => _analyser.noiseFloorDb;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Listens to the room for [duration] and derives its noise floor.
  ///
  /// Uses the 20th percentile of frame levels rather than the mean: a cough or
  /// a passing car during the check would drag a mean upward and wrongly
  /// condemn a perfectly good room.
  Future<RoomCheck> checkRoom({
    Duration duration = const Duration(seconds: 2),
  }) async {
    _setState(RecordingState.checkingRoom);

    final levels = <double>[];
    final buffer = FrameBuffer(frameSize: frameSize);
    final stream = await _recorder.startStream(_config);

    final completer = Completer<void>();
    final timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });

    final subscription = stream.listen((bytes) {
      for (final frame in buffer.addPcm16(bytes)) {
        levels.add(_analyser.analyse(frame, detectPitch: false).db);
      }
    });

    await completer.future;
    timer.cancel();
    await subscription.cancel();
    await _recorder.stop();

    _setState(RecordingState.idle);

    if (levels.isEmpty) {
      return RoomCheck.from(-100);
    }

    levels.sort();
    final floor = levels[(levels.length * 0.2).floor()];
    _analyser.noiseFloorDb = floor;
    return RoomCheck.from(floor);
  }

  /// Starts a take. [path] is where the encoded audio is written.
  Future<void> start({required String path}) async {
    if (_state == RecordingState.recording) return;

    _frames.reset();
    _analyser.reset();
    _takeFrames.clear();
    _takePlosiveScores.clear();

    final stream = await _recorder.startStream(_config);
    _subscription = stream.listen(
      _onBytes,
      onError: (Object error, StackTrace stack) {
        _analysisController.addError(error, stack);
      },
    );

    _setState(RecordingState.recording);
  }

  void _onBytes(Uint8List bytes) {
    for (final frame in _frames.addPcm16(bytes)) {
      _takeFrames.add(frame);
      _takePlosiveScores.add(_analyser.plosiveScore(frame));
      _analysisController.add(_analyser.analyse(frame));
    }
  }

  /// Stops and returns the take.
  Future<Take> stop() async {
    await _subscription?.cancel();
    _subscription = null;

    // The ragged tail matters: without this the last fraction of a second is
    // silently dropped, and a short take loses a measurable slice of itself.
    final tail = _frames.flush();
    if (tail != null) {
      _takeFrames.add(tail);
      _takePlosiveScores.add(_analyser.plosiveScore(tail));
      _analysisController.add(_analyser.analyse(tail));
    }

    final path = await _recorder.stop();
    _setState(RecordingState.finished);

    return Take(
      path: path,
      sampleRate: sampleRate,
      frames: List.unmodifiable(_takeFrames),
      plosiveScores: List.unmodifiable(_takePlosiveScores),
      durationSeconds: elapsedSeconds,
    );
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.cancel();
    _takeFrames.clear();
    _takePlosiveScores.clear();
    _frames.reset();
    _setState(RecordingState.idle);
  }

  RecordConfig get _config => RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    // Automatic gain control fights the whole point of a mic-technique
    // lesson: it would flatten the very proximity and level differences the
    // user is being taught to control.
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
  );

  void _setState(RecordingState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _analysisController.close();
    await _stateController.close();
    _analyser.dispose();
    // Only tear down a recorder that was actually opened — touching the getter
    // here would construct one purely in order to dispose it.
    await _lazyRecorder?.dispose();
  }
}

/// A finished recording.
class Take {
  const Take({
    required this.path,
    required this.sampleRate,
    required this.frames,
    required this.durationSeconds,
    this.plosiveScores = const [],
  });

  /// Where the encoded file landed, or null if the platform did not write one.
  final String? path;

  final int sampleRate;

  /// Every analysed frame, in order. Feeds the post-take waveform and scoring.
  final List<Float32List> frames;

  /// Plosive energy per frame, aligned with [frames].
  final List<double> plosiveScores;

  final double durationSeconds;

  /// Flattens the take back into one buffer for waveform rendering.
  Float32List get samples {
    final total = frames.fold<int>(0, (sum, f) => sum + f.length);
    final out = Float32List(total);
    var offset = 0;
    for (final frame in frames) {
      out.setRange(offset, offset + frame.length, frame);
      offset += frame.length;
    }
    return out;
  }
}
