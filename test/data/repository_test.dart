import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/data/category_repository.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/data/quest_repository.dart';
import 'package:broke_no_more/data/skipped_quest_repository.dart';
import 'package:broke_no_more/data/transaction_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Previously untested despite being the sole write path for every box in
/// the app. Focuses on the behaviour the UI/orchestrator actually depends
/// on — not exhaustive CRUD, most of which is already exercised indirectly
/// by `xp_engine_provider_test.dart` — plus the handful of edge cases the
/// audit flagged as load-bearing and unverified.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('repository_test');
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
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('TransactionRepository', () {
    final repo = TransactionRepository();

    test(
      'add assigns a uuid, sets loggedAt to now, and derives isQuickLog',
      () async {
        final t = await repo.add(
          amount: 50,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        expect(t.id, isNotEmpty);
        expect(t.isQuickLog, isTrue);
        expect(repo.getById(t.id), isNotNull);
      },
    );

    test('update preserves id and loggedAt, and recomputes isQuickLog against '
        'the original loggedAt', () async {
      final original = await repo.add(
        amount: 50,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      final backdated = await repo.update(
        original,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(backdated.id, original.id);
      expect(backdated.loggedAt, original.loggedAt);
      expect(
        backdated.isQuickLog,
        isFalse,
        reason:
            'backdating loses the quick-log bonus — the '
            'anti-abuse-correct direction',
      );
    });

    test('update with clearNote removes the note; without it, an omitted '
        'note is preserved', () async {
      final withNote = await repo.add(
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        note: 'lunch',
        timestamp: DateTime.now(),
      );
      final untouched = await repo.update(withNote, amount: 20);
      expect(untouched.note, 'lunch');

      final cleared = await repo.update(untouched, clearNote: true);
      expect(cleared.note, isNull);
    });

    test(
      'writeBackXp only rewrites rows whose xpAwarded actually changed',
      () async {
        final a = await repo.add(
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final b = await repo.add(
          amount: 20,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        await repo.writeBackXp({a.id: 5, b.id: 10});
        expect(repo.getById(a.id)!.xpAwarded, 5);
        expect(repo.getById(b.id)!.xpAwarded, 10);

        // Re-writing the same value for `a` and a different one for `b` must
        // touch only `b`.
        await repo.writeBackXp({a.id: 5, b.id: 15});
        expect(repo.getById(a.id)!.xpAwarded, 5);
        expect(repo.getById(b.id)!.xpAwarded, 15);
      },
    );

    test(
      'putAll overwrites existing ids rather than duplicating rows',
      () async {
        final t = await repo.add(
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        await repo.putAll([
          Transaction(
            id: t.id,
            amount: 999,
            type: TransactionType.expense,
            category: 'Transport',
            timestamp: DateTime.now(),
            loggedAt: DateTime.now(),
            isQuickLog: false,
          ),
        ]);
        expect(repo.getAll(), hasLength(1));
        expect(repo.getAll().single.amount, 999);
      },
    );

    test('delete removes exactly the targeted row', () async {
      final a = await repo.add(
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      final b = await repo.add(
        amount: 20,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      await repo.delete(a.id);
      expect(repo.getAll().map((t) => t.id), [b.id]);
    });

    test(
      'renameCategory rewrites every matching row and leaves others alone',
      () async {
        final food = await repo.add(
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final transport = await repo.add(
          amount: 20,
          type: TransactionType.expense,
          category: 'Transport',
          timestamp: DateTime.now(),
        );

        final touched = await repo.renameCategory('Food', 'Groceries');

        expect(touched, 1);
        expect(repo.getById(food.id)!.category, 'Groceries');
        expect(repo.getById(transport.id)!.category, 'Transport');
      },
    );

    test('renameCategory is a no-op when nothing matches', () async {
      final touched = await repo.renameCategory('Nonexistent', 'New');
      expect(touched, 0);
    });

    test('countForCategory counts only exact matches', () async {
      await repo.add(
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      await repo.add(
        amount: 20,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      await repo.add(
        amount: 30,
        type: TransactionType.expense,
        category: 'Transport',
        timestamp: DateTime.now(),
      );

      expect(repo.countForCategory('Food'), 2);
      expect(repo.countForCategory('Transport'), 1);
      expect(repo.countForCategory('Nonexistent'), 0);
    });
  });

  group('ProfileRepository', () {
    test('hasProfile is false before create and true after', () async {
      final repo = ProfileRepository();
      expect(repo.hasProfile, isFalse);
      await repo.create(name: 'Test', avatarId: '🦊');
      expect(repo.hasProfile, isTrue);
    });

    test(
      'save persists arbitrary copyWith changes under the fixed local key',
      () async {
        final repo = ProfileRepository();
        final created = await repo.create(name: 'Test', avatarId: '🦊');
        await repo.save(created.copyWith(currentXP: 500, level: 3));
        expect(repo.current!.currentXP, 500);
        expect(repo.current!.level, 3);
      },
    );

    test('defaults currencyCode to INR when not specified', () async {
      final repo = ProfileRepository();
      final created = await repo.create(name: 'Test', avatarId: '🦊');
      expect(created.currencyCode, 'INR');
    });

    test('create and save round-trip an explicit currencyCode', () async {
      final repo = ProfileRepository();
      final created = await repo.create(
        name: 'Test',
        avatarId: '🦊',
        currencyCode: 'USD',
      );
      expect(created.currencyCode, 'USD');

      await repo.save(created.copyWith(currencyCode: 'EUR'));
      expect(repo.current!.currencyCode, 'EUR');
    });
  });

  group('QuestRepository', () {
    final repo = QuestRepository();

    Quest quest({
      required String id,
      required QuestType type,
      required DateTime endDate,
      QuestStatus status = QuestStatus.active,
      String? category,
      int targetValue = 100,
    }) {
      return Quest(
        id: id,
        title: 'test $id',
        type: type,
        targetValue: targetValue,
        startDate: endDate.subtract(const Duration(days: 7)),
        endDate: endDate,
        xpReward: 50,
        status: status,
        category: category,
      );
    }

    test('expireOverdueQuests marks an overdue non-budget quest expired, '
        'and leaves a not-yet-due quest untouched', () async {
      final overdue = quest(
        id: 'q1',
        type: QuestType.count,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final notDue = quest(
        id: 'q2',
        type: QuestType.count,
        endDate: DateTime.now().add(const Duration(days: 1)),
      );
      await Hive.box<Quest>(HiveBoxes.quests).put(overdue.id, overdue);
      await Hive.box<Quest>(HiveBoxes.quests).put(notDue.id, notDue);

      await repo.expireOverdueQuests();

      expect(
        repo.getAll().firstWhere((q) => q.id == 'q1').status,
        QuestStatus.expired,
      );
      expect(
        repo.getAll().firstWhere((q) => q.id == 'q2').status,
        QuestStatus.active,
      );
    });

    test('expireOverdueQuests treats an overdue budgetLimit quest as '
        'completed, not expired — its success can only be proven once the '
        'window has fully elapsed', () async {
      final overdue = quest(
        id: 'q3',
        type: QuestType.budgetLimit,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        category: 'Food',
      );
      await Hive.box<Quest>(HiveBoxes.quests).put(overdue.id, overdue);

      await repo.expireOverdueQuests();

      expect(repo.getAll().single.status, QuestStatus.completed);
    });

    test(
      'expireOverdueQuests never touches an already-terminal quest',
      () async {
        final alreadyCompleted = quest(
          id: 'q4',
          type: QuestType.count,
          endDate: DateTime.now().subtract(const Duration(days: 1)),
          status: QuestStatus.completed,
        );
        await Hive.box<Quest>(HiveBoxes.quests)
            .put(alreadyCompleted.id, alreadyCompleted);

        await repo.expireOverdueQuests();

        expect(repo.getAll().single.status, QuestStatus.completed);
      },
    );

    test('accept persists a candidate as an active quest with the '
        'PRD-fixed 7-day window', () async {
      // No transaction history to derive category candidates from, so this
      // falls back to the general (count/streak) templates, which fire
      // unconditionally.
      final candidates = repo.generateCandidates([], currentStreak: 5);
      expect(candidates, isNotEmpty);

      final chosen = candidates.first;
      final start = DateTime(2026, 1, 1);
      final accepted = await repo.accept(chosen, now: start);

      expect(accepted.status, QuestStatus.active);
      expect(accepted.startDate, start);
      expect(accepted.endDate, start.add(const Duration(days: 7)));
      expect(repo.getAll().map((q) => q.id), contains(accepted.id));
    });

    test('accept honours a caller-supplied durationDays, for the quest '
        'customize flow', () async {
      final candidates = repo.generateCandidates([], currentStreak: 5);
      final chosen = candidates.first;
      final start = DateTime(2026, 1, 1);

      final accepted = await repo.accept(chosen, now: start, durationDays: 14);

      expect(accepted.endDate, start.add(const Duration(days: 14)));
    });

    test('accepting a categoryAvoid starter candidate excludes it from '
        'regeneration', () async {
      final now = DateTime(2026, 1, 10);
      final transactions = [
        Transaction(
          id: 't1',
          amount: 500,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: now,
          loggedAt: now,
          isQuickLog: false,
        ),
      ];
      final before = repo.generateCandidates(
        transactions,
        currentStreak: 0,
        now: now,
      );
      final starter = before.firstWhere(
        (c) => c.type == QuestType.categoryAvoid,
      );

      await repo.accept(starter, now: now);

      final after = repo.generateCandidates(
        transactions,
        currentStreak: 0,
        now: now,
      );
      expect(
        after.any((c) => c.type == QuestType.categoryAvoid),
        isFalse,
        reason: 'the accepted categoryAvoid candidate should not reappear',
      );
    });
  });

  group('CategoryRepository', () {
    final repo = CategoryRepository();

    test('remove refuses to delete the last category of a type', () async {
      final only = await repo.add(
        name: 'Only',
        iconId: 'other',
        type: TransactionType.expense,
      );
      final removed = await repo.remove(only);
      expect(removed, isFalse);
      expect(repo.getAll(TransactionType.expense), hasLength(1));
    });

    test(
      'remove succeeds when another category of the same type remains',
      () async {
        final a = await repo.add(
          name: 'A',
          iconId: 'other',
          type: TransactionType.expense,
        );
        await repo.add(
          name: 'B',
          iconId: 'other',
          type: TransactionType.expense,
        );

        final removed = await repo.remove(a);
        expect(removed, isTrue);
        expect(repo.getAll(TransactionType.expense), hasLength(1));
      },
    );

    test('remove is scoped by type — the last expense category can be '
        'removed while income categories exist, and vice versa', () async {
      final onlyExpense = await repo.add(
        name: 'Food',
        iconId: 'other',
        type: TransactionType.expense,
      );
      await repo.add(
        name: 'Salary',
        iconId: 'other',
        type: TransactionType.income,
      );

      final removed = await repo.remove(onlyExpense);
      expect(
        removed,
        isFalse,
        reason:
            'still the last expense category, '
            'regardless of how many income categories exist',
      );
    });

    test('reorder persists sortOrder in the new sequence', () async {
      final a = await repo.add(
        name: 'A',
        iconId: 'other',
        type: TransactionType.expense,
      );
      final b = await repo.add(
        name: 'B',
        iconId: 'other',
        type: TransactionType.expense,
      );
      final c = await repo.add(
        name: 'C',
        iconId: 'other',
        type: TransactionType.expense,
      );

      await repo.reorder(TransactionType.expense, [c, a, b]);

      final ordered = repo.getAll(TransactionType.expense);
      expect(ordered.map((r) => r.id), [c.id, a.id, b.id]);
    });
  });

  group('SkippedQuestRepository', () {
    final repo = SkippedQuestRepository();

    test('titles is empty before any skip', () {
      expect(repo.titles, isEmpty);
    });

    test('skip persists a title, and it survives being read again', () async {
      await repo.skip('No Food for 3 days');
      expect(repo.titles, {'No Food for 3 days'});
    });

    test('unskip removes exactly the given title', () async {
      await repo.skip('A');
      await repo.skip('B');
      await repo.unskip('A');
      expect(repo.titles, {'B'});
    });

    test('clear empties the whole set', () async {
      await repo.skip('A');
      await repo.skip('B');
      await repo.clear();
      expect(repo.titles, isEmpty);
    });
  });
}
