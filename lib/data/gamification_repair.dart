import 'dart:math' as math;

import '../core/utils/badge_engine.dart';
import '../core/utils/gamification_replay.dart';
import '../core/utils/quest_engine.dart';
import '../models/quest.dart';
import 'badge_repository.dart';
import 'profile_repository.dart';
import 'quest_repository.dart';
import 'transaction_repository.dart';

/// Re-derives gamification state at app start, repairing anything a partial
/// write left inconsistent.
///
/// Hive has no cross-box transaction: [XpEngineOrchestrator] writes the
/// transactions box, then the quests box, then badges, then the profile. If the
/// process is killed between those writes, the profile disagrees with the
/// transaction list — XP that was earned but not saved, or a deleted row whose
/// XP is still counted. There is no backend to reconcile that, so app start is
/// the one guaranteed checkpoint, exactly like
/// [QuestRepository.expireOverdueQuests].
///
/// Runs before `runApp`, so it uses repositories directly rather than Riverpod
/// providers — nothing is watching yet.
///
/// Deliberately silent: badges unlocked here appear on the shelf without a
/// celebration dialog, since the user didn't just do anything. A dialog on cold
/// start would be confusing.
Future<void> repairGamificationState() async {
  final profileRepo = ProfileRepository();
  final profile = profileRepo.current;
  // No profile yet means onboarding hasn't run — nothing to repair.
  if (profile == null) return;

  final transactionRepo = TransactionRepository();
  final transactions = transactionRepo.getAll();
  final now = DateTime.now();

  final replay = replayGamification(
    ReplayInput(
      transactions: transactions,
      joinDate: profile.joinDate,
      monthlyBudget: profile.monthlyBudget,
      asOf: now,
    ),
  );
  await transactionRepo.writeBackXp(replay.xpByTransactionId);

  final questRepo = QuestRepository();
  for (final quest in questRepo.getAll()) {
    final update = replayQuest(
      quest: quest,
      transactions: transactions,
      currentStreak: replay.currentStreak,
      asOf: now,
    );
    if (quest.currentProgress == update.progress &&
        quest.status == update.status) {
      continue;
    }
    quest.currentProgress = update.progress;
    quest.status = update.status;
    await quest.save();
  }

  final badgeRepo = BadgeRepository();
  final questsCompleted = questRepo
      .getAll()
      .where((q) => q.status == QuestStatus.completed)
      .length;
  final newlyUnlocked = evaluateNewlyUnlockedBadges(
    transactionCount: transactions.length,
    currentStreak: replay.currentStreak,
    level: replay.level,
    questsCompleted: questsCompleted,
    daysUnderBudget: replay.daysUnderBudgetCount,
    alreadyUnlockedIds: badgeRepo.unlockedIds,
  );
  for (final def in newlyUnlocked) {
    await badgeRepo.unlock(def, now: now);
  }

  await profileRepo.save(
    profile.copyWith(
      currentXP: replay.totalXp,
      level: replay.level,
      currentStreak: replay.currentStreak,
      // Ratchet: a record must survive history being edited away.
      longestStreak: math.max(profile.longestStreak, replay.longestStreakSeen),
      lastLoggedDate: replay.lastLoggedDay ?? profile.joinDate,
      streakFreezesLeft: replay.streakFreezesLeft,
      lastFreezeResetDate: replay.lastFreezeResetDate,
      lastBudgetBonusDate: replay.lastBudgetBonusDate,
      daysUnderBudgetCount: replay.daysUnderBudgetCount,
      badgeIds: newlyUnlocked.isEmpty
          ? profile.badgeIds
          : [...profile.badgeIds, ...newlyUnlocked.map((b) => b.id)],
    ),
  );
}
