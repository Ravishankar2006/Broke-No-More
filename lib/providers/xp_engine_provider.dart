import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/quest_engine.dart';
import '../core/utils/xp_engine.dart';
import '../models/transaction.dart';
import 'profile_provider.dart';
import 'quest_provider.dart';
import 'transaction_provider.dart';

/// Orchestrates the "log a transaction" flow described in the PRD (section
/// 8): save the transaction, run the pure XP/streak/quest engines against
/// it, persist the results, and update every dependent provider so Home,
/// Profile and Quests screens rebuild reactively from one action.
class XpEngineOrchestrator {
  XpEngineOrchestrator(this._ref);

  final Ref _ref;

  Future<Transaction> logTransaction({
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

    var profile = _ref.read(profileProvider);
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
    if (shouldAwardDailyBudgetBonus(
      monthlyBudget: profile.monthlyBudget,
      spentToday: spentToday,
      lastBudgetBonusDate: lastBudgetBonusDate,
      today: now,
    )) {
      xpGained += kUnderBudgetXp;
      lastBudgetBonusDate = now;
    }

    final newXp = profile.currentXP + xpGained;
    final updatedProfile = profile.copyWith(
      currentXP: newXp,
      level: levelForXp(newXp),
      currentStreak: streakResult.newStreak,
      longestStreak: streakResult.newStreak > profile.longestStreak
          ? streakResult.newStreak
          : profile.longestStreak,
      lastLoggedDate: now,
      streakFreezesLeft: streakResult.freezesLeft,
      lastFreezeResetDate: freezeResetDate,
      lastBudgetBonusDate: lastBudgetBonusDate,
    );
    await profileRepo.save(updatedProfile);
    _ref.read(profileProvider.notifier).setProfile(updatedProfile);

    await _updateQuestProgress(
      transaction: transaction,
      streak: streakResult.newStreak,
      today: now,
    );

    return transaction;
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
}

final xpEngineOrchestratorProvider = Provider<XpEngineOrchestrator>((ref) {
  return XpEngineOrchestrator(ref);
});
