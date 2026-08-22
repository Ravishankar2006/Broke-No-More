import 'package:flutter/material.dart';

/// Design tokens. Placeholder palette — branding/logo/tone are still an
/// open question per the PRD (section 11); swap these once decided.
abstract class AppColors {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color secondary = Color(0xFF00C896);

  static const Color xp = Color(0xFFFFB300);
  static const Color streak = Color(0xFFFF6D00);
  static const Color expense = Color(0xFFE53935);
  static const Color income = Color(0xFF2E7D32);

  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF121317);
  static const Color darkSurface = Color(0xFF1C1E24);
}
