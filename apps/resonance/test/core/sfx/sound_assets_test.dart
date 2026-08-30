import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/sfx/sound_palette.dart';
import 'package:resonance/domain/sensory/sensory_cue.dart';

/// The palette's manifest against what is actually on disk.
///
/// A cue whose file is missing fails silently — the palette logs once and
/// carries on, which is right at runtime and useless as a signal. These assert
/// the two agree, for every cue rather than for whichever one was last
/// reported.
void main() {
  test('every SoundCue has a manifest entry', () {
    final missing = SoundCue.values
        .where((cue) => SoundPalette.assets[cue] == null)
        .map((cue) => cue.name);

    expect(missing, isEmpty, reason: 'no asset path declared for: $missing');
  });

  test('every declared asset exists on disk', () {
    final absent = <String>[];
    for (final entry in SoundPalette.assets.entries) {
      if (!File(entry.value).existsSync()) {
        absent.add('${entry.key.name} -> ${entry.value}');
      }
    }

    expect(
      absent,
      isEmpty,
      reason: 'declared but not present, so these fail silently: $absent',
    );
  });

  test('every declared asset is real audio, not an empty placeholder', () {
    // A zero-byte or truncated file passes an existence check and then throws
    // at playback, where the palette swallows it.
    for (final entry in SoundPalette.assets.entries) {
      final file = File(entry.value);
      expect(
        file.lengthSync(),
        greaterThan(1000),
        reason: '${entry.key.name} looks like a placeholder',
      );

      final header = file.readAsBytesSync().sublist(0, 4);
      expect(
        String.fromCharCodes(header),
        'RIFF',
        reason: '${entry.key.name} is not a WAV file',
      );
    }
  });

  test('no asset is shared between two cues', () {
    // Two cues pointing at one file is nearly always a copy-paste slip, and it
    // makes the palette sound broken rather than missing.
    final paths = SoundPalette.assets.values.toList();
    expect(paths.toSet().length, paths.length);
  });
}
