import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/streak_reminder_service.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/badge_unlock_dialog.dart';
import '../../shared_widgets/level_up_dialog.dart';
import '../insights/insights_screen.dart';
import '../log_transaction/log_transaction_sheet.dart';
import '../profile/profile_screen.dart';
import '../quests/quests_screen.dart';
import 'home_screen.dart';

/// Bottom-nav shell wiring the four main tabs plus the log-transaction FAB,
/// per the core user flow in the PRD (section 4).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Re-arm tonight's streak reminder on every app open — cheap, and
    // means a killed/reinstalled app doesn't leave a stale schedule.
    Future.microtask(() {
      final profile = ref.read(profileProvider);
      if (profile == null || !profile.remindersEnabled) return;
      if (isSameDay(profile.lastLoggedDate, DateTime.now())) return;
      StreakReminderService.instance
          .scheduleTonightReminder(currentStreak: profile.currentStreak);
    });
  }

  static const _tabs = [
    HomeScreen(),
    InsightsScreen(),
    QuestsScreen(),
    ProfileScreen(),
  ];

  Future<void> _openLogSheet() async {
    final result = await showModalBottomSheet<LogTransactionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LogTransactionSheet(),
    );
    if (!mounted || result == null) return;

    if (result.leveledUpTo != null) {
      await showLevelUpDialog(context, result.leveledUpTo!);
    }
    if (!mounted || result.newlyUnlockedBadges.isEmpty) return;
    await showBadgeUnlockDialog(context, result.newlyUnlockedBadges);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openLogSheet,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavButton(
              icon: Icons.insights_rounded,
              label: 'Insights',
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            const SizedBox(width: 48),
            _NavButton(
              icon: Icons.flag_rounded,
              label: 'Quests',
              selected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
            _NavButton(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
