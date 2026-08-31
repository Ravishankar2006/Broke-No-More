import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';

/// 60-30-10 colour distribution:
/// - 60% canvas: scaffoldBackgroundColor
/// - 30% indigo: all chrome (surface, cards, app bar, nav, dialogs, sheet)
/// - 10% gold: FAB, buttons, XP/streak/progress, badges
///
/// Color-scheme is built via fromSeed + explicit role overrides so brand hexes
/// (indigo, gold) survive quantisation. ColorScheme.surface is the single source
/// of truth for all chrome — no more seams between cards and nav bar.
abstract class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = _colorScheme(brightness);
    // Hoisted: this used to be re-invoked inside ~19 component themes, rebuilding
    // the whole text theme each time.
    final text = buildTextTheme(cs, brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark
          ? AppPalette.canvasDark
          : AppPalette.canvasLight,
      textTheme: text,
      extensions: [isDark ? AppSemanticColors.dark : AppSemanticColors.light],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      // --- Component themes ---
      appBarTheme: AppBarThemeData(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Spacing.lg,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
        surfaceTintColor: Colors.transparent,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: cs.surface,
        elevation: AppElevation.chrome,
        shadowColor: AppPalette.indigo950.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.secondaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.tertiary,
        foregroundColor: cs.onTertiary,
        elevation: AppElevation.fab,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 6,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.tertiary, // gold
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        circularTrackColor: Colors.transparent,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.tertiary,
          foregroundColor: cs.onTertiary,
          disabledBackgroundColor: cs.tertiary.withValues(alpha: 0.35),
          disabledForegroundColor: cs.onTertiary.withValues(alpha: 0.5),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl,
            vertical: Spacing.md,
          ),
          textStyle: text.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          side: BorderSide(color: cs.outline),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.secondaryContainer,
        disabledColor: cs.surfaceContainerHighest,
        showCheckmark: false,
        side: BorderSide(color: cs.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge!.copyWith(color: cs.onSurface),
        secondaryLabelStyle: text.labelLarge!.copyWith(
          color: cs.onSecondaryContainer,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 18),
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? cs.primary
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? cs.onPrimary
                : cs.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        textColor: cs.onSurface,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall!.copyWith(color: cs.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        minLeadingWidth: 24,
        horizontalTitleGap: Spacing.lg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
        indent: 56, // align under ListTile text
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.xl,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        modalBackgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false, // log_transaction_sheet draws its own
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        hintStyle: text.bodyLarge!.copyWith(color: cs.onSurfaceVariant),
        labelStyle: text.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
        prefixStyle: text.bodyLarge!.copyWith(color: cs.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.onPrimary : cs.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primary
              : cs.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(cs.outline),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        insetPadding: const EdgeInsets.all(Spacing.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: text.bodySmall!.copyWith(color: cs.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.24),
        selectionHandleColor: cs.primary,
      ),
    );
  }

  /// Build the ColorScheme: fromSeed with explicit role overrides so brand hexes survive.
  static ColorScheme _colorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return ColorScheme.fromSeed(
        seedColor: AppPalette.indigo600,
        brightness: Brightness.dark,
        primary: AppPalette.indigoLight400,
        onPrimary: AppPalette.indigo950,
        primaryContainer: AppPalette.indigo700,
        onPrimaryContainer: AppPalette.indigoLight100,
        secondary: AppPalette.indigoLight400,
        onSecondary: AppPalette.indigo950,
        secondaryContainer: AppPalette.indigo800,
        onSecondaryContainer: AppPalette.indigoLight100,
        tertiary: AppPalette.gold,
        onTertiary: AppPalette.onGold,
        tertiaryContainer: AppPalette.goldTintDark,
        onTertiaryContainer: const Color(0xFFFFE9A8),
        error: const Color(0xFFF87171),
        onError: const Color(0xFF2B0A0A),
        surface: AppPalette.surfaceDark,
        onSurface: AppPalette.onSurfaceDark,
        surfaceContainerLowest: const Color(0xFF0B0E14),
        surfaceContainerLow: const Color(0xFF141A27),
        surfaceContainer: AppPalette.surfaceDark,
        surfaceContainerHigh: AppPalette.surfaceHighDark,
        surfaceContainerHighest: AppPalette.surfaceHighestDark,
        onSurfaceVariant: AppPalette.onSurfaceVariantDark,
        outline: AppPalette.outlineDark,
        outlineVariant: AppPalette.outlineVariantDark,
        surfaceTint: Colors.transparent,
      );
    } else {
      return ColorScheme.fromSeed(
        seedColor: AppPalette.indigo600,
        brightness: Brightness.light,
        primary: AppPalette.indigo600,
        onPrimary: Colors.white,
        primaryContainer: AppPalette.indigoLight100,
        onPrimaryContainer: AppPalette.indigo950,
        secondary: AppPalette.indigo700,
        onSecondary: Colors.white,
        secondaryContainer: AppPalette.indigoLight100,
        onSecondaryContainer: AppPalette.indigo950,
        tertiary: AppPalette.gold,
        onTertiary: AppPalette.onGold,
        tertiaryContainer: AppPalette.goldTintLight,
        onTertiaryContainer: AppPalette.goldTintDark,
        error: AppPalette.expense,
        onError: Colors.white,
        surface: AppPalette.surfaceLight,
        onSurface: AppPalette.onSurfaceLight,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFBFBFE),
        surfaceContainer: const Color(0xFFF1F3FA),
        surfaceContainerHigh: AppPalette.surfaceHighLight,
        surfaceContainerHighest: AppPalette.surfaceHighestLight,
        onSurfaceVariant: AppPalette.onSurfaceVariantLight,
        outline: AppPalette.outlineLight,
        outlineVariant: AppPalette.outlineVariantLight,
        surfaceTint: Colors.transparent,
      );
    }
  }
}
