import 'package:flutter/material.dart';

/// Raw colour hexes — palette ramps only. Widgets must NOT import this directly.
/// Use AppSemanticColors (a ThemeExtension) for brightness-aware semantic colours
/// that change between light and dark modes. Use context.colorScheme for M3 colours.
///
/// CRITICAL RULE: brand hex fills (gold, income, expense) are barely readable as text
/// on canvas. Each split into FILL (FAB, progress, badges) and INK variants
/// (text/icons on canvas or card, same hue, contrast-corrected):
/// - #F5B301 gold fill → #9A6C00 on light canvas, #F7C846 on dark canvas
/// - #16A34A income fill → #15803D on light, #4ADE80 on dark
/// - #DC2626 expense fill → #B91C1C on light, #F87171 on dark
/// Violating this rule is how palettes get quietly abandoned. Do not put gold text on white.
abstract class AppPalette {
  // --- Indigo ramp (30% tier, primary) ---
  static const Color indigoLight50 = Color(0xFFEEF0FB);
  static const Color indigoLight100 = Color(0xFFE0E3FB);
  static const Color indigoLight300 = Color(0xFFA5B4FC);
  static const Color indigoLight400 = Color(0xFF818CF8);
  static const Color indigoLight500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5); // brand primary
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color indigo800 = Color(0xFF3730A3);
  static const Color indigo950 = Color(0xFF1E1B4B);

  // --- Gold ramp (10% tier, fills only) ---
  static const Color gold = Color(0xFFF5B301); // brand accent, fills only
  static const Color goldSoft = Color(0xFFFFD65C);
  static const Color goldTintLight = Color(0xFFFFF1C9);
  static const Color goldTintDark = Color(0xFF4A3300);
  // Ink versions (text/icon on canvas/card):
  static const Color goldInkLight = Color(
    0xFF9A6C00,
  ); // gold text on light canvas/card
  static const Color goldInkDark = Color(
    0xFFF7C846,
  ); // gold text on dark canvas/card
  // Ink placed ON gold fills (never Colors.white):
  static const Color onGold = Color(0xFF1A1200);

  // --- Canvas (60% tier) ---
  static const Color canvasLight = Color(0xFFF6F7FB);
  static const Color canvasDark = Color(0xFF0E1117);

  // --- Surfaces (30% tier) ---
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A2030);
  static const Color surfaceHighLight = Color(0xFFEAEDF7);
  static const Color surfaceHighDark = Color(0xFF212940);
  static const Color surfaceHighestLight = Color(0xFFE4E8F4);
  static const Color surfaceHighestDark = Color(0xFF27314B);

  // --- Outline (dividers, borders) ---
  static const Color outlineLight = Color(0xFFC7CBDA);
  static const Color outlineDark = Color(0xFF3A4358);
  static const Color outlineVariantLight = Color(0xFFE4E7F0);
  static const Color outlineVariantDark = Color(0xFF262E40);

  // --- OnSurface (text, icons on cards) ---
  static const Color onSurfaceLight = Color(0xFF12141C);
  static const Color onSurfaceDark = Color(0xFFE6E9F2);
  static const Color onSurfaceVariantLight = Color(0xFF55596B);
  static const Color onSurfaceVariantDark = Color(0xFFA3AAC0);

  // --- Semantic fills (use the Ink variants for foreground) ---
  static const Color income = Color(0xFF16A34A);
  static const Color incomeInkLight = Color(0xFF15803D);
  static const Color incomeInkDark = Color(0xFF4ADE80);

  static const Color expense = Color(0xFFDC2626);
  static const Color expenseInkLight = Color(0xFFB91C1C);
  static const Color expenseInkDark = Color(0xFFF87171);

  // --- Chart colour ramps (10 hues, light and dark) ---
  // Anchored on brand, alternating warm/cool, deliberately avoiding exact income-green
  // and expense-red so semantic colours stay distinct. Index-mapped, not category-keyed
  // (see insights_screen.dart for the stable-hash assignment).
  static const List<Color> chartLight = [
    indigo600, // #4F46E5
    gold, // #F5B301
    Color(0xFF0EA5E9), // sky
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF7C3AED), // violet
    Color(0xFFF97316), // orange
    Color(0xFF6366F1), // indigo-light
    Color(0xFFA16207), // bronze
    Color(0xFF64748B), // slate
  ];

  static const List<Color> chartDark = [
    indigoLight400, // #818CF8
    goldSoft, // #FBBF24
    Color(0xFF38BDF8), // sky
    Color(0xFFF472B6), // pink
    Color(0xFF2DD4BF), // teal
    Color(0xFFC084FC), // violet
    Color(0xFFFB923C), // orange
    Color(0xFFE879F9), // indigo-light
    Color(0xFFCBA35C), // bronze
    Color(0xFF94A3B8), // slate
  ];
}
