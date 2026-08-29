import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

import '../../../core/audio/recording_session.dart';
import '../../../core/net/coach_note_client.dart';
import '../../../core/scoring/attempt_scorer.dart';
import '../../../core/speech/speech_recogniser.dart';
import '../../../domain/curriculum/curriculum.dart';
import '../../../domain/curriculum/mastery.dart';
import '../../../domain/scoring/rubric.dart';

/// Where a lesson attempt is in its life.
enum LessonPhase {
  /// Before anything — the room has not been checked.
  ready,
  checkingRoom,
  roomChecked,
  recording,

  /// Take finished, scoring in flight. Brief — everything is on-device.
  scoring,

  /// Score is on screen. The coach note may still be arriving.
  scored,
  failed,
}

/// Drives one attempt from room check to score.
///
/// The ordering here is the product: the score is computed entirely on-device
/// and rendered immediately, and only then is the coach note requested. A user
/// on a train sees their full breakdown at the same speed as a user on wifi —
/// the only difference is whether a note appears underneath a moment later.
class LessonController extends ChangeNotifier {
  LessonController({
    required this.lesson,
    required this.recogniser,
    RecordingSession? session,
    this.scorer = const AttemptScorer(),
    this.coachNotes = const NullCoachNoteClient(),
    Mastery mastery = const Mastery.fresh(),
  }) : // `_mastery` is mutable state behind a read-only getter, and a named
       // parameter cannot be written `this._mastery` — Dart forbids named
       // parameters beginning with an underscore.
       // ignore: prefer_initializing_formals
       _mastery = mastery,
       _injectedSession = session;

  final Lesson lesson;
  final SpeechRecogniser recogniser;
  final RecordingSession? _injectedSession;

  /// Created on first use rather than in the constructor.
  ///
  /// Constructing a [RecordingSession] opens the platform recorder, which needs
  /// a Flutter binding — doing it eagerly would mean the controller could not
  /// be built at all without the mic stack, and there is no reason to hold the
  /// microphone before the user has asked for anything.
  RecordingSession? _lazySession;
  RecordingSession get _session {
    final existing = _lazySession ??= _injectedSession ?? RecordingSession();
    _analysisSubscription ??= existing.analysis.listen(_onFrame);
    return existing;
  }

  final CoachNoteClient coachNotes;
  final AttemptScorer scorer;

  StreamSubscription<FrameAnalysis>? _analysisSubscription;

  final List<FrameAnalysis> _frames = [];
  final List<double> _plosiveScores = [];

  LessonPhase _phase = LessonPhase.ready;
  LessonPhase get phase => _phase;

  RoomCheck? _room;
  RoomCheck? get room => _room;

  FrameAnalysis _latestFrame = const FrameAnalysis.silent();
  FrameAnalysis get latestFrame => _latestFrame;

  Mastery _mastery;
  Mastery get mastery => _mastery;

  AttemptScore? _score;
  AttemptScore? get score => _score;

  PromotionResult? _promotion;
  PromotionResult? get promotion => _promotion;

  String? _coachNote;
  String? get coachNote => _coachNote;

  bool _coachNotePending = false;
  bool get coachNotePending => _coachNotePending;

  String? _error;
  String? get error => _error;

  /// True when clarity could not be measured — no recogniser, no permission, or
  /// offline on a device that needs the network for it. The attempt still
  /// scores on pace and mic technique, and the UI says so rather than
  /// pretending the number means the same thing.
  bool _clarityUnavailable = false;
  bool get clarityUnavailable => _clarityUnavailable;

  Stream<FrameAnalysis> get analysis => _session.analysis;
  double get elapsedSeconds => _session.elapsedSeconds;

  void _onFrame(FrameAnalysis frame) {
    _frames.add(frame);
    _latestFrame = frame;
    notifyListeners();
  }

