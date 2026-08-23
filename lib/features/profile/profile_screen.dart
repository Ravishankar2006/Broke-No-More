import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/streak_reminder_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/badge_engine.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/xp_engine.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';
import '../../providers/badge_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/app_avatar.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/section_header.dart';
import '../../shared_widgets/skeleton.dart';
import '../../shared_widgets/stat_tile.dart';
import '../../shared_widgets/xp_bar.dart';
import '../transactions/transaction_history_screen.dart';
import 'category_management_screen.dart';
import 'edit_profile_sheet.dart';

/// The avatar choices offered at onboarding and when editing a profile.
const List<String> kAvatarChoices = ['🦊', '🐼', '🐨', '🐸', '🦉', '🐢'];

/// Identity, stats and settings.
///
/// Was a settings list wearing the Profile hat: six undifferentiated ListTiles
/// in one card, no stats beyond level and badge count, no way to change the
/// name or avatar chosen at onboarding, and a "Badges" row that looked tappable
/// but wasn't — its subtitle told the user to navigate somewhere else by hand.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final transactions = ref.watch(transactionsProvider);

    if (profile == null) {
      return const Scaffold(body: SkeletonScreen());
    }

    final progress = levelProgressForXp(profile.currentXP);
    final unlockedBadgeCount = ref.watch(badgesProvider).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Profile'),
            titleSpacing: Spacing.lg,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profile',
                onPressed: () => showEditProfileSheet(context, ref),
              ),
              SizedBox(width: Spacing.sm),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                _ProfileHeader(profile: profile, progress: progress),
                SizedBox(height: Spacing.md),
                AppCard(child: XpBar(progress: progress)),
                SizedBox(height: Spacing.xl),

                SectionHeader(title: 'Stats'),
                _StatsGrid(
                  profile: profile,
                  transactions: transactions,
                  badgeCount: unlockedBadgeCount,
                ),
                SizedBox(height: Spacing.xl),

                SectionHeader(title: 'Your money'),
                AppCard(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Transaction history',
                        subtitle: '${transactions.length} logged',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TransactionHistoryScreen(),
                          ),
                        ),
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Monthly budget',
                        subtitle: profile.monthlyBudget != null
                            ? formatCurrency(profile.monthlyBudget!)
                            : 'Not set',
                        onTap: () => _editBudget(context, ref),
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.category_outlined,
                        title: 'Manage categories',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CategoryManagementScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),

                SectionHeader(title: 'Preferences'),
                AppCard(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Column(
                    children: [
                      _SwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        value: themeMode == ThemeMode.dark,
                        onChanged: (value) => ref
                            .read(themeModeProvider.notifier)
                            .setDark(value),
                      ),
                      const _TileDivider(),
                      _SwitchTile(
                        icon: Icons.notifications_outlined,
                        title: 'Streak reminders',
                        subtitle: "A nudge in the evening if you haven't logged",
                        value: profile.remindersEnabled,
                        onChanged: (value) =>
                            _toggleReminders(context, ref, value),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),

                SectionHeader(title: 'Data'),
                AppCard(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: _SettingsTile(
                    icon: Icons.download_outlined,
                    title: 'Export as CSV',
                    subtitle: 'Doubles as a local backup',
                    onTap: () => _exportCsv(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // Owned by the dialog widget so it's disposed with it — the previous
    // version created a controller per invocation and never disposed it.
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => _BudgetDialog(initial: profile.monthlyBudget),
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

    // A raw filesystem path in a SnackBar was the whole previous feedback.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline),
        title: const Text('Export complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${transactions.length} transactions saved to:'),
            SizedBox(height: Spacing.sm),
            SelectableText(
              path,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.progress});

  final UserProfile profile;
  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return AppCard.hero(
      gradient: AppGradients.brand(theme.brightness),
      child: Row(
        children: [
          AppAvatar(emoji: profile.avatarId, size: 72),
          SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: semantics.xp,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Level ${progress.level}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantics.onGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Since ${_monthYear(profile.joinDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

/// The numbers a gamified app should be proud of, none of which the screen
/// showed before.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.profile,
    required this.transactions,
    required this.badgeCount,
  });

  final UserProfile profile;
  final List<Transaction> transactions;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final totalLogged = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final activeDays =
        transactions.map((t) => startOfDay(t.timestamp)).toSet().length;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  value: '${transactions.length}',
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Active days',
                  value: '$activeDays',
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Longest streak',
                  value: '${profile.longestStreak}',
                  caption: 'Now: ${profile.currentStreak}',
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Badges',
                  value: '$badgeCount of ${kBadgeCatalog.length}',
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Total spent',
                  value: formatCurrency(totalLogged),
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.bolt_outlined,
                  label: 'Total XP',
                  value: '${profile.currentXP}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.initial});

  final double? initial;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toStringAsFixed(0) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    // The old dialog silently closed on unparseable input, discarding the edit
    // with no explanation.
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your daily allowance is this divided by the days in the month.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: Spacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              hintText: 'e.g. 8000',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: Spacing.lg + 36 + Spacing.lg);
  }
}
