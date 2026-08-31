import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Depth tokens.
///
/// The app previously carried all elevation with 1px hairline borders and
/// `elevation: 0`, which reads flat and unfinished. These are the replacement.
///
/// Two rules make soft depth look designed rather than muddy:
///
/// 1. **Shadows are tinted, never black.** They use the brand indigo
///    (`indigo950`) so they read as the surface sitting on *this* canvas, not as
///    a generic drop shadow. Gold surfaces get a gold-tinted glow instead.
/// 2. **Dark mode is not the same shadow at higher opacity.** On `#0E1117` a
///    wide soft shadow is invisible, so dark uses tighter, deeper shadows —
///    the way real materials catch light.
///
/// Every getter takes [Brightness] so callers can't accidentally use the light
/// treatment on a dark canvas.
abstract class AppShadows {
  static bool _isDark(Brightness b) => b == Brightness.dark;

  /// Resting cards and list rows. Subtle — this is the most-used token, so it
  /// must never draw attention to itself.
  static List<BoxShadow> card(Brightness brightness) {
    if (_isDark(brightness)) {
      return const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x0F1E1B4B), // indigo950 @ 0.06
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x0A1E1B4B), // indigo950 @ 0.04
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
    ];
  }

  /// Gold glow. Reserved for reward surfaces — the streak hero, the XP bar on
  /// gain, level-up and badge-unlock art. Using it anywhere else spends the
  /// 10% accent tier and makes the real reward moments stop landing.
  static List<BoxShadow> gold(Brightness brightness) {
    if (_isDark(brightness)) {
      return const [
        BoxShadow(
          color: Color(0x4DF5B301), // gold @ 0.30
          blurRadius: 28,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x40F5B301), // gold @ 0.25
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0x141E1B4B), // indigo950 @ 0.08
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ];
  }
}

/// Gradients for hero surfaces.
///
/// Kept beside the shadows because the two are always used together: a hero
/// card is a gradient fill *plus* [AppShadows.gold]. Split them and they drift.
abstract class AppGradients {
  /// The streak hero on Home — the app's single loudest surface.
  static LinearGradient streak(Brightness brightness) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: brightness == Brightness.dark
          ? const [Color(0xFFF5B301), Color(0xFFD98A00)]
          : const [Color(0xFFFFD65C), Color(0xFFF5B301)],
    );
  }

  /// XP bar fill. Brighter at the leading edge so progress reads directionally.
  static LinearGradient xp(Brightness brightness) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: brightness == Brightness.dark
          ? const [Color(0xFFD98A00), Color(0xFFFFD65C)]
          : const [Color(0xFFF5B301), Color(0xFFFFD65C)],
    );
  }

  /// Indigo hero — quests, level medallions, anything brand-primary.
  static LinearGradient brand(Brightness brightness) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: brightness == Brightness.dark
          ? const [AppPalette.indigoLight500, AppPalette.indigo700]
          : const [AppPalette.indigoLight400, AppPalette.indigo600],
    );
  }

  /// Moving sheen swept across a bar or medallion when a reward lands.
  /// Transparent at both ends so it reads as light passing over, not a stripe.
  static const LinearGradient sheen = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );
}
