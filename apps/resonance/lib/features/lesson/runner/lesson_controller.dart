import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

import '../../../core/audio/recording_session.dart';
import '../../../core/net/coach_note_client.dart';
import '../../../core/progress/progress_repository.dart';
import '../../../core/sensory/sensory_director.dart';
import '../../../core/sfx/sound_palette.dart';
import '../../../core/scoring/attempt_scorer.dart';
import '../../../domain/scoring/sanity_gate.dart';
import '../../../domain/scoring/take_aggregation.dart';
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
    required this.progress,
    required this.sensory,
    this.onAttemptRecorded,
  }) : _injectedSession = session;

  /// Called once an attempt is safely on disk.
  ///
  /// The controller deliberately knows nothing about syncing — it hands over a
  /// fact ("an attempt was recorded") and the caller decides what that is worth.
  /// Nothing here waits on it, so a slow or failing network cannot delay the
  /// score the user is waiting to see.
  final VoidCallback? onAttemptRecorded;

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

  LessonPhase _phase = LessonPhase.ready;
  LessonPhase get phase => _phase;

  RoomCheck? _room;
  RoomCheck? get room => _room;

  FrameAnalysis _latestFrame = const FrameAnalysis.silent();
  FrameAnalysis get latestFrame => _latestFrame;

  /// Persisted progress. Read on [load], written by [stopAndScore].
  final ProgressRepository progress;

  /// Haptics and sound. Owns the duck that keeps UI cues out of the recording.
  final SensoryDirector sensory;

  /// The duck held for the current capture, if any.
  ///
  /// One field, released from every exit — start failure, stop, cancel, reset
  /// and dispose. Bare duck/unduck pairs leaked whenever an exit skipped the
  /// second half, and the palette outlives the lesson, so the leak was
  /// permanent.
  DuckHandle? _captureDuck;

  void _releaseCaptureDuck() {
    _captureDuck?.release();
    _captureDuck = null;
  }

  Mastery _mastery = const Mastery.fresh();
  Mastery get mastery => _mastery;

  /// Everything the last attempt changed — promotion, streak, XP, energy.
  SessionOutcome? _outcome;
  SessionOutcome? get outcome => _outcome;

  AttemptScore? _score;
  AttemptScore? get score => _score;

  /// Takes banked so far this attempt, with the score each earned.
  final List<ScoredTake> _scoredTakes = [];
  final List<RecordedTake> _recordedTakes = [];

  /// The take just recorded, scored but not yet banked.
  ///
  /// It sits here between the sanity gate judging it and the user either
  /// accepting the pass or choosing to continue past three failures — because
  /// a take the gate refused must not end up in the attempt unless the user
  /// says so.
  ({ScoredTake scored, RecordedTake recorded})? _pending;

  SanityVerdict? _lastVerdict;
  SanityVerdict? get lastVerdict => _lastVerdict;

  /// The composite, once every take is in. Null until then.
  AggregateScore? _aggregate;
  AggregateScore? get aggregate => _aggregate;

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

  /// Reads persisted state for this lesson. Call once, when the screen opens.
  Future<void> load() async {
    _mastery = await progress.masteryFor(lesson.id);
    notifyListeners();
  }

  Future<void> checkRoom() async {
    _setPhase(LessonPhase.checkingRoom);

    if (!await _session.hasPermission()) {
      _error = 'Resonance needs microphone access to hear your read.';
      _setPhase(LessonPhase.failed);
      return;
    }

    final duck = sensory.sounds.duckForCapture();
    try {
      _room = await _session.checkRoom();
    } finally {
      duck.release();
    }

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

    // The start cue plays *before* the bus is ducked. Ducking exists to keep
    // sound out of the microphone, and the microphone is not open yet — playing
    // it after the duck meant the cue announcing that recording had begun could
    // never be heard.
    await sensory.play(sensory.choreography.forRecordingStart());

    _releaseCaptureDuck();
    _captureDuck = sensory.sounds.duckForCapture();
    try {
      await _session.start(path: path);
    } catch (_) {
      // Permission revoked, device busy, another app holding the mic. The duck
      // must not outlive the take that failed to begin.
      _releaseCaptureDuck();
      rethrow;
    }
    _setPhase(LessonPhase.recording);
  }

  /// Stops recording, scores the take, and asks the sanity gate about it.
  ///
  /// Deliberately does **not** commit. A take the gate refused is held aside
  /// until the user either re-records it or chooses to continue past three
  /// failures — committing here would put a non-attempt into the attempt and
  /// then have to take it back out.
  Future<SanityVerdict> stopAndJudge({
    required int takeIndex,
    required LessonTake lessonTake,
  }) async {
    _setPhase(LessonPhase.scoring);

    final take = await _session.stop();
    _releaseCaptureDuck();
    await sensory.play(sensory.choreography.forRecordingStop());

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
      plosiveScores: take.plosiveScores,
      lessonTake: lessonTake,
    );

    // The gate reads the same measurements the rubric just used. One
    // measurement pipeline, so there is one thing to calibrate.
    final verdict = const SanityGate().check(score.measurements);

    _pending = (
      scored: ScoredTake(
        index: takeIndex,
        label: lessonTake.label,
        score: score,
      ),
      recorded: RecordedTake(
        index: takeIndex,
        label: lessonTake.label,
        durationMs: (take.durationSeconds * 1000).round(),
        score: score.composite,
        wordsPerMinute: score.measurements.wordsPerMinute.round(),
        transcript: transcript.text.isEmpty ? null : transcript.text,
        audioPath: take.path,
      ),
    );
    _lastVerdict = verdict;
    _score = score;
    _setPhase(LessonPhase.roomChecked);
    return verdict;
  }

  /// Accepts the pending take into the attempt.
  ///
  /// [passedSanity] records whether the gate approved it or gave up on it. The
  /// rubric's score is unchanged either way — the gate was only ever there to
  /// catch a non-attempt, and a weak take is the rubric's to judge.
  void bankTake({required bool passedSanity}) {
    final pending = _pending;
    if (pending == null) return;
    _scoredTakes.add(pending.scored);
    _recordedTakes.add(
      RecordedTake(
        index: pending.recorded.index,
        label: pending.recorded.label,
        durationMs: pending.recorded.durationMs,
        score: pending.recorded.score,
        wordsPerMinute: pending.recorded.wordsPerMinute,
        transcript: pending.recorded.transcript,
        audioPath: pending.recorded.audioPath,
        passedSanity: passedSanity,
      ),
    );
    _pending = null;
    notifyListeners();
  }

  /// Every take is in. Aggregate and commit, once, atomically.
  Future<void> commitAttempt({DateTime? now}) async {
    _setPhase(LessonPhase.scoring);

    final aggregate = aggregatorFor(
      lesson.takeAggregation,
    ).combine(_scoredTakes);
    _aggregate = aggregate;

    final at = now ?? DateTime.now();
    final attemptId = '${lesson.id}-${at.microsecondsSinceEpoch}';

    final outcome = await progress.recordAttempt(
      lesson: lesson,
      // The lesson is graded on the aggregate, not on the last take recorded.
      score: aggregate.decidedBy.score,
      attemptId: attemptId,
      durationMs: _recordedTakes.fold(0, (sum, t) => sum + t.durationMs),
      transcript: _recordedTakes
          .map((t) => t.transcript)
          .whereType<String>()
          .join('\n'),
      audioPath: _recordedTakes.first.audioPath,
      now: at,
      takes: _recordedTakes,
    );

    onAttemptRecorded?.call();

    _score = aggregate.decidedBy.score;
    _outcome = outcome;
    _mastery = await progress.masteryFor(lesson.id);
    _promotion = outcome.promotion;
    _setPhase(LessonPhase.scored);

    unawaited(
      _fetchCoachNote(
        aggregate.decidedBy.score,
        _recordedTakes.map((t) => t.transcript ?? '').join(' '),
      ),
    );
  }

  Future<void> stopAndScore({DateTime? now}) async {
    _setPhase(LessonPhase.scoring);

    final take = await _session.stop();
    // Released before the stop cue, which would otherwise be swallowed by the
    // duck it is announcing the end of.
    _releaseCaptureDuck();
    await sensory.play(sensory.choreography.forRecordingStop());

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
      // Comes from the take rather than a field the controller maintained but
      // never filled — which silently scored every attempt as pop-free.
      plosiveScores: take.plosiveScores,
    );

    final at = now ?? DateTime.now();
    final outcome = await progress.recordAttempt(
      lesson: lesson,
      score: score,
      attemptId: '${lesson.id}-${at.microsecondsSinceEpoch}',
      durationMs: (take.durationSeconds * 1000).round(),
      transcript: transcript.text.isEmpty ? null : transcript.text,
      audioPath: take.path,
      now: at,
    );

    onAttemptRecorded?.call();

    final promotion = outcome.promotion;

    _score = score;
    _outcome = outcome;
    _mastery = await progress.masteryFor(lesson.id);
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
    // "Again" can be pressed from a take that never reached stopAndScore.
    _releaseCaptureDuck();
    _frames.clear();
    _score = null;
    _promotion = null;
    _coachNote = null;
    _coachNotePending = false;
    _error = null;
    _latestFrame = const FrameAnalysis.silent();
    _setPhase(_room == null ? LessonPhase.ready : LessonPhase.roomChecked);
  }

  Future<void> cancel() async {
    _releaseCaptureDuck();
    await recogniser.cancel();
    // Only tear down a session that was actually opened. Touching the getter
    // would construct the whole mic and DSP stack purely in order to cancel
    // something that never started — the same guard `dispose` already uses.
    await _lazySession?.cancel();
    _setPhase(LessonPhase.ready);
  }

  void _setPhase(LessonPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    // Backing out mid-take. Without this the bus stays muted for the rest of
    // the app's life, presenting as "the sounds stopped working" long after.
    _releaseCaptureDuck();
    _analysisSubscription?.cancel();
    recogniser.dispose();
    // Only tear down a session that was actually created — touching the getter
    // here would construct one purely in order to dispose it.
    _lazySession?.dispose();
    super.dispose();
  }
}
