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
