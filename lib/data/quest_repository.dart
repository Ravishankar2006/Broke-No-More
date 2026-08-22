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

  Future<void> updateProgress(Quest quest, int newProgress) async {
    quest.currentProgress = newProgress;
    if (newProgress >= quest.targetValue) {
      quest.status = QuestStatus.completed;
    }
    await quest.save();
  }

  Future<void> expireOverdueQuests({DateTime? now}) async {
    final today = now ?? DateTime.now();
    for (final quest in active) {
      if (quest.endDate.isBefore(today)) {
        quest.status = QuestStatus.expired;
        await quest.save();
      }
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
