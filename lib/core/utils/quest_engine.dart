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

/// Re-derives a quest's progress and status from the whole transaction list,
/// rather than advancing it incrementally by one transaction.
///
/// A one-way incremental evaluator (advance-by-one-transaction, moving a
/// quest to `failed` but never back) would leave a `categoryAvoid` quest
/// failed forever even after the offending transaction was deleted or
/// recategorised. Once transactions became editable that would be a visible
/// lie, so every mutation replays from scratch instead.
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
        // No completed state here: staying under the limit is only proven
        // once the quest's window fully elapses, which
        // QuestRepository.expireOverdueQuests resolves, not this replay.
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
