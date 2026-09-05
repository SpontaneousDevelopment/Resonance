import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/curriculum/curriculum.dart';
import 'package:resonance/domain/lesson/take_loop.dart';
import 'package:resonance/domain/scoring/sanity_gate.dart';

/// The take loop's sequencing, including every path that is awkward to reach
/// through the UI: a retry, a third failure, the last take, and the fact that
/// the failure allowance is per take rather than per lesson.
void main() {
  const ladder = TakeLoop(
    takes: [
      LessonTake(label: 'Slow'),
      LessonTake(label: 'Conversational'),
      LessonTake(label: 'Fast'),
    ],
  );
  const single = TakeLoop(takes: [LessonTake(label: 'The take')]);

  const pass = SanityVerdict.pass();
  const fail = SanityVerdict.fail(SanityFailure.didNotMatchScript);

  /// Walks from the start to the record screen of the current take.
  TakeLoopState atRecording(TakeLoop loop) =>
      loop.takeIntroRead(loop.briefRead(const TakeLoopState.start()));

  group('the happy path', () {
    test('brief, then a card per take, then recording', () {
      var s = const TakeLoopState.start();
      expect(s.stage, TakeLoopStage.exerciseIntro);

      s = ladder.briefRead(s);
      expect(s.stage, TakeLoopStage.takeIntro);
      expect(s.takeNumber, 1);

      s = ladder.takeIntroRead(s);
      expect(s.stage, TakeLoopStage.recording);
    });

    test('a passing take celebrates before it moves on', () {
      final s = ladder.judged(atRecording(ladder), pass);
      expect(
        s.stage,
        TakeLoopStage.passed,
        reason: 'a pass should be its own moment, not an immediate advance',
      );
      expect(
        s.recorded,
        isEmpty,
        reason: 'nothing is banked until it moves on',
      );
    });

    test('banking moves to the next take, not straight to recording', () {
      var s = ladder.judged(atRecording(ladder), pass);
      s = ladder.bank(s, passedSanity: true);

      expect(s.stage, TakeLoopStage.takeIntro);
      expect(s.takeNumber, 2);
      expect(s.recorded.single.label, 'Slow');
    });

    test('the last take completes rather than looping', () {
      var s = atRecording(ladder);
      for (var i = 0; i < 3; i++) {
        s = ladder.bank(ladder.judged(s, pass), passedSanity: true);
        if (i < 2) s = ladder.takeIntroRead(s);
      }

      expect(s.stage, TakeLoopStage.complete);
      expect(s.isComplete, isTrue);
      expect(s.recorded.map((t) => t.label), [
        'Slow',
        'Conversational',
        'Fast',
      ]);
    });

    test('a single-take lesson is the same path', () {
      var s = atRecording(single);
      s = single.bank(single.judged(s, pass), passedSanity: true);

      expect(s.stage, TakeLoopStage.complete);
      expect(s.recorded, hasLength(1));
    });
  });

  group('failing a take', () {
    test('the first failure offers a re-record, not a way past', () {
      final s = ladder.judged(atRecording(ladder), fail);

      expect(s.stage, TakeLoopStage.failed);
      expect(s.consecutiveFailures, 1);
      expect(s.lastFailure, SanityFailure.didNotMatchScript);
      expect(s.recorded, isEmpty);
    });

    test('retrying returns to the same take without re-showing its card', () {
      var s = ladder.judged(atRecording(ladder), fail);
      s = ladder.retry(s);

      expect(
        s.stage,
        TakeLoopStage.recording,
        reason: 'a retry must not send the user back through the intro card',
      );
      expect(s.takeNumber, 1);
      expect(s.consecutiveFailures, 1, reason: 'the count survives the retry');
    });

    test('a pass after a failure clears the count', () {
      var s = ladder.retry(ladder.judged(atRecording(ladder), fail));
      s = ladder.judged(s, pass);

      expect(s.stage, TakeLoopStage.passed);
      expect(s.consecutiveFailures, 0);
    });
  });

  group('the third failure', () {
    TakeLoopState failTimes(int n) {
      var s = atRecording(ladder);
      for (var i = 0; i < n; i++) {
        s = ladder.judged(s, fail);
        if (i < n - 1) s = ladder.retry(s);
      }
      return s;
    }

    test('two failures still only offer a retry', () {
      expect(failTimes(2).stage, TakeLoopStage.failed);
    });

    test('the third offers a way past', () {
      final s = failTimes(3);
      expect(s.stage, TakeLoopStage.exhausted);
      expect(s.consecutiveFailures, 3);
    });

    test('it offers rather than proceeds', () {
      final s = failTimes(3);
      expect(
        s.recorded,
        isEmpty,
        reason: 'nothing is banked until the user taps Continue',
      );
      expect(s.isComplete, isFalse);
    });

    test('continuing banks the take and marks the gate as having given up', () {
      var s = failTimes(3);
      s = ladder.bank(s, passedSanity: false);

      expect(s.recorded.single.passedSanity, isFalse);
      expect(s.takeNumber, 2, reason: 'it moves on with what was recorded');
      expect(s.stage, TakeLoopStage.takeIntro);
    });

    test('the allowance is per take, not per lesson', () {
      // Three failures on take one, then take two starts clean. Otherwise a
      // user who struggled once is one bad take from being waved through the
      // rest of the lesson.
      var s = failTimes(3);
      s = ladder.bank(s, passedSanity: false);
      expect(s.consecutiveFailures, 0);

      s = ladder.judged(ladder.takeIntroRead(s), fail);
      expect(
        s.stage,
        TakeLoopStage.failed,
        reason: 'take two should get its own three attempts',
      );
      expect(s.consecutiveFailures, 1);
    });

    test('a third failure on the last take still completes', () {
      var s = atRecording(ladder);
      for (var i = 0; i < 2; i++) {
        s = ladder.takeIntroRead(
          ladder.bank(ladder.judged(s, pass), passedSanity: true),
        );
      }
      for (var i = 0; i < 3; i++) {
        s = ladder.judged(s, fail);
        if (i < 2) s = ladder.retry(s);
      }
      expect(s.stage, TakeLoopStage.exhausted);

      s = ladder.bank(s, passedSanity: false);
      expect(s.stage, TakeLoopStage.complete);
      expect(s.recorded, hasLength(3));
      expect(s.recorded.last.passedSanity, isFalse);
    });
  });

  group('the threshold is the one the gate publishes', () {
    test('three, from SanityThresholds', () {
      // If these drift apart, the UI offers a way past at a different point
      // from the one the gate documents.
      expect(SanityThresholds.failuresBeforeContinue, 3);
    });
  });
}
