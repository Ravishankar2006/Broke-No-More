import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/streak_reminder_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/badge_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/badge_unlock_dialog.dart';
import '../../shared_widgets/celebration_effects.dart';
import '../../shared_widgets/level_up_dialog.dart';
import '../../shared_widgets/quest_complete_dialog.dart';
import '../insights/insights_screen.dart';
import '../log_transaction/log_transaction_sheet.dart';
import '../profile/profile_screen.dart';
import '../quests/quests_screen.dart';
import 'home_screen.dart';

/// Width reserved in the nav row for the docked FAB.
///
/// A default [FloatingActionButton] is 56px wide and `notchMargin` adds 10px on
/// each side, so the notch actually occupies 76px. The previous 48px reservation
/// meant the notch cut into the buttons on either side.
const double _kFabNotchWidth = 76;

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

  List<Widget> get _tabs => [
        HomeScreen(onLogPressed: _openLogSheet),
        const InsightsScreen(),
        const QuestsScreen(),
        const ProfileScreen(),
      ];

  Future<void> _openLogSheet() async {
    final result = await showModalBottomSheet<LogTransactionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LogTransactionSheet(),
    );
    if (!mounted || result == null) return;

    // Every log now gets acknowledged. Previously a log that didn't happen to
    // trigger a level-up produced no feedback at all — the sheet just closed.
    if (result.xpGained > 0) showXpGain(context, result.xpGained);

    // completedQuests was computed by the orchestrator but never surfaced —
    // a quest could fill its bar to 100% with no acknowledgement at all.
    if (result.completedQuests.isNotEmpty) {
      await showQuestCompleteDialog(context, result.completedQuests);
    }

    if (!mounted) return;
    if (result.leveledUpTo != null) {
      await showLevelUpDialog(context, result.leveledUpTo!);
    }
    if (!mounted || result.newlyUnlockedBadges.isEmpty) return;
    await showBadgeUnlockDialog(
      context,
      result.newlyUnlockedBadges,
      totalUnlocked: ref.read(badgesProvider).length,
    );
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppMotion.standard,
        // Cross-fade instead of the hard cut an IndexedStack gives. The
        // outgoing tab is faded out in place rather than sliding, so switching
        // tabs never looks like navigation.
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _tabs[_index],
        ),
      ),
      floatingActionButton: _LogFab(onPressed: _openLogSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: Row(
          children: [
            _NavButton(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _index == 0,
              onTap: () => _select(0),
            ),
            _NavButton(
              icon: Icons.insights_rounded,
              label: 'Insights',
              selected: _index == 1,
              onTap: () => _select(1),
            ),
            const SizedBox(width: _kFabNotchWidth),
            _NavButton(
              icon: Icons.flag_rounded,
              label: 'Quests',
              selected: _index == 2,
              onTap: () => _select(2),
            ),
            _NavButton(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: _index == 3,
              onTap: () => _select(3),
            ),
          ],
        ),
      ),
    );
  }
}

/// The log FAB, with a press response so the app's primary action feels
/// physical rather than inert.
class _LogFab extends StatefulWidget {
  const _LogFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LogFab> createState() => _LogFabState();
}

class _LogFabState extends State<_LogFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.9 : 1,
      duration: AppMotion.quick,
      curve: AppMotion.emphasized,
      // Wraps the whole button, not just its icon child — a Listener
      // nested inside the FAB only sees pointer events that land on the
      // 28px icon, so most presses on the 56px button never set _pressed.
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onPressed();
          },
          tooltip: 'Log a transaction',
          child: const Icon(Icons.add_rounded, size: 28),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        // Without this the InkSparkle ripple splashes as a rectangle across the
        // whole nav item, escaping the rounded pill.
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The pill wraps the icon rather than sitting behind the whole
              // stack. Previously it was a fixed 56x28 box with a ~41px-tall
              // icon+label stack layered on top, so it rendered as a stripe
              // *through* the item instead of a container around it.
              AnimatedContainer(
                duration: AppMotion.quick,
                curve: AppMotion.standardCurve,
                width: 52,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? cs.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(height: Spacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall!.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
