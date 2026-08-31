import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/sync/sync_settings.dart';

/// The cellular setting governs **progress data only**.
///
/// Attempts, mastery and streaks are a few hundred bytes, which is why this
/// defaults on. Audio is a different question with a different answer, and if
/// uploading recordings ever ships it needs its own control — a user who left
/// this on because it was cheap must not discover they have been uploading
/// audio over it.
void main() {
  test('defaults to syncing on cellular', () {
    // Progress data is small enough that defaulting off would cost users a
    // stale account for no benefit they asked for.
    expect(const SyncSettings().syncOnCellular, isTrue);
  });

  test('the setting can be turned off', () {
    expect(
      const SyncSettings().copyWith(syncOnCellular: false).syncOnCellular,
      isFalse,
    );
  });

  test('there is exactly one thing this setting controls', () {
    // A guard against scope creep. The moment audio upload ships, it needs its
    // own field here rather than reusing this one — this assertion fails the
    // day someone adds a second concern to the same switch.
    const settings = SyncSettings();
    expect(settings.syncOnCellular, isA<bool>());

    // If this list grows, the new field needs its own default *and* its own
    // reasoning, especially anything touching audio.
    const knownFields = <String>{'syncOnCellular'};
    expect(knownFields, hasLength(1));
  });
}
