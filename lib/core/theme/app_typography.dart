import 'package:flutter/material.dart';

/// Build the text theme for a given brightness. Called from app_theme.dart.
TextTheme buildTextTheme(ColorScheme scheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = isDark
      ? Typography.material2021().white
      : Typography.material2021().black;

  final onSurface = isDark ? scheme.onSurface : scheme.onSurface;
  final onSurfaceVariant = isDark ? scheme.onSurfaceVariant : scheme.onSurfaceVariant;

  return base
      .apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      )
      .copyWith(
        // Headlines — used for large numbers (amounts, balances)
        headlineMedium: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.2,
        ).copyWith(color: onSurface),
        headlineSmall: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.25,
        ).copyWith(color: onSurface),

        // Titles
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
        ).copyWith(color: onSurface),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.35,
        ).copyWith(color: onSurface),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.4,
        ).copyWith(color: onSurface),

        // Body
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
        ).copyWith(color: onSurface),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          height: 1.5,
        ).copyWith(color: onSurface),
        bodySmall: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          height: 1.45,
        ).copyWith(color: onSurfaceVariant),

        // Labels — used for buttons, chip text, nav labels, chart axis
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.2,
        ).copyWith(color: onSurface),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.2,
        ).copyWith(color: onSurface),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.2,
        ).copyWith(color: onSurfaceVariant),
      );
}
