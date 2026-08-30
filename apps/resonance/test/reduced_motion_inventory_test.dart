import 'package:flutter_test/flutter_test.dart';

/// An inventory, not a test of behaviour.
///
/// Reduced motion is a cross-cutting concern, and the M4 audit marked it green
/// on the strength of a test covering the sensory director — while the breather
/// had no such test at all. An item named after a *concern* is retired by any
/// one passing test that mentions it.
///
/// This file exists so the gap is visible while reading: every component that
/// animates is listed, with where its reduced-motion behaviour is actually
/// asserted. Adding an animated component without a line here is a review
/// catch, not a mechanical one — there is no enum to make it enforceable, and
/// a CI check flagging "source changed, test didn't" is mostly false positives.
///
/// Coverage does not substitute for this. When the breather's reduced-motion
/// branch was deleted, it took its lines with it: nothing was uncovered, the
/// new code was simply doing less.
void main() {
  test('every animated component has reduced-motion coverage somewhere', () {
    const covered = <String, String>{
      'SensoryDirector (cue pacing)':
          'test/core/sensory/sensory_director_test.dart '
          '— "reaches the same end state with no waiting"',
      'TakeFiveScreen (breath circle)':
          'test/features/take_five_test.dart '
          '— group "reduced motion"',
      'LiveVisualiser (waveform scroll)':
          'test/ui/live_visualiser_test.dart '
          '— "honours reduced motion"',
    };

    // Components that animate but are not yet listed. Add the component *and*
    // its coverage together, or leave it here as an honest open gap.
    const knownGaps = <String>{
      // MasteryRing's fill uses TweenAnimationBuilder on the feedback screen.
      // It is a one-shot on a screen the user is reading, not continuous
      // motion, so it has not been treated as reduced-motion relevant.
      'MasteryRing fill',
    };

    expect(covered, isNotEmpty);
    expect(
      covered.values.every((where) => where.contains('test/')),
      isTrue,
      reason: 'every entry must name where the assertion lives',
    );
    // Recorded deliberately rather than silently omitted.
    expect(knownGaps, hasLength(1));
  });
}
