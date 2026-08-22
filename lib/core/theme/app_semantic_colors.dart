import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-specific semantic colours that vary by brightness. Lives as a ThemeExtension
/// so it's brightness-aware and animates smoothly during light↔dark transitions
/// (consts would hard-cut mid-animation while ColorScheme fades).
///
/// Consumers read via context.semantics, defined below.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.xp,
    required this.xpTrack,
    required this.streak,
    required this.streakTrack,
    required this.onGold,
    required this.goldInk,
    required this.income,
    required this.incomeInk,
    required this.expense,
    required this.expenseInk,
    required this.budgetUnder,
    required this.budgetOver,
    required this.barTrack,
    required this.chartGrid,
    required this.chartBar,
    required this.chartPalette,
  });

  final Color xp;
  final Color xpTrack;
  final Color streak;
  final Color streakTrack;
  final Color onGold;
  final Color goldInk;
  final Color income;
  final Color incomeInk;
  final Color expense;
  final Color expenseInk;
  final Color budgetUnder;
  final Color budgetOver;
  final Color barTrack;
  final Color chartGrid;
  final Color chartBar;
  final List<Color> chartPalette;

  static const AppSemanticColors light = AppSemanticColors(
    xp: AppPalette.gold,
    xpTrack: Color(0x26F5B301), // gold @ 0.15 alpha
    streak: AppPalette.gold,
    streakTrack: Color(0x1EF5B301), // gold @ 0.12 alpha
    onGold: AppPalette.onGold,
    goldInk: AppPalette.goldInkLight,
    income: AppPalette.income,
    incomeInk: AppPalette.incomeInkLight,
    expense: AppPalette.expense,
    expenseInk: AppPalette.expenseInkLight,
    budgetUnder: AppPalette.indigo600,
    budgetOver: AppPalette.expense,
    barTrack: AppPalette.surfaceHighLight,
    chartGrid: AppPalette.outlineVariantLight,
    chartBar: AppPalette.indigo600,
    chartPalette: AppPalette.chartLight,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    xp: AppPalette.gold,
    xpTrack: Color(0x33F5B301), // gold @ 0.2 alpha
    streak: AppPalette.gold,
    streakTrack: Color(0x2DF5B301), // gold @ 0.18 alpha
    onGold: AppPalette.onGold,
    goldInk: AppPalette.goldInkDark,
    income: AppPalette.income,
    incomeInk: AppPalette.incomeInkDark,
    expense: AppPalette.expense,
    expenseInk: AppPalette.expenseInkDark,
    budgetUnder: AppPalette.indigoLight400,
    budgetOver: AppPalette.expense,
    barTrack: AppPalette.surfaceHighDark,
    chartGrid: AppPalette.outlineVariantDark,
    chartBar: AppPalette.indigoLight400,
    chartPalette: AppPalette.chartDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? xp,
    Color? xpTrack,
    Color? streak,
    Color? streakTrack,
    Color? onGold,
    Color? goldInk,
    Color? income,
    Color? incomeInk,
    Color? expense,
    Color? expenseInk,
    Color? budgetUnder,
    Color? budgetOver,
    Color? barTrack,
    Color? chartGrid,
    Color? chartBar,
    List<Color>? chartPalette,
  }) {
    return AppSemanticColors(
      xp: xp ?? this.xp,
      xpTrack: xpTrack ?? this.xpTrack,
      streak: streak ?? this.streak,
      streakTrack: streakTrack ?? this.streakTrack,
      onGold: onGold ?? this.onGold,
      goldInk: goldInk ?? this.goldInk,
      income: income ?? this.income,
      incomeInk: incomeInk ?? this.incomeInk,
      expense: expense ?? this.expense,
      expenseInk: expenseInk ?? this.expenseInk,
      budgetUnder: budgetUnder ?? this.budgetUnder,
      budgetOver: budgetOver ?? this.budgetOver,
      barTrack: barTrack ?? this.barTrack,
      chartGrid: chartGrid ?? this.chartGrid,
      chartBar: chartBar ?? this.chartBar,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      xp: Color.lerp(xp, other.xp, t)!,
      xpTrack: Color.lerp(xpTrack, other.xpTrack, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      streakTrack: Color.lerp(streakTrack, other.streakTrack, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      goldInk: Color.lerp(goldInk, other.goldInk, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeInk: Color.lerp(incomeInk, other.incomeInk, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseInk: Color.lerp(expenseInk, other.expenseInk, t)!,
      budgetUnder: Color.lerp(budgetUnder, other.budgetUnder, t)!,
      budgetOver: Color.lerp(budgetOver, other.budgetOver, t)!,
      barTrack: Color.lerp(barTrack, other.barTrack, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartBar: Color.lerp(chartBar, other.chartBar, t)!,
      chartPalette: t < 0.5
          ? chartPalette
          : other.chartPalette, // discrete, not interpolated
    );
  }
}

/// Convenience extension: `context.semantics` instead of
/// `Theme.of(context).extension<AppSemanticColors>()!`
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantics =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
