import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Carries [ResColors] down the tree.
///
/// Colours live in a [ThemeExtension] rather than being squeezed into
/// [ColorScheme] because the palette has concepts Material has no slot for —
/// the tier ramp, the reference/user trace pair, a distinct clip colour. Bending
/// those into `tertiaryContainer` and friends would make every call site a
/// puzzle.
@immutable
class ResColorsExtension extends ThemeExtension<ResColorsExtension> {
  const ResColorsExtension(this.colors);

  final ResColors colors;

  @override
  ResColorsExtension copyWith({ResColors? colors}) =>
      ResColorsExtension(colors ?? this.colors);

  @override
  ResColorsExtension lerp(ThemeExtension<ResColorsExtension>? other, double t) {
    // The palette swaps wholesale at the light/dark boundary; interpolating
    // twenty colours independently produces muddy intermediate frames, so snap
    // at the midpoint instead.
    if (other is! ResColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension ResThemeContext on BuildContext {
  /// The active palette. Prefer this over `Theme.of(context).colorScheme`.
  ResColors get colors =>
      Theme.of(this).extension<ResColorsExtension>()!.colors;

  /// True when the window is wide enough for a side rail rather than a bottom
  /// bar — practically, macOS and landscape tablets.
  bool get isExpanded => MediaQuery.sizeOf(this).width >= ResBreak.expanded;

  /// Horizontal page gutter for the current width.
  double get gutter =>
      isExpanded ? ResSpace.gutterExpanded : ResSpace.gutterCompact;
}

class ResTheme {
  const ResTheme._();

  static ThemeData light() => _build(ResColors.light, Brightness.light);
  static ThemeData dark() => _build(ResColors.dark, Brightness.dark);

  static ThemeData _build(ResColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.tier2,
      onSecondary: c.onAccent,
      error: c.clip,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.inkMuted,
      outline: c.rule,
      outlineVariant: c.ruleSoft,
    );

    final text = TextTheme(
      displayLarge: ResType.hero.copyWith(color: c.ink),
      headlineMedium: ResType.title.copyWith(color: c.ink),
      titleMedium: ResType.heading.copyWith(color: c.ink),
      bodyLarge: ResType.body.copyWith(color: c.ink),
      bodyMedium: ResType.body.copyWith(color: c.inkMuted),
      bodySmall: ResType.caption.copyWith(color: c.inkMuted),
      labelSmall: ResType.label.copyWith(color: c.inkFaint),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: [ResColorsExtension(c)],
      dividerTheme: DividerThemeData(color: c.ruleSoft, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResRadius.medium),
          side: BorderSide(color: c.ruleSoft),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          textStyle: ResType.bodyStrong,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResRadius.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentInk,
          textStyle: ResType.bodyStrong,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: ResType.heading.copyWith(color: c.ink),
      ),
      // A visible focus ring is mandatory: macOS users navigate this app by
      // keyboard while their hands are otherwise on a mic or a script.
      focusColor: c.accent.withValues(alpha: 0.4),
    );
  }
}
