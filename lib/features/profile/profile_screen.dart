import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/app_avatar.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/celebration_sequence.dart';
import '../../shared_widgets/section_header.dart';
import '../../shared_widgets/skeleton.dart';
import '../../shared_widgets/stat_tile.dart';
import '../../shared_widgets/xp_bar.dart';
import '../transactions/transaction_history_screen.dart';
import 'category_management_screen.dart';
import 'recurring_transactions_screen.dart';
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
    final recurringCount = ref
        .watch(recurringTransactionsProvider)
        .where((r) => r.isActive)
        .length;

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
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.autorenew_rounded,
                        title: 'Recurring transactions',
                        subtitle: recurringCount == 0
                            ? 'None set up'
                            : '$recurringCount active',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecurringTransactionsScreen(),
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
                      _SettingsTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Appearance',
                        subtitle: _themeModeLabel(themeMode),
                        onTap: () => _editThemeMode(context, ref, themeMode),
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
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.ios_share_outlined,
                        title: 'Export as CSV',
                        subtitle: 'Share a backup of every transaction',
                        onTap: () => _exportCsv(context, ref),
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.upload_file_outlined,
                        title: 'Import from CSV',
                        subtitle: 'Restore or merge from a backup file',
                        onTap: () => _importCsv(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => _ThemeModeDialog(current: current),
    );
    if (result == null) return;
    await ref.read(themeModeProvider.notifier).setMode(result);
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // A record, not a bare `double?` — the dialog needs to say "clear it"
    // distinctly from "cancelled", and a popped `null` already means the
    // latter. Owned by the dialog widget so it's disposed with it.
    final result = await showDialog<({bool clear, double? value})>(
      context: context,
      builder: (context) => _BudgetDialog(initial: profile.monthlyBudget),
    );
    if (result == null) return;

    // Goes through the orchestrator, not a direct repo save — the budget
    // bonus, daysUnderBudgetCount and the Budget Boss badge all depend on
    // this value and need recomputing now, not on the next transaction.
    await ref
        .read(xpEngineOrchestratorProvider)
        .updateMonthlyBudget(result.clear ? null : result.value);
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
    try {
      // Hands the file to the OS share sheet — writing it to app-private
      // documents storage alone (the old behaviour) left the user with a
      // path they could never actually open on Android.
      await shareTransactionsCsv(transactions);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't export — please try again.")),
      );
    }
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the file picker.")),
      );
      return;
    }
    if (file == null || !context.mounted) return; // user cancelled

    final String content;
    try {
      content = utf8.decode(await file.readAsBytes());
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't read that file.")),
      );
      return;
    }

    final parsed = parseTransactionsCsv(content);
    if (parsed.transactions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parsed.errors.isEmpty
                ? 'No transactions found in that file.'
                : "Couldn't read any rows: ${parsed.errors.first}",
          ),
        ),
      );
      return;
    }

    // Split into rows that write cleanly and rows whose id already exists on
    // this device with *different* content — an identical row (the common
    // case of re-importing the same backup) is safe to overwrite silently
    // and isn't worth asking about.
    final existingById = {
      for (final t in ref.read(transactionsProvider)) t.id: t,
    };
    final toWrite = <Transaction>[];
    final conflicts = <_ImportConflict>[];
    for (final t in parsed.transactions) {
      final existing = existingById[t.id];
      if (existing == null || _sameContent(existing, t)) {
        toWrite.add(t);
      } else {
        conflicts.add(_ImportConflict(existing: existing, imported: t));
      }
    }

    if (conflicts.isNotEmpty) {
      if (!context.mounted) return;
      final resolved = await showDialog<List<Transaction>>(
        context: context,
        builder: (context) => _ImportConflictDialog(conflicts: conflicts),
      );
      if (resolved == null) return; // user cancelled the whole import
      toWrite.addAll(resolved);
    }

    if (toWrite.isEmpty) return; // every conflict was resolved as "keep existing"
    if (!context.mounted) return;

    try {
      final result =
          await ref.read(xpEngineOrchestratorProvider).importTransactions(toWrite);
      if (!context.mounted) return;

      final skipped = parsed.errors.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipped == 0
                ? 'Imported ${result.importedCount} transaction(s).'
                : 'Imported ${result.importedCount} transaction(s), '
                    'skipped $skipped row(s) with errors.',
          ),
        ),
      );

      await showGamificationCelebrations(
        context,
        xpGained: result.xpGained,
        completedQuests: result.completedQuests,
        leveledUpTo: result.leveledUpTo,
        newlyUnlockedBadges: result.newlyUnlockedBadges,
        totalBadgesUnlocked: ref.read(badgesProvider).length,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't import — please try again.")),
      );
    }
  }
}

/// Whether [a] and [b] represent the same transaction content — used to tell
/// a genuine edit conflict apart from re-importing an unchanged row.
bool _sameContent(Transaction a, Transaction b) {
  return a.amount == b.amount &&
      a.type == b.type &&
      a.category == b.category &&
      a.note == b.note &&
      a.timestamp.isAtSameMomentAs(b.timestamp);
}

class _ImportConflict {
  const _ImportConflict({required this.existing, required this.imported});

  final Transaction existing;
  final Transaction imported;
}

/// Lets the user resolve, per row, an imported transaction whose id already
/// exists on the device with different content. Defaults every row to
/// "keep existing" — the non-destructive choice for a conflict the user
/// hasn't looked at yet.
class _ImportConflictDialog extends StatefulWidget {
  const _ImportConflictDialog({required this.conflicts});

  final List<_ImportConflict> conflicts;

  @override
  State<_ImportConflictDialog> createState() => _ImportConflictDialogState();
}

class _ImportConflictDialogState extends State<_ImportConflictDialog> {
  late final List<bool> _useImported =
      List<bool>.filled(widget.conflicts.length, false);
  final _dateFormat = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('${widget.conflicts.length} conflicting transaction(s)'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These rows already exist on this device with different '
              'details. Choose which version to keep for each.',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: Spacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: Spacing.lg),
                itemBuilder: (context, i) {
                  final conflict = widget.conflicts[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.existing.category,
                        style: theme.textTheme.titleSmall,
                      ),
                      SizedBox(height: Spacing.xxs),
                      Text(
                        'On device: ${formatCurrency(conflict.existing.amount)}'
                        ' · ${_dateFormat.format(conflict.existing.timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Imported: ${formatCurrency(conflict.imported.amount)}'
                        ' · ${_dateFormat.format(conflict.imported.timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(height: Spacing.xs),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Keep existing'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Use imported'),
                          ),
                        ],
                        selected: {_useImported[i]},
                        onSelectionChanged: (selection) =>
                            setState(() => _useImported[i] = selection.first),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel import'),
        ),
        FilledButton(
          onPressed: () {
            final resolved = [
              for (var i = 0; i < widget.conflicts.length; i++)
                if (_useImported[i]) widget.conflicts[i].imported,
            ];
            Navigator.of(context).pop(resolved);
          },
          child: const Text('Import'),
        ),
      ],
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

String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _ThemeModeDialog extends StatelessWidget {
  const _ThemeModeDialog({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Appearance'),
      content: RadioGroup<ThemeMode>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(_themeModeLabel(mode)),
                value: mode,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
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
    Navigator.of(context).pop((clear: false, value: value));
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
        // Only offered once a budget actually exists — clearing an unset
        // budget isn't a meaningful action.
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((clear: true, value: null)),
            child: const Text('Clear'),
          ),
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
