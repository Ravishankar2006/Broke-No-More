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

  /// [durationDays] defaults to [kQuestDurationDays] — the "customize" flow
  /// (Quests screen) passes a user-chosen value instead.
  Future<Quest> accept(
    QuestCandidate candidate, {
    DateTime? now,
    int? durationDays,
  }) async {
    final start = now ?? DateTime.now();
    final quest = Quest(
      id: _uuid.v4(),
      title: candidate.title,
      type: candidate.type,
      targetValue: candidate.targetValue,
      startDate: start,
      endDate: start.add(Duration(days: durationDays ?? kQuestDurationDays)),
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
  ///
  /// Returns whether any quest actually changed, so a caller that follows
  /// this with a full gamification recompute (see
  /// `XpEngineOrchestrator.expireOverdueQuests`) can skip it on the common
  /// no-op call — most opens of the Quests screen find nothing overdue, and
  /// the recompute is real disk I/O the app has no reason to pay for then.
  Future<bool> expireOverdueQuests({DateTime? now}) async {
    final today = now ?? DateTime.now();
    var changed = false;
    for (final quest in active) {
      if (!quest.endDate.isBefore(today)) continue;
      quest.status = quest.type == QuestType.budgetLimit
          ? QuestStatus.completed
          : QuestStatus.expired;
      await quest.save();
      changed = true;
    }
    return changed;
  }

  /// Rule-based quest generation, entirely offline (PRD section 7) — see
  /// core/utils/quest_template_engine.dart for the actual rule engine and
  /// template library; this just supplies the transaction data.
  List<QuestCandidate> generateCandidates(
    List<Transaction> allTransactions, {
    required int currentStreak,
    DateTime? now,
    int maxCandidates = 3,
    String currencySymbol = '₹',
  }) {
    return generateQuestCandidates(
      allTransactions: allTransactions,
      currentStreak: currentStreak,
      activeQuests: active,
      now: now,
      maxCandidates: maxCandidates,
      currencySymbol: currencySymbol,
    );
  }

  /// Wipes every quest — the JSON backup restore's write path, which
  /// replaces the box wholesale rather than merging.
  Future<void> clear() => _box.clear();

  /// Writes every quest in [quests] by id, overwriting any existing row
  /// with the same id. Same reasoning as `TransactionRepository.putAll`.
  Future<void> putAll(Iterable<Quest> quests) {
    return _box.putAll({for (final q in quests) q.id: q});
  }
}
