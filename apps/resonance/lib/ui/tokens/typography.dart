import 'package:flutter/widgets.dart';

/// Type scale.
///
/// Two families, split by job rather than by size:
///
/// * **Display/UI** — a grotesque, tight-tracked at large sizes. Carries
///   headings, buttons and anything the user taps.
/// * **Script** — a serif reserved for the one place it matters: the text the
///   user is reading aloud. Scripts are read from a page in this craft, and a
///   serif at generous leading is measurably easier to sight-read than a UI
///   sans. This is the single most functional type decision in the app.
/// * **Data** — monospace with tabular figures for scores, timers, dB and WPM,
///   so digits do not jitter as they update in real time.
///
/// Font files are bundled (see pubspec `fonts:`), not fetched, because the app
/// must render correctly offline on first launch.
class ResType {
  const ResType._();

  static const _display = 'Archivo';
  static const _script = 'Newsreader';
  static const _data = 'JetBrainsMono';

  static const _displayFallback = <String>['.SF Pro Display', 'Roboto'];
  static const _scriptFallback = <String>['Georgia', 'serif'];
  static const _dataFallback = <String>['.SF Mono', 'monospace'];

  // Display / UI ----------------------------------------------------------
  static const hero = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );

  static const title = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 24,
    height: 1.16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const heading = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const bodyStrong = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _displayFallback,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Uppercase eyebrows and section labels. Letter-spaced, never below 11pt.
  static const label = TextStyle(
    fontFamily: _data,
    fontFamilyFallback: _dataFallback,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
  );

  // Script — the read-aloud surface ---------------------------------------
  /// Generous size and leading: the user is glancing between the page and a
  /// mic, and needs to find their place again without hunting.
  static const script = TextStyle(
    fontFamily: _script,
    fontFamilyFallback: _scriptFallback,
    fontSize: 22,
    height: 1.72,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  /// The word currently being spoken, during a shadow or cold read.
  static const scriptActive = TextStyle(
    fontFamily: _script,
    fontFamilyFallback: _scriptFallback,
    fontSize: 22,
    height: 1.72,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Data ------------------------------------------------------------------
  /// Big numerals — scores, countdowns. Tabular so they do not reflow.
  static const metricLarge = TextStyle(
    fontFamily: _data,
    fontFamilyFallback: _dataFallback,
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const metric = TextStyle(
    fontFamily: _data,
    fontFamilyFallback: _dataFallback,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
