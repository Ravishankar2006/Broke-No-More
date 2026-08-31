import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/insights/insights_screen.dart';
import 'package:broke_no_more/features/transactions/transaction_history_screen.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers two Phase 3.2 additions: tapping a category in the Insights
/// breakdown should open History pre-filtered to it (there was previously
/// no way to drill from a category slice into its transactions), and an
/// active quest targeting a category should be visible right there instead
/// of Insights staying entirely disconnected from the gamification layer.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('insights_drilldown_test');
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
    final quests = await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    final now = DateTime.now();
    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        name: 'Test',
        avatarId: '🦊',
        joinDate: now.subtract(const Duration(days: 10)),
      ),
    );
    await transactions.put(
      't1',
      Transaction(
        id: 't1',
        amount: 250,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: now,
        loggedAt: now,
        isQuickLog: true,
      ),
    );
    await quests.put(
      'q1',
      Quest(
        id: 'q1',
        title: 'Spend under 500 on Food this week',
        type: QuestType.budgetLimit,
        targetValue: 500,
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        xpReward: 50,
        category: 'Food',
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'tapping a category legend row opens History pre-filtered to it',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const InsightsScreen(),
          ),
        ),
      );
      // Default 800x600 test surface leaves the category legend below the
      // fold with the new gamification strip and month-outlook card above
      // it — grow it rather than fight the scroll view.
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionHistoryScreen), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, 'Food');
    },
  );

  testWidgets('a category targeted by an active quest shows the quest flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const InsightsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
  });
}
