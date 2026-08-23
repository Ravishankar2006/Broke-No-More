import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/quest_template_engine.dart';
import '../models/quest.dart';
import '../models/transaction.dart';

export '../core/utils/quest_template_engine.dart' show QuestCandidate;

const _uuid = Uuid();

class QuestRepository {
  Box<Quest> get _box => Hive.box<Quest>(HiveBoxes.quests);

  List<Quest> getAll() => _box.values.toList(growable: false);

  List<Quest> get active =>
      _box.values.where((q) => q.status == QuestStatus.active).toList();

  Future<Quest> accept(QuestCandidate candidate, {DateTime? now}) async {
    final start = now ?? DateTime.now();
    final quest = Quest(
      id: _uuid.v4(),
      title: candidate.title,
      type: candidate.type,
      targetValue: candidate.targetValue,
      startDate: start,
      endDate: start.add(const Duration(days: kQuestDurationDays)),
      xpReward: candidate.xpReward,
      category: candidate.category,
    );
    await _box.put(quest.id, quest);
    return quest;
  }

  /// The one checkpoint (run at app startup, no backend to run this on a
  /// schedule) for both expiring stale quests and resolving `budgetLimit`
  /// quests, whose success can only be proven once their window has fully
  /// elapsed — the incremental replay deliberately never marks one
  /// `completed` while still active, so a `budgetLimit` quest that survives
  /// to its deadline without failing succeeded, and belongs here rather
  /// than lumped in with `expired`.
  Future<void> expireOverdueQuests({DateTime? now}) async {
    final today = now ?? DateTime.now();
    for (final quest in active) {
      if (!quest.endDate.isBefore(today)) continue;
      quest.status = quest.type == QuestType.budgetLimit
          ? QuestStatus.completed
          : QuestStatus.expired;
      await quest.save();
    }
  }

  /// Rule-based quest generation, entirely offline (PRD section 7) — see
  /// core/utils/quest_template_engine.dart for the actual rule engine and
  /// template library; this just supplies the transaction data.
  List<QuestCandidate> generateCandidates(
    List<Transaction> allTransactions, {
    required int currentStreak,
    DateTime? now,
    int maxCandidates = 3,
  }) {
    return generateQuestCandidates(
      allTransactions: allTransactions,
      currentStreak: currentStreak,
      activeQuests: active,
      now: now,
      maxCandidates: maxCandidates,
    );
  }
}
