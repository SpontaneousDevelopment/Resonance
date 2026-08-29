/// Spacing scale — a 4pt grid. Every gap in the app is one of these.
///
/// Named by role rather than size so a rename of the underlying value does not
/// require touching call sites.
class ResSpace {
  const ResSpace._();

  /// 4 — between an icon and its label.
  static const hair = 4.0;

  /// 8 — within a component.
  static const tight = 8.0;

  /// 12 — between related rows.
  static const snug = 12.0;

  /// 16 — the default. Card padding, list gaps.
  static const base = 16.0;

  /// 24 — between components.
  static const loose = 24.0;

  /// 32 — between sections.
  static const section = 32.0;

  /// 48 — above a screen's primary action.
  static const major = 48.0;

  /// Horizontal page gutter. Wider on desktop, where the window is not the
  /// content's natural width.
  static const gutterCompact = 20.0;
  static const gutterExpanded = 32.0;
}

/// Corner radii. Deliberately restrained — three values, not a continuum.
class ResRadius {
  const ResRadius._();

  /// 6 — chips, small controls.
  static const small = 6.0;

  /// 10 — cards, sheets, the skill-tree nodes.
  static const medium = 10.0;

  /// 20 — the record button and other fully-rounded affordances.
  static const large = 20.0;
}

/// Breakpoints. The app is one layout that adapts, not three layouts.
class ResBreak {
  const ResBreak._();

  /// Below this: phone portrait. Single column, bottom nav.
  static const compact = 600.0;

  /// Below this: tablet / small window. Two columns where it helps.
  static const medium = 900.0;

  /// At or above: macOS window. Persistent side rail, wider gutters.
  static const expanded = 900.0;
}
