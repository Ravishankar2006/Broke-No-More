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

/// Covers Phase 3.4's History additions: category filter, sort control
/// (including the switch to a flat non-grouped layout for amount sorts),
/// multi-select bulk delete, and delete-with-undo.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_power_test');
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
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

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

  // Seeding must happen inside `runAsync`, before `pumpWidget` — real Hive
  // I/O started directly in a test body (as opposed to `setUp`, which runs
  // fine) corrupts flutter_test's fake-async harness otherwise, hanging
  // the whole run rather than failing. Same class of issue documented for
  // the (since-deleted) repair_scheduler_test.dart.
  Future<void> pump(WidgetTester tester, List<Transaction> seed) async {
    await tester.runAsync(() async {
      final box = Hive.box<Transaction>(HiveBoxes.transactions);
      for (final t in seed) {
        await box.put(t.id, t);
      }
    });
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

  Transaction expense(
    String id,
    double amount,
    String category,
    DateTime timestamp,
  ) {
    return Transaction(
      id: id,
      amount: amount,
      type: TransactionType.expense,
      category: category,
      timestamp: timestamp,
      loggedAt: DateTime.now(),
      isQuickLog: true,
    );
  }

  testWidgets('category filter narrows the list to just that category', (
    tester,
  ) async {
    final now = DateTime.now();
    await pump(tester, [
      expense('t1', 80, 'Food', now),
      expense('t2', 40, 'Transport', now),
    ]);
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(ListTile, 'Food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Transport'), findsNothing);
  });

  testWidgets(
    'sorting by highest amount switches to a flat list ordered by amount',
    (tester) async {
      final now = DateTime.now();
      await pump(tester, [
        expense('small', 10, 'Food', now),
        expense('big', 900, 'Rent', now.subtract(const Duration(days: 3))),
      ]);
      // Chronological order: today's "Food" day-group renders above the
      // 3-day-old "Rent" one.
      expect(
        tester.getTopLeft(find.text('Food')).dy,
        lessThan(tester.getTopLeft(find.text('Rent')).dy),
      );

      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Highest amount'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Day headers ("TODAY" etc.) are gone — this is now a flat list — and
      // the bigger amount sorts above the smaller one regardless of date.
      expect(find.text('TODAY'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Rent')).dy,
        lessThan(tester.getTopLeft(find.text('Food')).dy),
      );
    },
  );

  testWidgets(
    'long-press enters selection mode; bulk delete removes the selected '
    'rows and Undo brings them back',
    (tester) async {
      final now = DateTime.now();
      await pump(tester, [
        expense('t1', 80, 'Food', now),
        expense('t2', 40, 'Transport', now),
      ]);

      await tester.longPress(find.text('Food'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.select_all_rounded));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();
        // Confirm dialog.
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      // Lets the "N deleted" SnackBar finish animating in before the next
      // block tries to tap its Undo action.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Food'), findsNothing);
      expect(find.text('Transport'), findsNothing);
      expect(find.text('History'), findsOneWidget); // back to the plain title

      await tester.runAsync(() async {
        await tester.tap(find.text('Undo'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
    },
  );

  testWidgets(
    'a single-item selection delete offers an Undo that restores the row',
    (tester) async {
      // Driving the Dismissible's swipe gesture reliably through
      // flutter_test's synthetic pointer events is its own can of worms —
      // this goes through the long-press → select → delete path instead,
      // which lands on the same `deleteTransactions`/`restoreTransactions`
      // orchestrator calls and the same snackbar-with-Undo UI.
      final now = DateTime.now();
      await pump(tester, [expense('t1', 80, 'Food', now)]);

      await tester.longPress(find.text('Food'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Food'), findsNothing);

      await tester.runAsync(() async {
        await tester.tap(find.text('Undo'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Food'), findsOneWidget);
    },
  );
}
