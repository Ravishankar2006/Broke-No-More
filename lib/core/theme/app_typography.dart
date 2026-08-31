import 'package:flutter/material.dart';

/// The bundled typeface. Declared in pubspec.yaml under `fonts:` and shipped as
/// static .ttf files in assets/fonts/, so it renders offline on first launch —
/// google_fonts' runtime fetch was never viable in a fully-offline app.
const String kFontFamily = 'Plus Jakarta Sans';

/// The tracking applied to every all-caps "overline" label — section
/// headers, day-group labels, streak-hero captions ("DAY", "BEST").
/// Previously each site hand-picked its own value (0.8-1.2) with no shared
/// rule; this is the one true value, matched to `SectionHeader`'s.
const double kOverlineLetterSpacing = 1.1;

/// Build the text theme for a given brightness. Called from app_theme.dart.
TextTheme buildTextTheme(ColorScheme scheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = isDark
      ? Typography.material2021().white
      : Typography.material2021().black;

  const fontFamily = kFontFamily;

  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  // Apply font family and colors to base theme
  return base
      .apply(
        bodyColor: onSurface,
        displayColor: onSurface,
        fontFamily: fontFamily,
      )
      .copyWith(
        // Display — the app's biggest hero numbers (streak count, the
        // log-sheet amount field). Sizes match Material's own defaults
        // (32/36/45/57) rather than a redesigned scale, so adding these
        // doesn't risk a layout regression in the two places that were
        // already rendering at the untuned default; what was missing was
        // the family's letterSpacing/height/weight convention, extrapolated
        // from headlineSmall/headlineMedium below.
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          height: 1.0,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.05,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.1,
          fontFamily: fontFamily,
          color: onSurface,
        ),

        // Headlines — used for large numbers (amounts, balances)
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.2,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.25,
          fontFamily: fontFamily,
          color: onSurface,
        ),

        // Titles
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.35,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.4,
          fontFamily: fontFamily,
          color: onSurface,
        ),

        // Body
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          height: 1.5,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          height: 1.45,
          fontFamily: fontFamily,
          color: onSurfaceVariant,
        ),

        // Labels — used for buttons, chip text, nav labels, chart axis
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.2,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.2,
          fontFamily: fontFamily,
          color: onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.2,
          fontFamily: fontFamily,
          color: onSurfaceVariant,
        ),
      );
}
