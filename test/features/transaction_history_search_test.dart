import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
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

/// The search field's `onChanged` debounces the underlying filter (see
/// `transaction_history_screen.dart`) so fast typing on a large history
/// doesn't re-filter+regroup on every keystroke. Covers the behaviour that
/// makes real: results don't change until the debounce window elapses, and
/// the clear button both appears instantly and resets instantly.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_search_test');
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
    await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    final now = DateTime.now();
    await transactions.put(
      't1',
      Transaction(
        id: 't1',
        amount: 80,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: now,
        loggedAt: now,
        isQuickLog: true,
      ),
    );
    await transactions.put(
      't2',
      Transaction(
        id: 't2',
        amount: 40,
        type: TransactionType.expense,
        category: 'Transport',
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('both rows show before typing', (tester) async {
    await pump(tester);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets(
    'results stay unfiltered immediately after typing, then narrow once '
    'the debounce window elapses',
    (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'food');
      // Only one frame — the debounce timer hasn't fired yet.
      await tester.pump();

      expect(
        find.text('Transport'),
        findsOneWidget,
        reason: 'filtering must not happen synchronously on keystroke',
      );

      // Past the 200ms debounce window.
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsNothing);
    },
  );

  testWidgets('the clear button appears instantly and resets instantly', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'food');
    await tester.pump();
    // No debounce wait — the clear button is driven by the controller, not
    // the debounced query.
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });
}
