import 'package:flutter/widgets.dart';

/// Motion tokens.
///
/// The rule this app follows: motion either communicates state or it does not
/// ship. A celebration is state ("you levelled"), a page transition is state
/// ("you moved"), a decorative parallax is not.
///
/// Every duration here has a paired reduced-motion behaviour. Call
/// [ResMotion.duration] rather than reading the constants directly so the
/// accessibility setting is honoured in one place.
class ResMotion {
  const ResMotion._();

  /// 90ms — a button acknowledging a press. Below ~80ms reads as instant and
  /// therefore as unresponsive; above ~120ms reads as laggy.
  static const tap = Duration(milliseconds: 90);

  /// 180ms — a control changing state, a chip filling.
  static const control = Duration(milliseconds: 180);

  /// 280ms — a sheet, a route push.
  static const surface = Duration(milliseconds: 280);

  /// 640ms — a mastery ring filling on the feedback screen. Long enough to be
  /// felt as an event, short enough not to delay the user's next tap.
  static const celebrate = Duration(milliseconds: 640);

  /// Standard easing. Slight overshoot on entry, none on exit.
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasise = Curves.easeOutBack;

  /// Resolves a duration against the platform's reduced-motion preference.
  ///
  /// Returns [Duration.zero] when the user has asked for reduced motion, which
  /// makes animated widgets settle instantly rather than being removed — the
  /// end state is identical either way.
  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}
