import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/utils/xp_engine.dart';
import 'package:broke_no_more/data/gamification_repair.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/profile_provider.dart';
import 'package:broke_no_more/providers/quest_provider.dart';
import 'package:broke_no_more/providers/transaction_provider.dart';
import 'package:broke_no_more/providers/xp_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers [XpEngineOrchestrator] and its boot-time counterpart
/// `repairGamificationState` — previously untested despite being the single
/// entry point for every XP/streak/quest/badge mutation in the app. These
/// tests specifically guard the quest-XP fix: before it, `Quest.xpReward`
/// was displayed on cards but never added to `UserProfile.currentXP`
/// anywhere.
void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xp_engine_provider_test');
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

  Future<void> putQuest(Quest quest) async {
    await Hive.box<Quest>(HiveBoxes.quests).put(quest.id, quest);
  }

  Quest countQuest({
    required String id,
    required int target,
    required int reward,
  }) {
    final now = DateTime.now();
    return Quest(
      id: id,
      title: 'test quest $id',
      type: QuestType.count,
      targetValue: target,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 6)),
      xpReward: reward,
    );
  }

  test('completing a quest raises currentXP by exactly xpReward, and it '
      'survives a subsequent unrelated log/edit/delete', () async {
    await putQuest(countQuest(id: 'q1', target: 1, reward: 75));

    final orchestrator = container.read(xpEngineOrchestratorProvider);
    final first = await orchestrator.logTransaction(
      amount: 100,
      type: TransactionType.expense,
      category: 'Food',
      timestamp: DateTime.now(),
    );

    // The one relevant transaction satisfies the count-1 target, so the
    // quest completes on this very mutation.
    expect(first.completedQuests.map((q) => q.id), contains('q1'));

    final transactionXp =
        calculateTransactionLogXp(
          logsAlreadyToday: 0,
          isQuickLog: first.transaction!.isQuickLog,
        ) +
        kStreakDayXp;
    expect(first.xpGained, transactionXp + 75);

    final afterFirst = container.read(profileProvider)!;
    expect(afterFirst.currentXP, transactionXp + 75);

    // An unrelated second log must not disturb the already-banked quest
    // reward — completed quests are sticky, so their XP is added again
    // (still summed fresh) but never lost.
    final second = await orchestrator.logTransaction(
      amount: 50,
      type: TransactionType.expense,
      category: 'Food',
      timestamp: DateTime.now(),
    );
    final afterSecond = container.read(profileProvider)!;
    expect(afterSecond.currentXP, afterFirst.currentXP + second.xpGained);
    expect(afterSecond.currentXP, greaterThanOrEqualTo(75));

    // Deleting the transaction that originally completed the quest must
    // not revoke it — `replayQuest` treats `completed` as terminal.
    await orchestrator.deleteTransaction(first.transaction!.id);
    final afterDelete = container.read(profileProvider)!;
    expect(afterDelete.currentXP, greaterThanOrEqualTo(75));
  });

  test('boot repair preserves quest XP — replay both paths and assert they '
      'agree', () async {
    await putQuest(countQuest(id: 'q2', target: 1, reward: 60));

    final orchestrator = container.read(xpEngineOrchestratorProvider);
    await orchestrator.logTransaction(
      amount: 20,
      type: TransactionType.expense,
      category: 'Food',
      timestamp: DateTime.now(),
    );

    final liveXp = container.read(profileProvider)!.currentXP;
    expect(liveXp, greaterThanOrEqualTo(60));

    // Simulates an app restart: the boot-time repair path must reproduce
    // exactly what the live orchestrator already computed, not erase the
    // quest XP it granted.
    await repairGamificationState();
    final afterReboot = ProfileRepository().current!;
    expect(afterReboot.currentXP, liveXp);
  });

  test('a budgetLimit quest past endDate with spend under target becomes '
      'completed and pays out', () async {
    final now = DateTime.now();
    await putQuest(
      Quest(
        id: 'q3',
        title: 'stay under Food',
        type: QuestType.budgetLimit,
        targetValue: 500,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 1)),
        xpReward: 50,
        category: 'Food',
      ),
    );

    // Mirrors the real boot sequence in main.dart: expiry runs before the
    // gamification repair that folds quest XP into the profile.
    await container.read(questRepositoryProvider).expireOverdueQuests();
    expect(
      container.read(questRepositoryProvider).getAll().single.status,
      QuestStatus.completed,
      reason:
          'stayed under the ₹500 limit for the whole window, so it '
          'succeeded rather than merely expiring',
    );

    await repairGamificationState();
    final profile = ProfileRepository().current!;
    expect(profile.currentXP, 50);
  });

  test(
    'badges gate on the combined level, not the transaction-only level',
    () async {
      // xpForLevel(4) == 1000, so a reward this large reaches level 5 purely
      // from quest XP — a handful of transaction XP on top proves the badge
      // check used the combined total, not the transaction-only replay.
      expect(xpForLevel(4), 1000);
      await putQuest(countQuest(id: 'q4', target: 1, reward: 1000));

      final orchestrator = container.read(xpEngineOrchestratorProvider);
      final result = await orchestrator.logTransaction(
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );

      expect(result.completedQuests.map((q) => q.id), contains('q4'));
      expect(result.newlyUnlockedBadges.map((b) => b.id), contains('level_5'));
      expect(container.read(profileProvider)!.level, greaterThanOrEqualTo(5));
    },
  );

  group('importTransactions', () {
    Transaction importedTx({
      required String id,
      double amount = 40,
      String category = 'Food',
      DateTime? timestamp,
    }) {
      final ts = timestamp ?? DateTime.now();
      return Transaction(
        id: id,
        amount: amount,
        type: TransactionType.expense,
        category: category,
        timestamp: ts,
        loggedAt: ts,
        isQuickLog: false,
      );
    }

    test('writes new rows and recomputes XP the same as a live log', () async {
      final orchestrator = container.read(xpEngineOrchestratorProvider);
      final result = await orchestrator.importTransactions([
        importedTx(id: 'i1', timestamp: DateTime.now()),
      ]);

      expect(result.importedCount, 1);
      expect(container.read(transactionsProvider), hasLength(1));
      // A fresh streak day plus one log, same as any first transaction.
      expect(result.xpGained, kStreakDayXp + kBaseLogXp);
      expect(container.read(profileProvider)!.currentXP, result.xpGained);
    });

    test(
      'a row whose id already exists overwrites it, not duplicates it',
      () async {
        final orchestrator = container.read(xpEngineOrchestratorProvider);
        final logged = await orchestrator.logTransaction(
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final id = logged.transaction!.id;

        await orchestrator.importTransactions([
          importedTx(id: id, amount: 250, category: 'Transport'),
        ]);

        final all = container.read(transactionsProvider);
        expect(all, hasLength(1));
        expect(all.single.amount, 250);
        expect(all.single.category, 'Transport');
      },
    );

    test('an imported row can complete a quest and unlock a badge, exactly '
        'like a live log', () async {
      await putQuest(countQuest(id: 'iq1', target: 1, reward: 50));

      final orchestrator = container.read(xpEngineOrchestratorProvider);
      final result = await orchestrator.importTransactions([
        importedTx(id: 'i2', timestamp: DateTime.now()),
      ]);

      expect(result.completedQuests.map((q) => q.id), contains('iq1'));
      expect(
        result.newlyUnlockedBadges.map((b) => b.id),
        contains('quest_first'),
      );
      expect(result.xpGained, kStreakDayXp + kBaseLogXp + 50);
    });
  });

  group('updateMonthlyBudget', () {
    test('setting a budget awards the under-budget bonus immediately, without '
        'waiting for the next transaction', () async {
      final orchestrator = container.read(xpEngineOrchestratorProvider);
      // Logged with no budget set — no bonus is possible yet.
      await orchestrator.logTransaction(
        amount: 50,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      final xpBefore = container.read(profileProvider)!.currentXP;

      // 3000/31 (or whichever month) still comfortably covers a ₹50 day.
      await orchestrator.updateMonthlyBudget(3000);

      final profile = container.read(profileProvider)!;
      expect(profile.monthlyBudget, 3000);
      expect(profile.currentXP, xpBefore + kUnderBudgetXp);
      expect(profile.daysUnderBudgetCount, 1);
    });

    test('clearing a budget revokes the bonus immediately, and the budget is '
        'actually null afterwards', () async {
      final orchestrator = container.read(xpEngineOrchestratorProvider);
      await orchestrator.updateMonthlyBudget(3000);
      await orchestrator.logTransaction(
        amount: 50,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: DateTime.now(),
      );
      final withBonus = container.read(profileProvider)!;
      expect(withBonus.daysUnderBudgetCount, 1);

      await orchestrator.updateMonthlyBudget(null);

      final cleared = container.read(profileProvider)!;
      // The regression this guards: UserProfile.copyWith used
      // `monthlyBudget ?? this.monthlyBudget`, so passing null could never
      // actually clear it.
      expect(cleared.monthlyBudget, isNull);
      expect(cleared.currentXP, withBonus.currentXP - kUnderBudgetXp);
      expect(cleared.daysUnderBudgetCount, 0);
    });
  });

  group('expireOverdueQuests', () {
    test('an overdue budgetLimit quest resolving to completed reaches the '
        'live profile immediately, not just after a reboot', () async {
      await putQuest(
        Quest(
          id: 'q5',
          title: 'stay under Food',
          type: QuestType.budgetLimit,
          targetValue: 500,
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now().subtract(const Duration(days: 1)),
          xpReward: 50,
          category: 'Food',
        ),
      );

      final orchestrator = container.read(xpEngineOrchestratorProvider);
      await orchestrator.expireOverdueQuests();

      expect(
        container.read(questsProvider).single.status,
        QuestStatus.completed,
      );
      expect(
        container.read(profileProvider)!.currentXP,
        50,
        reason:
            'previously only QuestRepository.expireOverdueQuests was '
            'called directly from quests_screen.dart, with nothing '
            'recomputing the profile until the next app restart',
      );
    });

    test(
      'with nothing overdue, the profile is left untouched — this must '
      'stay a cheap no-op since it runs every time the Quests screen opens',
      () async {
        await putQuest(countQuest(id: 'q6', target: 100, reward: 50));
        final before = container.read(profileProvider)!;

        final orchestrator = container.read(xpEngineOrchestratorProvider);
        await orchestrator.expireOverdueQuests();

        expect(container.read(profileProvider)!, same(before));
      },
    );
  });

  group('acceptQuest', () {
    test('persists the candidate as an active quest visible to the '
        'questsProvider', () async {
      final candidates = container
          .read(questRepositoryProvider)
          .generateCandidates([], currentStreak: 0);
      expect(candidates, isNotEmpty);

      final orchestrator = container.read(xpEngineOrchestratorProvider);
      final accepted = await orchestrator.acceptQuest(candidates.first);

      expect(accepted.status, QuestStatus.active);
      expect(container.read(questsProvider).map((q) => q.id), [accepted.id]);
    });
  });

  group('deleteTransactions', () {
    test(
      'removes every listed id in one mutation and recomputes XP once',
      () async {
        final orchestrator = container.read(xpEngineOrchestratorProvider);
        final a = await orchestrator.logTransaction(
          amount: 50,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final b = await orchestrator.logTransaction(
          amount: 30,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );

        await orchestrator.deleteTransactions([
          a.transaction!.id,
          b.transaction!.id,
        ]);

        expect(container.read(transactionsProvider), isEmpty);
        expect(container.read(profileProvider)!.currentXP, 0);
      },
    );
  });

  group('renameCategory', () {
    test(
      'rewrites the category on every matching transaction, XP unaffected',
      () async {
        final orchestrator = container.read(xpEngineOrchestratorProvider);
        await orchestrator.logTransaction(
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final xpBefore = container.read(profileProvider)!.currentXP;

        await orchestrator.renameCategory('Food', 'Groceries');

        expect(
          container.read(transactionsProvider).single.category,
          'Groceries',
        );
        expect(
          container.read(profileProvider)!.currentXP,
          xpBefore,
          reason: 'a category label change carries no XP of its own',
        );
      },
    );
  });

  group('restoreTransactions', () {
    test(
      'writes the exact same rows back and recomputes XP to match',
      () async {
        final orchestrator = container.read(xpEngineOrchestratorProvider);
        final logged = await orchestrator.logTransaction(
          amount: 50,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: DateTime.now(),
        );
        final xpBeforeDelete = container.read(profileProvider)!.currentXP;
        final original = logged.transaction!;

        await orchestrator.deleteTransaction(original.id);
        expect(container.read(transactionsProvider), isEmpty);

        await orchestrator.restoreTransactions([original]);

        expect(container.read(transactionsProvider).single.id, original.id);
        expect(
          container.read(profileProvider)!.currentXP,
          xpBeforeDelete,
          reason:
              'restoring the exact same row (same id/timestamp) must land '
              'back on the same XP the replay originally attributed to it',
        );
      },
    );
  });
}
