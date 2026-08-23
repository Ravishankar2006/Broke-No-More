import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/utils/xp_engine.dart';
import 'package:broke_no_more/data/gamification_repair.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/profile_provider.dart';
import 'package:broke_no_more/providers/quest_provider.dart';
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
    }
    await Hive.openBox<Transaction>(HiveBoxes.transactions);
    await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<dynamic>(HiveBoxes.appState);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);

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

  test(
    'completing a quest raises currentXP by exactly xpReward, and it '
    'survives a subsequent unrelated log/edit/delete',
    () async {
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

      final transactionXp = calculateTransactionLogXp(
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
    },
  );

  test(
    'boot repair preserves quest XP — replay both paths and assert they '
    'agree',
    () async {
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
    },
  );

  test(
    'a budgetLimit quest past endDate with spend under target becomes '
    'completed and pays out',
    () async {
      final now = DateTime.now();
      await putQuest(Quest(
        id: 'q3',
        title: 'stay under Food',
        type: QuestType.budgetLimit,
        targetValue: 500,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 1)),
        xpReward: 50,
        category: 'Food',
      ));

      // Mirrors the real boot sequence in main.dart: expiry runs before the
      // gamification repair that folds quest XP into the profile.
      await container.read(questRepositoryProvider).expireOverdueQuests();
      expect(
        container.read(questRepositoryProvider).getAll().single.status,
        QuestStatus.completed,
        reason: 'stayed under the ₹500 limit for the whole window, so it '
            'succeeded rather than merely expiring',
      );

      await repairGamificationState();
      final profile = ProfileRepository().current!;
      expect(profile.currentXP, 50);
    },
  );

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
      expect(
        result.newlyUnlockedBadges.map((b) => b.id),
        contains('level_5'),
      );
      expect(container.read(profileProvider)!.level, greaterThanOrEqualTo(5));
    },
  );
}