  Future<void> checkRoom() async {
    _setPhase(LessonPhase.checkingRoom);

    if (!await _session.hasPermission()) {
      _error = 'Resonance needs microphone access to hear your read.';
      _setPhase(LessonPhase.failed);
      return;
    }

    _room = await _session.checkRoom();

    // Probe speech recognition here rather than at the moment of recording.
    //
    // Two reasons. The permission dialog belongs before the user has committed
    // to a take — the same principle the room check itself exists for. And on
    // Apple platforms the first call into SFSpeechRecognizer is what triggers
    // the TCC check; if the usage description is ever missing again the app is
    // terminated outright, and having that happen during a two-second room
    // check is far less costly than losing a performance the user has just
    // given.
    _clarityUnavailable = !await _probeSpeech();

    _setPhase(LessonPhase.roomChecked);
  }

  /// Returns whether clarity scoring will be available for this attempt.
  Future<bool> _probeSpeech() async {
    try {
      return await recogniser.isAvailable();
    } on SpeechUnavailable catch (e) {
      debugPrint('Speech recognition unavailable: $e');
      return false;
    } catch (e) {
      debugPrint('Speech recognition probe failed: $e');
      return false;
    }
  }

  Future<void> startRecording() async {
    _frames.clear();
    _plosiveScores.clear();
    _score = null;
    _promotion = null;
    _coachNote = null;
    _error = null;

    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    final path =
        '${directory.path}/${lesson.id}_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Availability was established during the room check. Starting is still
    // guarded: the recogniser can be available and then fail to start, most
    // plausibly because the recorder has already claimed the microphone. The
    // take proceeds either way and scores on everything that needs no
    // transcript.
    if (!_clarityUnavailable) {
      try {
        await recogniser.start(contextHint: lesson.script);
      } catch (e) {
        _clarityUnavailable = true;
        debugPrint('Speech recognition could not start: $e');
      }
    }

    await _session.start(path: path);
    _setPhase(LessonPhase.recording);
  }

  Future<void> stopAndScore({DateTime? now}) async {
    _setPhase(LessonPhase.scoring);

    final take = await _session.stop();

    Transcript transcript = const Transcript.empty();
    if (!_clarityUnavailable) {
      try {
        transcript = await recogniser.stop();
      } catch (e) {
        _clarityUnavailable = true;
        debugPrint('Transcript unavailable: $e');
      }
    }

    final score = scorer.score(
      lesson: lesson,
      take: take,
      transcript: transcript,
      frameAnalyses: _frames,
      plosiveScores: _plosiveScores,
    );

    final (updatedMastery, promotion) = _mastery.applyAttempt(
      score: score.composite,
      at: now ?? DateTime.now(),
    );

    _score = score;
    _mastery = updatedMastery;
    _promotion = promotion;
    _setPhase(LessonPhase.scored);

    // Only now, with the score already on screen.
    unawaited(_fetchCoachNote(score, transcript.text));
  }

  Future<void> _fetchCoachNote(AttemptScore score, String transcript) async {
    _coachNotePending = true;
    notifyListeners();

    final note = await coachNotes.fetch(
      lesson: lesson,
      score: score,
      transcript: transcript,
    );

    _coachNote = note;
    _coachNotePending = false;
    notifyListeners();
  }

  /// Clears the last attempt and returns to the pre-record state, keeping the
  /// room check. Backs the "Again" button on the feedback screen — re-checking
  /// the room between takes would be pointless ceremony.
  void reset() {
    _frames.clear();
    _plosiveScores.clear();
    _score = null;
    _promotion = null;
    _coachNote = null;
    _coachNotePending = false;
    _error = null;
    _latestFrame = const FrameAnalysis.silent();
    _setPhase(_room == null ? LessonPhase.ready : LessonPhase.roomChecked);
  }

  Future<void> cancel() async {
    await recogniser.cancel();
    await _session.cancel();
    _setPhase(LessonPhase.ready);
  }

  void _setPhase(LessonPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    recogniser.dispose();
    // Only tear down a session that was actually created — touching the getter
    // here would construct one purely in order to dispose it.
    _lazySession?.dispose();
    super.dispose();
  }
}
