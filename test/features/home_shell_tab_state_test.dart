import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/home/home_shell.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/insights_provider.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// `HomeShell` used to rebuild the outgoing tab from scratch on every
/// switch (`AnimatedSwitcher` + `KeyedSubtree`), so any screen-local state —
/// Insights' range selector included — silently reset. Moving to
/// `IndexedStack` (see `home_shell.dart`) is meant to fix exactly this.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('home_shell_tab_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionTypeAdapter());
      Hive.registerAdapter(TransactionAdapter());
      Hive.registerAdapter(UserProfileAdapter());
      Hive.registerAdapter(QuestTypeAdapter());
      Hive.registerAdapter(QuestStatusAdapter());
      Hive.registerAdapter(QuestAdapter());
      Hive.registerAdapter(BadgeAdapter());
      Hive.registerAdapter(CategoryRecordAdapter());
      Hive.registerAdapter(RecurrenceFrequencyAdapter());
      Hive.registerAdapter(RecurringTransactionAdapter());
    }
    final transactions = await Hive.openBox<Transaction>(
      HiveBoxes.transactions,
    );
    final profiles = await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        name: 'Test',
        avatarId: '🦊',
        joinDate: DateTime.now(),
      ),
    );
    // Insights shows an empty state (no range selector at all) with no
    // transactions logged, so this needs at least one for the selector
    // this test asserts on to render.
    final now = DateTime.now();
    await transactions.put(
      't1',
      Transaction(
        id: 't1',
        amount: 50,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: now,
        loggedAt: now,
        isQuickLog: true,
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    "switching away from Insights and back keeps the range selector on "
    "the user's choice instead of resetting to Week",
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light, home: const HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Home is the default tab — go to Insights.
      await tester.tap(find.text('Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Week'), findsOneWidget);
      await tester.tap(find.text('Month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Switch to Profile, then back to Insights.
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final segmented = tester.widget<SegmentedButton<InsightsRange>>(
        find.byType(SegmentedButton<InsightsRange>),
      );
      expect(
        segmented.selected.single,
        InsightsRange.month,
        reason:
            'the range selector must still read Month, not have reset '
            'to Week when the tab was rebuilt',
      );
    },
  );
}
