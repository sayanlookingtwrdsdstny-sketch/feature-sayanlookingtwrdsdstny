import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// Builds NURIVA's light and dark themes from [NurivaTokens].
///
/// Every component style is centralized here rather than repeated per screen,
/// so a change to button shape or input padding lands everywhere at once.
abstract final class NurivaTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: NurivaTokens.brand,
      brightness: brightness,
    ).copyWith(
      // Slightly warmer, less clinical surfaces than the raw seed produces.
      surface: isLight ? const Color(0xFFFBFCFC) : const Color(0xFF0F1716),
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontSize: NurivaTokens.fontDisplay,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: NurivaTokens.fontHeading,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: NurivaTokens.fontTitle,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: NurivaTokens.fontBody,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: NurivaTokens.fontBody,
        height: 1.5,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: NurivaTokens.fontBodySm,
        height: 1.5,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: NurivaTokens.fontBody,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: NurivaTokens.fontCaption,
        height: 1.4,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        isLight
            ? const NurivaStatusColors.light()
            : const NurivaStatusColors.dark(),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 26),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(NurivaTokens.controlHeight),
          shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: NurivaTokens.space6,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(NurivaTokens.controlHeight),
          shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outlineVariant, width: 1.4),
          padding: const EdgeInsets.symmetric(
            horizontal: NurivaTokens.space6,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, NurivaTokens.minTouchTarget),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.surfaceContainerHighest.withValues(alpha: .5)
            : scheme.surfaceContainerHighest.withValues(alpha: .35),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NurivaTokens.space4,
          vertical: NurivaTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: NurivaTokens.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NurivaTokens.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NurivaTokens.brMd,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: NurivaTokens.brMd,
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: NurivaTokens.brMd,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.outline),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brLg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NurivaTokens.radiusLg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: NurivaTokens.space3,
        shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 6,
      ),
    );
  }
}
