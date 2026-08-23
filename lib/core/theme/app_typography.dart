import 'package:flutter/material.dart';

/// The bundled typeface. Declared in pubspec.yaml under `fonts:` and shipped as
/// static .ttf files in assets/fonts/, so it renders offline on first launch —
/// google_fonts' runtime fetch was never viable in a fully-offline app.
const String kFontFamily = 'Plus Jakarta Sans';

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
        // Headlines — used for large numbers (amounts, balances)
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
