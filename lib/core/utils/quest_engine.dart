/// Pure logic for advancing quest progress after a transaction is logged.
/// Kept alongside [xp_engine.dart] for the same reason: no Flutter/Riverpod
/// dependency, independently unit-testable.
library;

import '../../models/quest.dart';
import '../../models/transaction.dart';
import 'date_helpers.dart';

class QuestUpdateResult {
  const QuestUpdateResult({required this.progress, required this.status});

  final int progress;
  final QuestStatus status;
}

/// Given an active [quest] and a newly-logged [transaction], returns the
/// quest's updated progress/status. Returns null when the transaction is
/// irrelevant to this quest (no-op).
QuestUpdateResult? evaluateQuestAfterTransaction({
  required Quest quest,
  required Transaction transaction,
  required double categorySpendSinceStart,
  required int transactionCountSinceStart,
  required int currentStreak,
  required DateTime today,
}) {
  if (quest.status != QuestStatus.active) return null;

  switch (quest.type) {
    case QuestType.categoryAvoid:
      if (transaction.type == TransactionType.expense &&
          transaction.category == quest.category) {
        return QuestUpdateResult(
          progress: quest.currentProgress,
          status: QuestStatus.failed,
        );
      }
      final daysElapsed =
          (daysBetween(quest.startDate, today) + 1).clamp(0, quest.targetValue);
      final status = daysElapsed >= quest.targetValue
          ? QuestStatus.completed
          : QuestStatus.active;
      return QuestUpdateResult(progress: daysElapsed, status: status);

    case QuestType.budgetLimit:
      if (transaction.type != TransactionType.expense ||
          transaction.category != quest.category) {
        return null;
      }
      final status = categorySpendSinceStart > quest.targetValue
          ? QuestStatus.failed
          : QuestStatus.active;
      return QuestUpdateResult(
        progress: categorySpendSinceStart.ceil(),
        status: status,
      );

    case QuestType.count:
      final status = transactionCountSinceStart >= quest.targetValue
          ? QuestStatus.completed
          : QuestStatus.active;
      return QuestUpdateResult(
        progress: transactionCountSinceStart,
        status: status,
      );

    case QuestType.streak:
      final progress = currentStreak.clamp(0, quest.targetValue);
      final status = currentStreak >= quest.targetValue
          ? QuestStatus.completed
          : QuestStatus.active;
      return QuestUpdateResult(progress: progress, status: status);
  }
}

/// Re-derives a quest's progress and status from the whole transaction list,
/// rather than advancing it by one transaction.
///
/// [evaluateQuestAfterTransaction] above is incremental and one-way: it can move
/// a quest to `failed` but never back, so a `categoryAvoid` quest stayed failed
/// forever even after the offending transaction was deleted or recategorised.
/// Once transactions became editable that turned into a visible lie, so
/// mutations go through this instead.
///
/// Terminal states are respected, not recomputed:
/// - `expired` is time-driven (set at startup by `expireOverdueQuests`), so it
///   is never revisited here.
/// - `completed` is sticky. It may already have fired a celebration and counted
///   toward the quest badges; un-completing it would revoke something the user
///   was already told they'd earned.
///
/// Everything else — `active` and `failed` — is recomputed from scratch, which
/// is what lets a quest recover when the evidence against it is removed.
QuestUpdateResult replayQuest({
  required Quest quest,
  required List<Transaction> transactions,
  required int currentStreak,
  required DateTime asOf,
}) {
  if (quest.status == QuestStatus.expired ||
      quest.status == QuestStatus.completed) {
    return QuestUpdateResult(
      progress: quest.currentProgress,
      status: quest.status,
    );
  }

  // Window: from the quest's start through the earlier of now and its deadline,
  // so transactions logged after a quest ended can't retroactively affect it.
  final windowStart = startOfDay(quest.startDate);
  final windowEnd = startOfDay(
    asOf.isBefore(quest.endDate) ? asOf : quest.endDate,
  );
  final inWindow = transactions.where((t) {
    final day = startOfDay(t.timestamp);
    return !day.isBefore(windowStart) && !day.isAfter(windowEnd);
  }).toList(growable: false);

  switch (quest.type) {
    case QuestType.categoryAvoid:
      final offended = inWindow.any((t) =>
          t.type == TransactionType.expense && t.category == quest.category);
      if (offended) {
        return QuestUpdateResult(
          progress: quest.currentProgress,
          status: QuestStatus.failed,
        );
      }
      final daysElapsed =
          (daysBetween(quest.startDate, asOf) + 1).clamp(0, quest.targetValue);
      return QuestUpdateResult(
        progress: daysElapsed,
        status: daysElapsed >= quest.targetValue
            ? QuestStatus.completed
            : QuestStatus.active,
      );

    case QuestType.budgetLimit:
      final spend = inWindow
          .where((t) =>
              t.type == TransactionType.expense && t.category == quest.category)
          .fold<double>(0, (sum, t) => sum + t.amount);
      return QuestUpdateResult(
        progress: spend.ceil(),
        // No completed state: staying under the limit is only proven once the
        // quest expires, matching the incremental path.
        status: spend > quest.targetValue
            ? QuestStatus.failed
            : QuestStatus.active,
      );

    case QuestType.count:
      // Counts every transaction, not just expenses — matches the incremental
      // path, which used the unfiltered since-start list.
      final count = inWindow.length;
      return QuestUpdateResult(
        progress: count,
        status: count >= quest.targetValue
            ? QuestStatus.completed
            : QuestStatus.active,
      );

    case QuestType.streak:
      return QuestUpdateResult(
        progress: currentStreak.clamp(0, quest.targetValue),
        status: currentStreak >= quest.targetValue
            ? QuestStatus.completed
            : QuestStatus.active,
      );
  }
}
