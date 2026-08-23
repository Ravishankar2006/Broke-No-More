import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple in-memory theme toggle for the Profile screen (PRD section 4).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Explicit set, for a switch whose position must match the resulting state.
  /// `toggle` flips relative to the current value, which desyncs a Switch when
  /// the mode is still `system`.
  void setDark(bool dark) {
    state = dark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
