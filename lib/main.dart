import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'data/gamification_repair.dart';
import 'data/quest_repository.dart';
import 'data/recurring_transaction_repository.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  // Turns any due recurring rules into real transactions — same "no backend
  // to run this on a schedule" constraint as quest expiry below, so this is
  // the one checkpoint. Must run before the repair pass, so newly-created
  // rows are already in the transactions box when it replays.
  await RecurringTransactionRepository().materializeDue();
  // Catches quests that passed their endDate while the app was closed —
  // nothing else runs while offline, so this is the one guaranteed checkpoint.
  await QuestRepository().expireOverdueQuests();
  // Re-derives XP/streak/quests from the transaction list, repairing anything a
  // partial write left inconsistent — Hive has no cross-box transaction, and
  // there's no backend to reconcile on a schedule. Must run after quest expiry,
  // which is time-driven and treated as terminal by the replay.
  await repairGamificationState();
  runApp(const ProviderScope(child: BrokeNoMoreApp()));
}

class BrokeNoMoreApp extends ConsumerWidget {
  const BrokeNoMoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final hasProfile = ref.watch(profileProvider) != null;

    return MaterialApp(
      title: 'Broke No More',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: hasProfile ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
