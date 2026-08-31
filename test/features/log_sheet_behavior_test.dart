import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/log_transaction/log_transaction_sheet.dart';
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

/// Covers Phase 3.4's log-sheet additions: the amount input formatter, the
/// quick-amount chips, "save and add another", and the recent-category
/// shortcut row.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('log_sheet_behavior_test');
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
    await Hive.openBox<Transaction>(HiveBoxes.transactions);
    final profiles = await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    final categories = await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    await categories.add(
      CategoryRecord(
        id: 'e0',
        name: 'Food',
        iconId: 'restaurant',
        type: TransactionType.expense,
        sortOrder: 0,
      ),
    );
    await categories.add(
      CategoryRecord(
        id: 'e1',
        name: 'Transport',
        iconId: 'transport',
        type: TransactionType.expense,
        sortOrder: 1,
      ),
    );

    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        name: 'Test',
        avatarId: '🦊',
        joinDate: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: LogTransactionSheet()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('the amount field rejects a string with two decimal points', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, '12.34.56');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isNot('12.34.56'));
  });

  testWidgets('a valid two-decimal amount is accepted as-is', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, '12.34');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '12.34');
  });

  testWidgets('tapping a quick-amount chip fills the amount field', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('₹100'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '100');
  });

  testWidgets('"Save & add another" resets the form and keeps the sheet open', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, '50');
    await tester.tap(find.text('Food').first);
    await tester.pump();
    // An unfocused field stops the cursor-blink timer from scheduling
    // frames forever, and the tap below goes through real Hive I/O — same
    // combination widget_test.dart's onboarding test needs for the same
    // reason.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Save & add another'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Still on the log sheet, not popped.
    expect(find.byType(LogTransactionSheet), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
    // No category selected — the grid must show the "Pick one" prompt
    // again if submitted a second time without reselecting.
    await tester.tap(find.text('Save & add another'));
    await tester.pump();
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets(
    'a category used in a prior transaction appears in the recent-category '
    'shortcut row',
    (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() async {
        final box = Hive.box<Transaction>(HiveBoxes.transactions);
        await box.put(
          't1',
          Transaction(
            id: 't1',
            amount: 20,
            type: TransactionType.expense,
            category: 'Transport',
            timestamp: now,
            loggedAt: now,
            isQuickLog: true,
          ),
        );
      });

      await pumpSheet(tester);

      // Appears twice: once in the recent-shortcut row, once in the grid.
      expect(find.text('Transport'), findsNWidgets(2));
    },
  );
}
