import 'package:flutter/material.dart';

/// NURIVA design tokens — the single source of every visual constant.
///
/// Nothing in the app hardcodes a colour, radius, or spacing value. Screens
/// compose components; components read tokens. That is what keeps eighteen
/// modules from drifting into eighteen visual dialects.
///
/// The numbers are driven by the audience, not by taste. NURIVA's users are
/// elderly patients and non-technical family members, so touch targets exceed
/// the Material minimum, body text starts larger than default, and contrast is
/// held above WCAG AA in both themes.
abstract final class NurivaTokens {
  // ─────────────────────────────────────────────────────────────── brand

  /// Brand seed. A calm clinical green-teal.
  ///
  /// Chosen over hospital blue (cold, institutional) and over any red or
  /// orange, which are reserved exclusively for dose state. A brand colour that
  /// collides with a status colour makes "is this bad news?" ambiguous.
  static const Color brand = Color(0xFF0E6E5C);
  static const Color brandDeep = Color(0xFF0A5648);
  static const Color brandLight = Color(0xFF4FBFA5);

  // ───────────────────────────────────────────────────────── touch targets

  /// Minimum tappable edge. Above Material's 48dp floor.
  ///
  /// Reduced motor precision is the norm in this audience, and a mis-tap on a
  /// dose screen records the wrong medical fact.
  static const double minTouchTarget = 56;

  /// Edge for the single most important control on a screen (TAKEN).
  static const double primaryActionHeight = 72;

  /// Standard control height for secondary actions and inputs.
  static const double controlHeight = 56;

  // ─────────────────────────────────────────────────────────────── spacing

  /// 4dp base unit. Every gap in the app is a multiple of it.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;

  /// Standard horizontal page inset.
  static const double pageInset = space5;

  // ──────────────────────────────────────────────────────────────── shape

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);
  static BorderRadius get brPill => BorderRadius.circular(radiusPill);

  // ───────────────────────────────────────────────────────────── typography

  /// Body text size. Larger than Material's 14dp default.
  static const double fontBody = 17;
  static const double fontBodySm = 15;
  static const double fontCaption = 13;
  static const double fontTitle = 20;
  static const double fontHeading = 26;
  static const double fontDisplay = 34;

  /// Upper bound on the OS text-scale factor NURIVA honours.
  ///
  /// Users in this audience often set system text very large. Unbounded scaling
  /// can push a primary action off screen, which on a dose reminder is a safety
  /// problem rather than a cosmetic one. Scaling is respected up to this bound,
  /// never ignored.
  static const double maxTextScale = 1.6;

  // ───────────────────────────────────────────────────────────── elevation

  /// Shadows are used sparingly: only to lift something that genuinely floats
  /// above the page (dialogs, sheets, the active dose card). A shadow on every
  /// surface flattens hierarchy instead of creating it.
  static List<BoxShadow> shadowSoft(Brightness b) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.light ? .06 : .34),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> shadowLifted(Brightness b) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.light ? .12 : .48),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  // ──────────────────────────────────────────────────────────── animation

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationBase = Duration(milliseconds: 260);
  static const Duration durationSlow = Duration(milliseconds: 420);
  static const Curve curveStandard = Curves.easeOutCubic;

  // ─────────────────────────────────────────────────── dose-state palette

  // Semantic status colours, kept deliberately separate from [brand] so that
  // status never competes with branding for meaning. These become load-bearing
  // from Module 10 onward.

  static const Color taken = Color(0xFF2E7D5B);
  static const Color due = Color(0xFF0E6E5C);
  static const Color late = Color(0xFF8A6212);
  static const Color missed = Color(0xFFA8341F);
  static const Color skipped = Color(0xFF6A7A76);

  static const Color takenDark = Color(0xFF5FBF92);
  static const Color dueDark = Color(0xFF4FBFA5);
  static const Color lateDark = Color(0xFFD9A93E);
  static const Color missedDark = Color(0xFFE38468);
  static const Color skippedDark = Color(0xFF7D8E89);
}

/// Status a piece of information can carry, independent of dose semantics.
///
/// Used by [NurivaStatusChip] and the state views so that "good / attention /
/// problem" is expressed the same way everywhere.
enum NurivaStatus { neutral, positive, warning, danger, info }

/// Dose-state colours resolved for the active brightness.
///
/// A [ThemeExtension] rather than raw constants, so a widget cannot accidentally
/// paint a light-theme red onto a dark surface.
@immutable
final class NurivaStatusColors extends ThemeExtension<NurivaStatusColors> {
  const NurivaStatusColors({
    required this.taken,
    required this.due,
    required this.late,
    required this.missed,
    required this.skipped,
  });

  const NurivaStatusColors.light()
      : taken = NurivaTokens.taken,
        due = NurivaTokens.due,
        late = NurivaTokens.late,
        missed = NurivaTokens.missed,
        skipped = NurivaTokens.skipped;

  const NurivaStatusColors.dark()
      : taken = NurivaTokens.takenDark,
        due = NurivaTokens.dueDark,
        late = NurivaTokens.lateDark,
        missed = NurivaTokens.missedDark,
        skipped = NurivaTokens.skippedDark;

  final Color taken;
  final Color due;
  final Color late;
  final Color missed;
  final Color skipped;

  /// Resolves a semantic [status] to its colour in the current theme.
  Color of(NurivaStatus status, ColorScheme scheme) => switch (status) {
        NurivaStatus.positive => taken,
        NurivaStatus.warning => late,
        NurivaStatus.danger => missed,
        NurivaStatus.info => due,
        NurivaStatus.neutral => skipped,
      };

  @override
  NurivaStatusColors copyWith({
    Color? taken,
    Color? due,
    Color? late,
    Color? missed,
    Color? skipped,
  }) =>
      NurivaStatusColors(
        taken: taken ?? this.taken,
        due: due ?? this.due,
        late: late ?? this.late,
        missed: missed ?? this.missed,
        skipped: skipped ?? this.skipped,
      );

  @override
  NurivaStatusColors lerp(NurivaStatusColors? other, double t) {
    if (other == null) return this;
    return NurivaStatusColors(
      taken: Color.lerp(taken, other.taken, t)!,
      due: Color.lerp(due, other.due, t)!,
      late: Color.lerp(late, other.late, t)!,
      missed: Color.lerp(missed, other.missed, t)!,
      skipped: Color.lerp(skipped, other.skipped, t)!,
    );
  }
}

/// Convenience access to NURIVA's theme pieces.
extension NurivaThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Dose/status colours for the active theme.
  NurivaStatusColors get statusColors =>
      Theme.of(this).extension<NurivaStatusColors>() ??
      (isDark
          ? const NurivaStatusColors.dark()
          : const NurivaStatusColors.light());
}
