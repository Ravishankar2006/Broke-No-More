import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/hive_boxes.dart';
import '../../core/notifications/streak_reminder_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/currency_catalog.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/xp_engine.dart';
import '../../data/backup_repository.dart';
import '../../models/transaction.dart';
import '../../providers/badge_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/celebration_sequence.dart';
import '../../shared_widgets/section_header.dart';
import '../../shared_widgets/skeleton.dart';
import '../../shared_widgets/xp_bar.dart';
import '../transactions/transaction_history_screen.dart';
import 'about_screen.dart';
import 'category_management_screen.dart';
import 'edit_profile_sheet.dart';
import 'recurring_transactions_screen.dart';
import 'widgets/budget_dialog.dart';
import 'widgets/csv_import_conflict_dialog.dart';
import 'widgets/currency_dialog.dart';
import 'widgets/profile_header.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/stats_grid.dart';
import 'widgets/theme_mode_dialog.dart';

/// The avatar choices offered at onboarding and when editing a profile.
const List<String> kAvatarChoices = ['🦊', '🐼', '🐨', '🐸', '🦉', '🐢'];

enum _ExportChoice { allTime, chooseRange }

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
              const SizedBox(width: Spacing.sm),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                ProfileHeader(profile: profile, progress: progress),
                const SizedBox(height: Spacing.md),
                AppCard(child: XpBar(progress: progress)),
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'Stats'),
                StatsGrid(
                  profile: profile,
                  transactionCount: transactions.length,
                  activeDays: ref.watch(loggedDaysProvider).length,
                  totalSpent: ref.watch(totalSpentProvider),
                  badgeCount: unlockedBadgeCount,
                ),
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'Your money'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Transaction history',
                        subtitle: '${transactions.length} logged',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TransactionHistoryScreen(),
                          ),
                        ),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Monthly budget',
                        subtitle: profile.monthlyBudget != null
                            ? formatCurrency(
                                profile.monthlyBudget!,
                                currencyCode: profile.currencyCode,
                              )
                            : 'Not set',
                        onTap: () => _editBudget(context, ref),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.currency_exchange_outlined,
                        title: 'Currency',
                        subtitle:
                            '${profile.currencyCode} '
                            '(${currencyInfoFor(profile.currencyCode).symbol})',
                        onTap: () => _editCurrency(context, ref),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.category_outlined,
                        title: 'Manage categories',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CategoryManagementScreen(),
                          ),
                        ),
                      ),
                      const TileDivider(),
                      SettingsTile(
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
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'Preferences'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Appearance',
                        subtitle: themeModeLabel(themeMode),
                        onTap: () => _editThemeMode(context, ref, themeMode),
                      ),
                      const TileDivider(),
                      SwitchTile(
                        icon: Icons.notifications_outlined,
                        title: 'Streak reminders',
                        subtitle:
                            "A nudge in the evening if you haven't logged",
                        value: profile.remindersEnabled,
                        onChanged: (value) =>
                            _toggleReminders(context, ref, value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'Data'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.ios_share_outlined,
                        title: 'Export as CSV',
                        subtitle: 'Share a backup of every transaction',
                        onTap: () => _exportCsv(context, ref),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.upload_file_outlined,
                        title: 'Import from CSV',
                        subtitle: 'Restore or merge from a backup file',
                        onTap: () => _importCsv(context, ref),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.save_outlined,
                        title: 'Full backup',
                        subtitle:
                            'Everything — XP, streak, quests, badges, '
                            'categories and recurring rules',
                        onTap: () => _exportJsonBackup(context, ref),
                      ),
                      const TileDivider(),
                      SettingsTile(
                        icon: Icons.settings_backup_restore_outlined,
                        title: 'Restore from backup',
                        subtitle:
                            'Replaces everything currently on this device',
                        onTap: () => _importJsonBackup(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'About'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: SettingsTile(
                    icon: Icons.info_outline,
                    title: 'About Broke No More',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutAppScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                const SectionHeader(title: 'Danger zone'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Reset app',
                    subtitle: 'Erase everything on this device',
                    onTap: () => _resetApp(context, ref),
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
      builder: (context) => ThemeModeDialog(current: current),
    );
    if (result == null) return;
    await ref.read(themeModeProvider.notifier).setMode(result);
  }

  Future<void> _editCurrency(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => CurrencyDialog(current: profile.currencyCode),
    );
    if (result == null || result == profile.currencyCode) return;

    // A display setting only — it doesn't feed XP/streak/quest math, so this
    // goes straight through the repository like name/avatar edits, not the
    // orchestrator (reserved for actions that affect gamification state).
    try {
      final updated = profile.copyWith(currencyCode: result);
      await ref.read(profileRepositoryProvider).save(updated);
      ref.read(profileProvider.notifier).setProfile(updated);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't update currency — please try again."),
        ),
      );
    }
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // A record, not a bare `double?` — the dialog needs to say "clear it"
    // distinctly from "cancelled", and a popped `null` already means the
    // latter. Owned by the dialog widget so it's disposed with it.
    final result = await showDialog<({bool clear, double? value})>(
      context: context,
      builder: (context) => BudgetDialog(
        initial: profile.monthlyBudget,
        currencySymbol: currencyInfoFor(profile.currencyCode).symbol,
      ),
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
      await StreakReminderService.instance.scheduleTonightReminder(
        currentStreak: profile.currentStreak,
      );
    } else {
      await StreakReminderService.instance.cancelToday();
    }

    final updated = profile.copyWith(remindersEnabled: enabled);
    await ref.read(profileRepositoryProvider).save(updated);
    ref.read(profileProvider.notifier).setProfile(updated);
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final transactions = ref.read(transactionsProvider);
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export yet.')));
      return;
    }

    final choice = await showDialog<_ExportChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export as CSV'),
        content: const Text('Export everything, or just a date range?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ExportChoice.chooseRange),
            child: const Text('Choose range'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExportChoice.allTime),
            child: const Text('All time'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    var toExport = transactions;
    if (choice == _ExportChoice.chooseRange) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
      );
      if (range == null || !context.mounted) return;
      toExport = transactions
          .where((t) {
            final day = startOfDay(t.timestamp);
            return !day.isBefore(range.start) && !day.isAfter(range.end);
          })
          .toList(growable: false);
      if (toExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions in that range.')),
        );
        return;
      }
    }

    try {
      // Hands the file to the OS share sheet — writing it to app-private
      // documents storage alone (the old behaviour) left the user with a
      // path they could never actually open on Android.
      await shareTransactionsCsv(toExport);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't read that file.")));
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
    final conflicts = <ImportConflict>[];
    for (final t in parsed.transactions) {
      final existing = existingById[t.id];
      if (existing == null || sameTransactionContent(existing, t)) {
        toWrite.add(t);
      } else {
        conflicts.add(ImportConflict(existing: existing, imported: t));
      }
    }

    if (conflicts.isNotEmpty) {
      if (!context.mounted) return;
      final resolved = await showDialog<List<Transaction>>(
        context: context,
        builder: (context) => ImportConflictDialog(
          conflicts: conflicts,
          currencyCode: ref.read(currentCurrencyCodeProvider),
        ),
      );
      if (resolved == null) return; // user cancelled the whole import
      toWrite.addAll(resolved);
    }

    if (toWrite.isEmpty) {
      return; // every conflict was resolved as "keep existing"
    }
    if (!context.mounted) return;

    try {
      final result = await ref
          .read(xpEngineOrchestratorProvider)
          .importTransactions(toWrite);
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

  Future<void> _exportJsonBackup(BuildContext context, WidgetRef ref) async {
    try {
      final json = buildBackupJson();
      await shareBackupFile(json);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't create a backup — please try again."),
        ),
      );
    }
  }

  Future<void> _importJsonBackup(BuildContext context, WidgetRef ref) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the file picker.")),
      );
      return;
    }
    if (file == null || !context.mounted) return; // user cancelled

    final BackupData data;
    try {
      final content = utf8.decode(await file.readAsBytes());
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Not a valid backup file');
      }
      data = backupFromJson(json);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't read that backup: $e")));
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: Text(
          'This replaces everything currently on this device — profile, '
          '${data.transactions.length} transaction(s), XP, streak, quests, '
          'badges, categories and recurring rules — with what\'s in this '
          'backup, made ${_formatBackupDate(data.exportedAt)}. This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await restoreBackup(data);
      _invalidateEverything(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup restored.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't restore — please try again.")),
      );
    }
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently erases everything on this device — your '
              'profile, every transaction, quests, badges, categories, '
              'recurring rules and settings. There is no undo unless you '
              'have a backup.\n\nType RESET to confirm.',
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'RESET'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: textController,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim() == 'RESET'
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Erase everything'),
            ),
          ),
        ],
      ),
    );
    textController.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await resetAllData();
      _invalidateEverything(ref);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reset — please try again.")),
      );
    }
  }

  /// Both a full restore and a reset replace the contents of every box at
  /// once — the providers backing every screen need to re-read from disk
  /// rather than keep serving whatever they cached from before.
  void _invalidateEverything(WidgetRef ref) {
    ref.invalidate(profileProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(questsProvider);
    ref.invalidate(badgesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(incomeCategoriesProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(skippedQuestsProvider);
  }

  static String _formatBackupDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
