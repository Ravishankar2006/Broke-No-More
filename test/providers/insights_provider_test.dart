import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/insights_provider.dart';
import 'package:broke_no_more/providers/profile_provider.dart';
import 'package:broke_no_more/providers/recurring_transaction_provider.dart';
import 'package:broke_no_more/providers/transaction_provider.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Transaction _expense(String id, double amount, DateTime day, [String? cat]) {
  return Transaction(
    id: id,
    amount: amount,
    type: TransactionType.expense,
    category: cat ?? 'Food',
    timestamp: day,
    loggedAt: day,
    isQuickLog: true,
  );
}

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('insights_provider_test');
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
    await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<dynamic>(HiveBoxes.appState);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);

    container = ProviderContainer();
    await container
        .read(profileProvider.notifier)
        .createProfile(name: 'Test', avatarId: '🦊');
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('currentInsightsWindowProvider (month)', () {
    test(
      'bounds to the calendar month to date, not a rolling 30 days',
      () async {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final box = Hive.box<Transaction>(HiveBoxes.transactions);
        await box.put('t1', _expense('t1', 100, startOfMonth));
        // A day that's within the last rolling 30 days but before this
        // calendar month started (only reachable when today is early in
        // the month) would have leaked into the old 30-day window.
        if (startOfMonth.subtract(const Duration(days: 1)).month != now.month) {
          await box.put(
            't2',
            _expense('t2', 999, startOfMonth.subtract(const Duration(days: 1))),
          );
        }
        container.read(transactionsProvider.notifier).refresh();

        final window = container.read(
          currentInsightsWindowProvider(InsightsRange.month),
        );
        expect(window.start, startOfMonth);
        expect(window.total, 100);
      },
    );
  });

  group('previousInsightsWindowProvider (month)', () {
    test('is the full previous calendar month', () {
      final now = DateTime.now();
      final current = container.read(
        currentInsightsWindowProvider(InsightsRange.month),
      );
      final previous = container.read(
        previousInsightsWindowProvider(InsightsRange.month),
      );

      final expectedPrevStart = DateTime(now.year, now.month - 1, 1);
      final expectedPrevEnd = current.start.subtract(const Duration(days: 1));
      expect(previous.start, expectedPrevStart);
      expect(previous.end, expectedPrevEnd);
    });
  });

  group('monthBurnRateProjectionProvider', () {
    test('is null with nothing spent this month', () {
      expect(container.read(monthBurnRateProjectionProvider), isNull);
    });

    test('projects spend-to-date at its own daily average', () async {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final box = Hive.box<Transaction>(HiveBoxes.transactions);
      await box.put('t1', _expense('t1', 100, startOfMonth));
      container.read(transactionsProvider.notifier).refresh();

      final window = container.read(
        currentInsightsWindowProvider(InsightsRange.month),
      );
      final projection = container.read(monthBurnRateProjectionProvider);

      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      if (window.dayCount >= daysInMonth) {
        // Ran on the last day of the month — projection is intentionally
        // suppressed since there's nothing left to project.
        expect(projection, isNull);
      } else {
        final expected = (window.total / window.dayCount) * daysInMonth;
        expect(projection, closeTo(expected, 0.001));
      }
    });
  });

  group('currentInsightsWindowProvider (custom)', () {
    test('bounds to the picked range once one is set', () async {
      final box = Hive.box<Transaction>(HiveBoxes.transactions);
      await box.put('t1', _expense('t1', 100, DateTime(2026, 8, 5)));
      // Outside the picked range — must not count toward the total.
      await box.put('t2', _expense('t2', 999, DateTime(2026, 8, 20)));
      container.read(transactionsProvider.notifier).refresh();

      container
          .read(customInsightsRangeProvider.notifier)
          .set(
            DateTimeRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 10),
            ),
          );

      final window = container.read(
        currentInsightsWindowProvider(InsightsRange.custom),
      );
      expect(window.start, DateTime(2026, 8, 1));
      expect(window.end, DateTime(2026, 8, 10));
      expect(window.total, 100);
    });

    test('falls back to today when nothing has been picked yet', () {
      final today = DateTime.now();
      final window = container.read(
        currentInsightsWindowProvider(InsightsRange.custom),
      );
      expect(window.start, DateTime(today.year, today.month, today.day));
      expect(window.end, window.start);
    });

    test('has no previous-period comparison', () {
      container
          .read(customInsightsRangeProvider.notifier)
          .set(
            DateTimeRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 10),
            ),
          );
      final previous = container.read(
        previousInsightsWindowProvider(InsightsRange.custom),
      );
      expect(previous.expenses, isEmpty);
      expect(previous.income, isEmpty);
    });
  });

  group('recurringCommitmentForecastProvider', () {
    test(
      'sums remaining occurrences of active expense rules this month',
      () async {
        final now = DateTime.now();
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        final today = DateTime(now.year, now.month, now.day);

        final repo = container.read(recurringTransactionRepositoryProvider);
        await repo.add(
          amount: 500,
          type: TransactionType.expense,
          category: 'Rent',
          frequency: RecurrenceFrequency.monthly,
          startDate: today,
        );
        // Income rules shouldn't count toward a spending forecast.
        await repo.add(
          amount: 2000,
          type: TransactionType.income,
          category: 'Salary',
          frequency: RecurrenceFrequency.monthly,
          startDate: today,
        );
        container.read(recurringTransactionsProvider.notifier).refresh();

        final forecast = container.read(recurringCommitmentForecastProvider);
        // A monthly rule anchored today has exactly one occurrence left this
        // month (today itself) regardless of how many days remain.
        final expectedOccurrences = today.isAfter(monthEnd) ? 0 : 1;
        expect(forecast, 500.0 * expectedOccurrences);
      },
    );

    test('excludes paused rules', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final repo = container.read(recurringTransactionRepositoryProvider);
      final rule = await repo.add(
        amount: 500,
        type: TransactionType.expense,
        category: 'Rent',
        frequency: RecurrenceFrequency.monthly,
        startDate: today,
      );
      await repo.setActive(rule, false);
      container.read(recurringTransactionsProvider.notifier).refresh();

      expect(container.read(recurringCommitmentForecastProvider), 0);
    });
  });
}
