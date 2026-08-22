/// Quest template library and candidate generation — no Flutter/Riverpod or
/// Hive dependency, same reasoning as the other *_engine.dart files. PRD
/// section 7 specifies the rule ("compare last 7 days per category against
/// the user's own historical average") and gives two example phrasings;
/// this is the fleshed-out template library plus the fallback path for
/// users who don't have enough history yet for a category comparison.
library;

import '../../models/quest.dart';
import '../../models/transaction.dart';
import 'date_helpers.dart';

const int kQuestDurationDays = 7;

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

const List<String> _categoryAvoidTemplates = [
  'No {category} spending for {days} days',
  'Go {days} days without {category}',
  '{days}-day {category} detox',
];

const List<String> _budgetLimitTemplates = [
  'Spend under ₹{limit} on {category} this week',
  'Keep {category} spending below ₹{limit} this week',
  'Cap your {category} spend at ₹{limit} this week',
];

const List<String> _streakTemplates = [
  'Keep your streak alive for {days} more days',
  'Log something every day for the next {days} days',
];

const List<String> _countTemplates = [
  'Log {count} transactions this week',
  'Hit {count} logs before the week is out',
];

String _fill(String template, Map<String, String> vars) {
  var result = template;
  for (final entry in vars.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

/// Deterministic variant pick so the same category always phrases the same
/// way within a suggestion batch, but different categories/quests vary —
/// keeps the function pure (no [Random]) and testable.
String _pickVariant(List<String> templates, int seed) {
  return templates[seed.abs() % templates.length];
}

/// Generates 2-3 quest candidates from the user's own transaction history
/// (PRD section 7):
/// 1. Group last-7-days expenses by category.
/// 2. Compare each category's last-7-days spend against its own historical
///    weekly average (from everything logged before that window).
/// 3. Offending categories (over their own average) become quest
///    candidates via the local template library.
/// 4. If there isn't 7+ days of prior history yet to compare against, or
///    fewer than [maxCandidates] categories are offending, fill the rest
///    with general streak/count quests so new users still see something —
///    supports the "week-one hook" habit-formation goal (PRD section 2/6)
///    instead of leaving Quests empty until a full history exists.
///
/// [activeQuests] (type, category) pairs are excluded from the results so
/// an already-accepted quest doesn't keep reappearing as a suggestion.
List<QuestCandidate> generateQuestCandidates({
  required List<Transaction> allTransactions,
  required int currentStreak,
  List<Quest> activeQuests = const [],
  DateTime? now,
  int maxCandidates = 3,
}) {
  final today = now ?? DateTime.now();
  final windowStart = startOfDay(today).subtract(const Duration(days: 6));
  final activeSignatures = activeQuests.map((q) => (q.type, q.category)).toSet();

  final recentExpenses = allTransactions
      .where((t) => t.type == TransactionType.expense)
      .where((t) => !startOfDay(t.timestamp).isBefore(windowStart))
      .toList();
  final olderExpenses = allTransactions
      .where((t) => t.type == TransactionType.expense)
      .where((t) => startOfDay(t.timestamp).isBefore(windowStart))
      .toList();

  final candidates = <QuestCandidate>[];

  if (olderExpenses.isNotEmpty) {
    candidates.addAll(_categoryCandidates(
      recentExpenses: recentExpenses,
      olderExpenses: olderExpenses,
      windowStart: windowStart,
      maxCandidates: maxCandidates,
      activeSignatures: activeSignatures,
    ));
  }

  if (candidates.length < maxCandidates) {
    candidates.addAll(_generalCandidates(
      allTransactions: allTransactions,
      currentStreak: currentStreak,
      activeSignatures: activeSignatures,
      windowStart: windowStart,
      count: maxCandidates - candidates.length,
    ));
  }

  return candidates;
}

List<QuestCandidate> _categoryCandidates({
  required List<Transaction> recentExpenses,
  required List<Transaction> olderExpenses,
  required DateTime windowStart,
  required int maxCandidates,
  required Set<(QuestType, String?)> activeSignatures,
}) {
  final recentByCategory = <String, double>{};
  for (final t in recentExpenses) {
    recentByCategory[t.category] = (recentByCategory[t.category] ?? 0) + t.amount;
  }

  final oldestDate =
      olderExpenses.map((t) => t.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
  final priorWeeks = (daysBetween(oldestDate, windowStart) / 7).ceil().clamp(1, 1000);

  final historicalByCategory = <String, double>{};
  for (final t in olderExpenses) {
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
  for (final entry in offenders) {
    if (candidates.length >= maxCandidates) break;

    final category = entry.key;
    if (activeSignatures.contains((QuestType.categoryAvoid, category)) ||
        activeSignatures.contains((QuestType.budgetLimit, category))) {
      continue;
    }

    final avg = historicalWeeklyAvg[category]!;
    final seed = category.hashCode;
    final useAvoid = candidates.length.isEven;

    if (useAvoid) {
      const days = 3;
      candidates.add(QuestCandidate(
        title: _fill(_pickVariant(_categoryAvoidTemplates, seed), {
          'category': category,
          'days': '$days',
        }),
        type: QuestType.categoryAvoid,
        targetValue: days,
        xpReward: 75,
        category: category,
      ));
    } else {
      final limit = (avg * 0.8).ceil().clamp(1, 1 << 30);
      candidates.add(QuestCandidate(
        title: _fill(_pickVariant(_budgetLimitTemplates, seed), {
          'category': category,
          'limit': '$limit',
        }),
        type: QuestType.budgetLimit,
        targetValue: limit,
        xpReward: 50,
        category: category,
      ));
    }
  }
  return candidates;
}

List<QuestCandidate> _generalCandidates({
  required List<Transaction> allTransactions,
  required int currentStreak,
  required DateTime windowStart,
  required int count,
  required Set<(QuestType, String?)> activeSignatures,
}) {
  if (count <= 0) return const [];

  final olderLogs =
      allTransactions.where((t) => startOfDay(t.timestamp).isBefore(windowStart)).toList();
  int weeklyLogTarget;
  if (olderLogs.isEmpty) {
    weeklyLogTarget = 5;
  } else {
    final oldestDate =
        olderLogs.map((t) => t.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
    final priorWeeks = (daysBetween(oldestDate, windowStart) / 7).ceil().clamp(1, 1000);
    final avgWeeklyLogs = olderLogs.length / priorWeeks;
    weeklyLogTarget = (avgWeeklyLogs * 1.2).ceil().clamp(3, 1 << 30);
  }

  final streakTarget = currentStreak + 3;

  final general = <QuestCandidate>[
    if (!activeSignatures.contains((QuestType.streak, null)))
      QuestCandidate(
        title: _fill(_pickVariant(_streakTemplates, streakTarget), {
          'days': '${streakTarget - currentStreak}',
        }),
        type: QuestType.streak,
        targetValue: streakTarget,
        xpReward: 50,
      ),
    if (!activeSignatures.contains((QuestType.count, null)))
      QuestCandidate(
        title: _fill(_pickVariant(_countTemplates, weeklyLogTarget), {
          'count': '$weeklyLogTarget',
        }),
        type: QuestType.count,
        targetValue: weeklyLogTarget,
        xpReward: 50,
      ),
  ];

  return general.take(count).toList();
}
