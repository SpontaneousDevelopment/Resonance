/// Did a take contain a real attempt at the script?
///
/// **Not a quality gate.** This exists to catch the accidental non-attempt —
/// a mis-tap, a cough, a phone knocked off a table, a recording of the room
/// while someone answered the door, or a read of something else entirely.
/// A genuinely poor take is not this gate's problem: it is the rubric's, and
/// the rubric's job is to score it honestly rather than to refuse it.
///
/// That asymmetry sets every threshold below. Being too lenient costs a
/// low-but-real score the user can see and retry. Being too strict tells
/// someone who did read the passage that they did not, which is the worst
/// thing this screen can do.
///
/// It reuses the measurements the real rubric already produces — alignment and
/// words per minute — rather than adding a second, lighter analyser. One
/// measurement pipeline means one thing to calibrate and one thing to trust.
library;

import 'rubric.dart';

/// The gate's numbers, in one place because they will need tuning.
///
/// **Uncalibrated.** These are reasoned from the shape of the failure, not
/// validated against a corpus of real non-attempts — the same status the rubric
/// weights carry. The plosive detector is the standing warning here: it passed
/// three sine-tone tests and shipped reporting 284 pops a minute on speech.
/// Anything that matters should be checked against real recordings before it is
/// trusted, and this has not been.
class SanityThresholds {
  const SanityThresholds._();

  /// Proportion of the script's words the recogniser had to match.
  ///
  /// 0.35 — far below Bronze, which needs a 60 composite. A mumbled, halting,
  /// half-remembered read of the right passage clears this comfortably; a read
  /// of a different passage does not.
  static const minAccuracy = 0.35;

  /// Words the recogniser must have heard at all.
  ///
  /// Four. The shortest authored script is sixteen words, so this is a quarter
  /// of the smallest real target — enough that a cough, a throat-clear or a
  /// single "um" cannot pass, and low enough that nothing genuine trips it.
  static const minSpokenWords = 4;

  /// Outside this, it is not someone reading aloud.
  ///
  /// 40 is slower than any deliberate read; 320 is faster than anyone
  /// articulates. Deliberately far outside the widest authored band (95–215),
  /// because this asks "was this speech" and not "was this good speech".
  static const wpmFloor = 40.0;
  static const wpmCeiling = 320.0;

  /// Below this the recording is a mis-tap rather than a take.
  static const minDurationSeconds = 1.5;

  /// Consecutive failures on one take before the user is offered a way past.
  ///
  /// Three. At that point the gate has been wrong twice or the user genuinely
  /// cannot satisfy it, and either way blocking further is the app arguing with
  /// someone about whether they spoke.
  static const failuresBeforeContinue = 3;
}

/// Why a take did not look like an attempt. Surfaced, so the user is told
/// something more useful than "try again".
enum SanityFailure {
  /// Barely any recording.
  tooShort,

  /// Almost nothing was heard.
  tooFewWords,

  /// Speech, but not at a rate a person reads at.
  implausiblePace,

  /// Words were heard, but they were not this script.
  didNotMatchScript,
}

class SanityVerdict {
  const SanityVerdict.pass() : failure = null;
  const SanityVerdict.fail(this.failure);

  /// Null when the take passed.
  final SanityFailure? failure;

  bool get passed => failure == null;

  /// What to tell the user. Deliberately never implies they read it badly —
  /// this gate cannot tell, and saying so would be a judgement it has not made.
  String get message => switch (failure) {
    null => 'Got it.',
    SanityFailure.tooShort =>
      'That was too short to score — hold Record until '
          'you have finished the line.',
    SanityFailure.tooFewWords =>
      'We could not hear much. Check the microphone and try again.',
    SanityFailure.implausiblePace =>
      'That did not come through as a read of the line. Try again.',
    SanityFailure.didNotMatchScript =>
      'That did not match the script closely enough to score. Try again.',
  };
}

/// Checks a take against [SanityThresholds].
class SanityGate {
  const SanityGate();

  SanityVerdict check(AttemptMeasurements m) {
    if (m.durationSeconds < SanityThresholds.minDurationSeconds) {
      return const SanityVerdict.fail(SanityFailure.tooShort);
    }

    final spoken =
        m.alignment.matches +
        m.alignment.substitutions +
        m.alignment.insertions;
    if (spoken < SanityThresholds.minSpokenWords) {
      return const SanityVerdict.fail(SanityFailure.tooFewWords);
    }

    final wpm = m.wordsPerMinute;
    if (wpm < SanityThresholds.wpmFloor || wpm > SanityThresholds.wpmCeiling) {
      return const SanityVerdict.fail(SanityFailure.implausiblePace);
    }

    // Last, because it is the check most likely to be wrong about a real
    // attempt: a heavy accent or a noisy room lowers accuracy without meaning
    // the user read something else.
    if (m.alignment.accuracy < SanityThresholds.minAccuracy) {
      return const SanityVerdict.fail(SanityFailure.didNotMatchScript);
    }

    return const SanityVerdict.pass();
  }
}
