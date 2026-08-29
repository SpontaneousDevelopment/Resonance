import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/audio/recording_session.dart';

/// The thresholds here are product decisions, not implementation details — they
/// decide whether a user is told their room is fine, workable, or unusable. A
/// change to any of them should be deliberate enough to break a test.
void main() {
  group('room verdicts', () {
    test('a treated room passes silently', () {
      final room = RoomCheck.from(-68);

      expect(room.isAcceptable, isTrue);
      // No advice: saying "your room is great!" every single session is noise.
      expect(room.advice, isNull);
    });

    test('a live room passes with a caveat', () {
      final room = RoomCheck.from(-52);

      expect(room.isAcceptable, isTrue);
      expect(room.advice, isNotNull);
      expect(room.advice, contains('little live'));
    });

    test('a noisy room is refused with something actionable', () {
      final room = RoomCheck.from(-30);

      expect(room.isAcceptable, isFalse);
      expect(room.advice, isNotNull);
      // The advice has to name a thing the user can do, not just report a
      // number at them.
      expect(
        room.advice!.toLowerCase(),
        anyOf(contains('window'), contains('fan'), contains('somewhere')),
      );
    });

    test('boundaries fall on the documented side', () {
      expect(RoomCheck.from(RoomCheck.goodFloorDb).advice, isNull);
      expect(RoomCheck.from(RoomCheck.goodFloorDb + 0.1).advice, isNotNull);

      expect(RoomCheck.from(RoomCheck.acceptableFloorDb).isAcceptable, isTrue);
      expect(
        RoomCheck.from(RoomCheck.acceptableFloorDb + 0.1).isAcceptable,
        isFalse,
      );
    });

    test('silence reads as an excellent room, not a broken mic', () {
      // A -100 dB floor means the check heard nothing at all. That is either a
      // superb booth or a dead microphone; the recorder distinguishes them by
      // whether any frames arrived, so the verdict itself stays optimistic.
      expect(RoomCheck.from(-100).isAcceptable, isTrue);
    });
  });
}
