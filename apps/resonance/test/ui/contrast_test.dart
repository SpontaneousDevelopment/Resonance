import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/ui/tokens/colors.dart';

/// WCAG contrast for every text colour the design system actually uses.
///
/// The integration suite runs Flutter's `textContrastGuideline` over rendered
/// screens, which is the real check — but it only sees the combinations that
/// happen to be on screen in the test, and it takes a device run to find out.
/// This asserts the palette itself, in milliseconds, for every pairing the
/// tokens permit. It is what found `inkFaint` sitting at 3.36 against paper in
/// the light theme, on every small label in the app, for five milestones.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  /// WCAG AA for body text. The muted and faint inks are used at 11–13px, so
  /// the 3:1 large-text allowance does not apply to them.
  const aa = 4.5;

  for (final entry in {
    'light': ResColors.light,
    'dark': ResColors.dark,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    final grounds = {
      'paper': c.paper,
      'surface': c.surface,
      'surfaceRaised': c.surfaceRaised,
    };
    final inks = {'ink': c.ink, 'inkMuted': c.inkMuted, 'inkFaint': c.inkFaint};

    group('$name theme', () {
      for (final ground in grounds.entries) {
        for (final ink in inks.entries) {
          test('${ink.key} on ${ground.key} meets AA', () {
            final ratio = contrast(ink.value, ground.value);
            expect(
              ratio,
              greaterThanOrEqualTo(aa),
              reason:
                  '${ink.key} on ${ground.key} is ${ratio.toStringAsFixed(2)}:1, '
                  'below the $aa:1 needed for text this size',
            );
          });
        }
      }

      test('text on the accent colour meets AA', () {
        final ratio = contrast(c.onAccent, c.accent);
        expect(
          ratio,
          greaterThanOrEqualTo(aa),
          reason:
              'onAccent over accent is ${ratio.toStringAsFixed(2)}:1 — this is '
              'the primary button, so it is the worst possible place to fail',
        );
      });
    });
  }
}
