import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/database/hive_boxes.dart';

const String _kThemeModeKey = 'theme_mode';

/// Persists the user's theme choice to the untyped `app_state` box (PRD
/// section 4) — same pattern as [SkippedQuestRepository]. Previously this
/// held state in memory only, so every cold start reverted to `system`
/// regardless of what the user had chosen.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  Box<dynamic> get _box => Hive.box<dynamic>(HiveBoxes.appState);

  @override
  ThemeMode build() {
    final stored = _box.get(_kThemeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _box.put(_kThemeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
