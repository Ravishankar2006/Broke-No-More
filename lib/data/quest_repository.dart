import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/date_helpers.dart';
import '../models/quest.dart';
import '../models/transaction.dart';

const _uuid = Uuid();
const int _kQuestDurationDays = 7;

/// A generated-but-not-yet-accepted quest suggestion. Kept separate from
/// [Quest] so the rule engine can produce candidates without touching
/// persistence — the user has to accept one before it becomes a real Quest
/// (PRD section 7: "Never auto-assigned/forced").
class QuestCandidate {
  const QuestCandidate({
    required this.title,
    required this.type,
    required this.targetValue,
    required this.xpReward,
    this.category,
  });

  final String title;
  final QuestType type;
  final int targetValue;
  final int xpReward;
  final String? category;
}

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
      endDate: start.add(const Duration(days: _kQuestDurationDays)),
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

  /// Rule-based quest generation, entirely offline (PRD section 7):
  /// 1. Group last-7-days transactions by category.
  /// 2. Compare each category's last-7-days spend against its own
  ///    historical weekly average (from everything logged before that).
  /// 3. Offending categories (over their own average) become quest
  ///    candidates via the local template library.
  /// 4. Return 2-3 candidates; caller lets the user accept/skip.
  List<QuestCandidate> generateCandidates(
    List<Transaction> allTransactions, {
    DateTime? now,
    int maxCandidates = 3,
  }) {
    final today = now ?? DateTime.now();
    final windowStart = startOfDay(today).subtract(const Duration(days: 6));

    final recent = allTransactions
        .where((t) => t.type == TransactionType.expense)
        .where((t) => !startOfDay(t.timestamp).isBefore(windowStart))
        .toList();
    final older = allTransactions
        .where((t) => t.type == TransactionType.expense)
        .where((t) => startOfDay(t.timestamp).isBefore(windowStart))
        .toList();

    if (older.isEmpty) return const [];

    final recentByCategory = <String, double>{};
    for (final t in recent) {
      recentByCategory[t.category] = (recentByCategory[t.category] ?? 0) + t.amount;
    }

    final oldestDate = older.map((t) => t.timestamp).reduce(
        (a, b) => a.isBefore(b) ? a : b);
    final priorWeeks =
        (daysBetween(oldestDate, windowStart) / 7).ceil().clamp(1, 1000);

    final historicalByCategory = <String, double>{};
    for (final t in older) {
      historicalByCategory[t.category] =
          (historicalByCategory[t.category] ?? 0) + t.amount;
    }
    final historicalWeeklyAvg = historicalByCategory.map(
      (category, total) => MapEntry(category, total / priorWeeks),
    );

    final offenders = <MapEntry<String, double>>[];
    recentByCategory.forEach((category, spend) {
      final avg = historicalWeeklyAvg[category];
      if (avg != null && spend > avg) {
        offenders.add(MapEntry(category, spend - avg));
      }
    });
    offenders.sort((a, b) => b.value.compareTo(a.value));

    final candidates = <QuestCandidate>[];
    for (final entry in offenders.take(maxCandidates)) {
      final category = entry.key;
      final avg = historicalWeeklyAvg[category]!;
      final target = (avg * 0.8).ceil().clamp(1, 1 << 30);
      final useAvoid = candidates.length.isEven;
      candidates.add(
        useAvoid
            ? QuestCandidate(
                title: 'No $category spending for 3 days',
                type: QuestType.categoryAvoid,
                targetValue: 3,
                xpReward: 75,
                category: category,
              )
            : QuestCandidate(
                title: 'Spend under ₹$target on $category this week',
                type: QuestType.budgetLimit,
                targetValue: target,
                xpReward: 50,
                category: category,
              ),
      );
    }

    return candidates;
  }
}
