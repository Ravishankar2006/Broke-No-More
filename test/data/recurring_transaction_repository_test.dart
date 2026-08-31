import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/data/recurring_transaction_repository.dart';
import 'package:broke_no_more/data/transaction_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers RecurringTransactionRepository.materializeDue — the boot-time
/// checkpoint that turns due rules into real transactions, mirroring the
/// same real-dart:io Hive harness used for the other repository-adjacent
/// tests in this suite.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'recurring_transaction_test',
    );
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
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test(
    'a due rule materializes into a real transaction and advances',
    () async {
      final repo = RecurringTransactionRepository();
      await repo.add(
        amount: 500,
        type: TransactionType.expense,
        category: 'Subscriptions',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 8, 1),
      );

      await repo.materializeDue(now: DateTime(2026, 8, 1));

      final transactions = TransactionRepository().getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.amount, 500);
      expect(transactions.single.category, 'Subscriptions');
      expect(transactions.single.isQuickLog, isFalse);

      final rule = repo.getAll().single;
      expect(rule.nextDueDate, DateTime(2026, 9, 1));
    },
  );

  test('a rule not yet due materializes nothing', () async {
    final repo = RecurringTransactionRepository();
    await repo.add(
      amount: 500,
      type: TransactionType.expense,
      category: 'Subscriptions',
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 9, 1),
    );

    await repo.materializeDue(now: DateTime(2026, 8, 15));

    expect(TransactionRepository().getAll(), isEmpty);
  });

  test('a paused rule is skipped entirely', () async {
    final repo = RecurringTransactionRepository();
    final rule = await repo.add(
      amount: 500,
      type: TransactionType.expense,
      category: 'Subscriptions',
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 8, 1),
    );
    await repo.setActive(rule, false);

    await repo.materializeDue(now: DateTime(2026, 9, 1));

    expect(TransactionRepository().getAll(), isEmpty);
    // The cursor doesn't move either — resuming later shouldn't have
    // skipped whatever was due while paused.
    expect(repo.getAll().single.nextDueDate, DateTime(2026, 8, 1));
  });

  test('reaching endDate auto-deactivates the rule', () async {
    final repo = RecurringTransactionRepository();
    await repo.add(
      amount: 500,
      type: TransactionType.expense,
      category: 'Subscriptions',
      frequency: RecurrenceFrequency.weekly,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 8),
    );

    await repo.materializeDue(now: DateTime(2026, 9, 1));

    expect(TransactionRepository().getAll(), hasLength(2)); // 8/1 and 8/8
    expect(repo.getAll().single.isActive, isFalse);
  });

  test('a second pass on the same day materializes nothing new', () async {
    final repo = RecurringTransactionRepository();
    await repo.add(
      amount: 500,
      type: TransactionType.expense,
      category: 'Subscriptions',
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 8, 1),
    );

    await repo.materializeDue(now: DateTime(2026, 8, 1));
    await repo.materializeDue(now: DateTime(2026, 8, 1));

    expect(TransactionRepository().getAll(), hasLength(1));
  });

  group('renameCategory', () {
    test(
      'rewrites every rule under the old name, leaves others alone',
      () async {
        final repo = RecurringTransactionRepository();
        final rent = await repo.add(
          amount: 15000,
          type: TransactionType.expense,
          category: 'Rent',
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2026, 8, 1),
        );
        final gym = await repo.add(
          amount: 1000,
          type: TransactionType.expense,
          category: 'Gym',
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2026, 8, 1),
        );

        final touched = await repo.renameCategory('Rent', 'Housing');

        expect(touched, 1);
        expect(
          repo.getAll().firstWhere((r) => r.id == rent.id).category,
          'Housing',
        );
        expect(repo.getAll().firstWhere((r) => r.id == gym.id).category, 'Gym');
      },
    );

    test('countForCategory matches renameCategory\'s own count', () async {
      final repo = RecurringTransactionRepository();
      await repo.add(
        amount: 15000,
        type: TransactionType.expense,
        category: 'Rent',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 8, 1),
      );

      expect(repo.countForCategory('Rent'), 1);
      final touched = await repo.renameCategory('Rent', 'Housing');
      expect(touched, 1);
      expect(repo.countForCategory('Rent'), 0);
      expect(repo.countForCategory('Housing'), 1);
    });
  });
}
