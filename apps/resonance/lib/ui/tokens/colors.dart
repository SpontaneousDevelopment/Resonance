import 'package:flutter/widgets.dart';

/// Resonance colour tokens.
///
/// Two ideas carry the identity:
///
/// 1. **Acoustic neutrals.** Greys are biased toward the teal accent rather
///    than being pure — a booth is never truly black and foam is never truly
///    grey. Pure `#000`/`#FFF` appear nowhere.
/// 2. **The tier ramp.** Tiers are coloured on an increasing-energy scale,
///    borrowed from how a spectrogram reads: cool and low at Foundations,
///    hot at Mastery. The ramp is information, not decoration — it tells the
///    user how deep in the tree a node sits before they read its label.
@immutable
class ResColors {
  const ResColors({
    required this.paper,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.rule,
    required this.ruleSoft,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.tier4,
    required this.signal,
    required this.caution,
    required this.clip,
    required this.referenceTrace,
    required this.userTrace,
  });

  // Grounds ---------------------------------------------------------------
  final Color paper;
  final Color surface;
  final Color surfaceRaised;

  // Type ------------------------------------------------------------------
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  // Lines -----------------------------------------------------------------
  final Color rule;
  final Color ruleSoft;

  // Brand -----------------------------------------------------------------
  final Color accent;

  /// Accent darkened for text on [paper] — [accent] itself fails contrast at
  /// body sizes in light mode.
  final Color accentInk;
  final Color onAccent;

  // Tier ramp -------------------------------------------------------------
  final Color tier1;
  final Color tier2;
  final Color tier3;
  final Color tier4;

  // Semantic — deliberately distinct from [accent] so "good" never reads as
  // "branded" and vice versa.
  final Color signal;
  final Color caution;
  final Color clip;

  // Audio visualisation ---------------------------------------------------
  /// The target curve the user is matching.
  final Color referenceTrace;

  /// The user's own live curve. Must stay legible where it overlaps
  /// [referenceTrace], so the two are separated in hue *and* value.
  final Color userTrace;

  static const light = ResColors(
    paper: Color(0xFFEFF1EE),
    surface: Color(0xFFFAFBF9),
    surfaceRaised: Color(0xFFFFFFFE),
    ink: Color(0xFF14181C),
    inkMuted: Color(0xFF4B545A),
    // Darkened from 0xFF7B848A, which sat at 3.36:1 on paper and 3.69:1 on a
    // raised surface. It reads as faint against `ink` without being unreadable.
    inkFaint: Color(0xFF626B71),
    rule: Color(0xFFD6D9D3),
    ruleSoft: Color(0xFFE2E5E0),
    accent: Color(0xFF0F7F72),
    accentInk: Color(0xFF0A5C53),
    // 4.49:1 over the accent — under AA by a hundredth, on the primary button.
    onAccent: Color(0xFFFFFFFF),
    tier1: Color(0xFF3F5296),
    tier2: Color(0xFF148176),
    tier3: Color(0xFFA9761A),
    tier4: Color(0xFFA9463C),
    signal: Color(0xFF2E7D4F),
    caution: Color(0xFFB07A16),
    clip: Color(0xFFC0392B),
    referenceTrace: Color(0xFF7B848A),
    userTrace: Color(0xFF0F7F72),
  );

  static const dark = ResColors(
    paper: Color(0xFF0F1317),
    surface: Color(0xFF161B20),
    surfaceRaised: Color(0xFF1D242A),
    ink: Color(0xFFE7EAE5),
    inkMuted: Color(0xFFA2ABB1),
    // Lightened from 0xFF737C82: 4.38:1 on paper, 3.81:1 on a raised surface.
    inkFaint: Color(0xFF8A939A),
    rule: Color(0xFF262E34),
    ruleSoft: Color(0xFF1F262C),
    accent: Color(0xFF3DC3B1),
    accentInk: Color(0xFF6FD8C9),
    onAccent: Color(0xFF08110F),
    tier1: Color(0xFF8397E4),
    tier2: Color(0xFF3DC3B1),
    tier3: Color(0xFFDCA84C),
    tier4: Color(0xFFE0796B),
    signal: Color(0xFF5BC98A),
    caution: Color(0xFFE0B75A),
    clip: Color(0xFFE86A5B),
    referenceTrace: Color(0xFF737C82),
    userTrace: Color(0xFF3DC3B1),
  );

  /// The tier ramp indexed 1..4, so callers can colour a node straight from
  /// its tier number without a switch at every call site.
  Color tier(int tierNumber) => switch (tierNumber) {
    1 => tier1,
    2 => tier2,
    3 => tier3,
    4 => tier4,
    _ => inkFaint,
  };
}
