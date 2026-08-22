import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/badge_engine.dart';
import '../core/utils/date_helpers.dart';
import '../core/utils/quest_engine.dart';
import '../core/utils/xp_engine.dart';
import '../models/quest.dart';
import '../models/transaction.dart';
import 'badge_provider.dart';
import 'profile_provider.dart';
import 'quest_provider.dart';
import 'transaction_provider.dart';

/// Result of logging a transaction — lets the UI react to badge unlocks
/// (e.g. a celebration) without the orchestrator knowing about widgets.
class LogTransactionResult {
  const LogTransactionResult({
    required this.transaction,
    required this.xpGained,
    required this.newlyUnlockedBadges,
    required this.leveledUpTo,
  });

  final Transaction transaction;
  final int xpGained;
  final List<BadgeDefinition> newlyUnlockedBadges;

  /// Non-null when this log pushed the profile to a new level.
  final int? leveledUpTo;
}

/// Orchestrates the "log a transaction" flow described in the PRD (section
/// 8): save the transaction, run the pure XP/streak/quest/badge engines
/// against it, persist the results, and update every dependent provider so
/// Home, Profile and Quests screens rebuild reactively from one action.
class XpEngineOrchestrator {
  XpEngineOrchestrator(this._ref);

  final Ref _ref;

  Future<LogTransactionResult> logTransaction({
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required DateTime timestamp,
  }) async {
    final now = DateTime.now();
    final transactionRepo = _ref.read(transactionRepositoryProvider);
    final profileRepo = _ref.read(profileRepositoryProvider);

    final logsAlreadyToday = transactionRepo.countForDay(now);

    final transaction = transactionRepo.add(
      amount: amount,
      type: type,
      category: category,
      note: note,
      timestamp: timestamp,
    );
    _ref.read(transactionsProvider.notifier).refresh();

    final profile = _ref.read(profileProvider);
    if (profile == null) {
      throw StateError('logTransaction called before a profile exists');
    }

    var xpGained = calculateTransactionLogXp(
      logsAlreadyToday: logsAlreadyToday,
      isQuickLog: transaction.isQuickLog,
    );

    var freezesLeft = profile.streakFreezesLeft;
    var freezeResetDate = profile.lastFreezeResetDate;
    if (shouldResetWeeklyFreeze(
        lastFreezeResetDate: freezeResetDate, today: now)) {
      freezesLeft = 1;
      freezeResetDate = now;
    }

    final streakResult = evaluateStreak(
      lastLogged: profile.lastLoggedDate,
      today: now,
      currentStreak: profile.currentStreak,
      freezesLeft: freezesLeft,
    );
    if (streakResult.streakAdvancedToday) {
      xpGained += kStreakDayXp;
    }

    final spentToday = transactionRepo.totalSpentForDay(now);
    var lastBudgetBonusDate = profile.lastBudgetBonusDate;
    var daysUnderBudgetCount = profile.daysUnderBudgetCount;
    if (shouldAwardDailyBudgetBonus(
      monthlyBudget: profile.monthlyBudget,
      spentToday: spentToday,
      lastBudgetBonusDate: lastBudgetBonusDate,
      today: now,
    )) {
      xpGained += kUnderBudgetXp;
      lastBudgetBonusDate = now;
      daysUnderBudgetCount += 1;
    }

    final newXp = profile.currentXP + xpGained;
    final newLevel = levelForXp(newXp);

    await _updateQuestProgress(
      transaction: transaction,
      streak: streakResult.newStreak,
      today: now,
    );

    final newlyUnlockedBadges = await _unlockEligibleBadges(
      transactionCount: transactionRepo.getAll().length,
      currentStreak: streakResult.newStreak,
      level: newLevel,
      daysUnderBudget: daysUnderBudgetCount,
      now: now,
    );

    final updatedProfile = profile.copyWith(
      currentXP: newXp,
      level: newLevel,
      currentStreak: streakResult.newStreak,
      longestStreak: streakResult.newStreak > profile.longestStreak
          ? streakResult.newStreak
          : profile.longestStreak,
      lastLoggedDate: now,
      streakFreezesLeft: streakResult.freezesLeft,
      lastFreezeResetDate: freezeResetDate,
      lastBudgetBonusDate: lastBudgetBonusDate,
      daysUnderBudgetCount: daysUnderBudgetCount,
      badgeIds: newlyUnlockedBadges.isEmpty
          ? profile.badgeIds
          : [...profile.badgeIds, ...newlyUnlockedBadges.map((b) => b.id)],
    );
    await profileRepo.save(updatedProfile);
    _ref.read(profileProvider.notifier).setProfile(updatedProfile);

    return LogTransactionResult(
      transaction: transaction,
      xpGained: xpGained,
      newlyUnlockedBadges: newlyUnlockedBadges,
      leveledUpTo: newLevel > profile.level ? newLevel : null,
    );
  }

  Future<void> _updateQuestProgress({
    required Transaction transaction,
    required int streak,
    required DateTime today,
  }) async {
    final questRepo = _ref.read(questRepositoryProvider);
    final transactionRepo = _ref.read(transactionRepositoryProvider);
    final allTransactions = _ref.read(transactionsProvider);

    for (final quest in questRepo.active) {
      final sinceStart = allTransactions
          .where((t) => !startOfDay(t.timestamp).isBefore(startOfDay(quest.startDate)))
          .toList();
      final categorySpend = transactionRepo
          .totalsByCategory(
            sinceStart.where((t) => t.category == quest.category).toList(),
          )[quest.category] ??
          0;
      final count = sinceStart.length;

      final update = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: transaction,
        categorySpendSinceStart: categorySpend,
        transactionCountSinceStart: count,
        currentStreak: streak,
        today: today,
      );
      if (update == null) continue;

      quest.currentProgress = update.progress;
      quest.status = update.status;
      await quest.save();
    }
    _ref.read(questsProvider.notifier).refresh();
  }

  Future<List<BadgeDefinition>> _unlockEligibleBadges({
    required int transactionCount,
    required int currentStreak,
    required int level,
    required int daysUnderBudget,
    required DateTime now,
  }) async {
    final badgeRepo = _ref.read(badgeRepositoryProvider);
    final questRepo = _ref.read(questRepositoryProvider);
    final questsCompleted =
        questRepo.getAll().where((q) => q.status == QuestStatus.completed).length;

    final newlyUnlocked = evaluateNewlyUnlockedBadges(
      transactionCount: transactionCount,
      currentStreak: currentStreak,
      level: level,
      questsCompleted: questsCompleted,
      daysUnderBudget: daysUnderBudget,
      alreadyUnlockedIds: badgeRepo.unlockedIds,
    );

    for (final def in newlyUnlocked) {
      await badgeRepo.unlock(def, now: now);
    }
    if (newlyUnlocked.isNotEmpty) {
      _ref.read(badgesProvider.notifier).refresh();
    }
    return newlyUnlocked;
  }
}

final xpEngineOrchestratorProvider = Provider<XpEngineOrchestrator>((ref) {
  return XpEngineOrchestrator(ref);
});
