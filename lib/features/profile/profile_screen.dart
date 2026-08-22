import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/notifications/streak_reminder_service.dart';
import '../../core/utils/badge_engine.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/xp_engine.dart';
import '../../providers/badge_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/xp_bar.dart';
import 'category_management_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final controller =
        TextEditingController(text: profile.monthlyBudget?.toStringAsFixed(0) ?? '');
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final updated = profile.copyWith(monthlyBudget: result);
    await ref.read(profileRepositoryProvider).save(updated);
    ref.read(profileProvider.notifier).setProfile(updated);
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    if (enabled) {
      final granted = await StreakReminderService.instance.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission was not granted.'),
            ),
          );
        }
        return;
      }
      await StreakReminderService.instance
          .scheduleTonightReminder(currentStreak: profile.currentStreak);
    } else {
      await StreakReminderService.instance.cancelToday();
    }

    final updated = profile.copyWith(remindersEnabled: enabled);
    await ref.read(profileRepositoryProvider).save(updated);
    ref.read(profileProvider.notifier).setProfile(updated);
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final transactions = ref.read(transactionsProvider);
    final path = await exportTransactionsToFile(transactions);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported to $path')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = levelProgressForXp(profile.currentXP);
    final unlockedBadgeCount = ref.watch(badgesProvider).length;
    final badgeCatalogSize = kBadgeCatalog.length;

    final semantics = context.semantics;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.all(Spacing.lg),
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: semantics.xp.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(profile.avatarId,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              SizedBox(width: Spacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                  Text('Level ${progress.level}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          SizedBox(height: Spacing.xl),
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: XpBar(progress: progress),
            ),
          ),
          SizedBox(height: Spacing.md),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text('Badges'),
                  subtitle: Text(
                    unlockedBadgeCount == 0
                        ? 'None yet — see the shelf on the Quests tab'
                        : '$unlockedBadgeCount of $badgeCatalogSize unlocked · see them on the Quests tab',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Monthly budget'),
                  subtitle: Text(profile.monthlyBudget != null
                      ? '₹${profile.monthlyBudget!.toStringAsFixed(0)}'
                      : 'Not set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editBudget(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Manage categories'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Streak reminders'),
                  subtitle: const Text(
                    "A nudge in the evening if you haven't logged yet",
                  ),
                  value: profile.remindersEnabled,
                  onChanged: (enabled) =>
                      _toggleReminders(context, ref, enabled),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export data (CSV)'),
                  subtitle: const Text('Also doubles as a local backup'),
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
