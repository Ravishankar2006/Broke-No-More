import 'package:broke_no_more/core/utils/quest_template_engine.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _expense(String category, double amount, DateTime day) {
  return Transaction(
    id: '$category-$amount-$day',
    amount: amount,
    type: TransactionType.expense,
    category: category,
    timestamp: day,
    loggedAt: day,
    isQuickLog: true,
  );
}

Quest _activeQuest(QuestType type, String? category, DateTime day) {
  return Quest(
    id: '$type-$category',
    title: 'existing',
    type: type,
    targetValue: 5,
    startDate: day,
    endDate: day.add(const Duration(days: 7)),
    xpReward: 50,
    category: category,
  );
}

void main() {
  final today = DateTime(2026, 8, 22);

  group('with no transaction history', () {
    test('falls back to general streak/count candidates', () {
      final candidates = generateQuestCandidates(
        allTransactions: const [],
        currentStreak: 2,
        now: today,
      );

      expect(candidates, hasLength(2));
      expect(candidates.map((c) => c.type), containsAll([QuestType.streak, QuestType.count]));
    });

    test('streak candidate targets a few days beyond the current streak', () {
      final candidates = generateQuestCandidates(
        allTransactions: const [],
        currentStreak: 2,
        now: today,
      );
      final streakCandidate = candidates.firstWhere((c) => c.type == QuestType.streak);
      expect(streakCandidate.targetValue, 5);
      expect(streakCandidate.title, isNot(contains('{')));
    });

    test('count candidate uses a sane default target with no history', () {
      final candidates = generateQuestCandidates(
        allTransactions: const [],
        currentStreak: 0,
        now: today,
      );
      final countCandidate = candidates.firstWhere((c) => c.type == QuestType.count);
      expect(countCandidate.targetValue, greaterThanOrEqualTo(3));
      expect(countCandidate.title, isNot(contains('{')));
    });
  });

  group('with prior history but nothing overspent this week', () {
    test('fills in with general candidates instead of an empty list', () {
      final priorWeek = today.subtract(const Duration(days: 14));
      final transactions = [
        _expense('Food', 100, priorWeek),
        _expense('Food', 50, today.subtract(const Duration(days: 1))),
      ];

      final candidates = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 1,
        now: today,
      );

      expect(candidates, isNotEmpty);
      expect(candidates.every((c) => c.category == null), isTrue);
    });
  });

  group('with an overspending category', () {
    test('generates a category-based candidate referencing that category', () {
      final priorWeek = today.subtract(const Duration(days: 14));
      final transactions = [
        _expense('Food', 100, priorWeek),
        _expense('Food', 500, today.subtract(const Duration(days: 1))),
      ];

      final candidates = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 0,
        now: today,
      );

      final categoryCandidate = candidates.firstWhere((c) => c.category == 'Food');
      expect(categoryCandidate.type,
          anyOf(QuestType.categoryAvoid, QuestType.budgetLimit));
      expect(categoryCandidate.title, contains('Food'));
      expect(categoryCandidate.title, isNot(contains('{')));
    });

    test('fills remaining slots with general candidates when few categories offend', () {
      final priorWeek = today.subtract(const Duration(days: 14));
      final transactions = [
        _expense('Food', 100, priorWeek),
        _expense('Food', 500, today.subtract(const Duration(days: 1))),
      ];

      final candidates = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 3,
        now: today,
        maxCandidates: 3,
      );

      expect(candidates, hasLength(3));
      expect(candidates.where((c) => c.category == 'Food'), hasLength(1));
      expect(candidates.where((c) => c.category == null), hasLength(2));
    });

    test('never exceeds maxCandidates even with many offending categories', () {
      final priorWeek = today.subtract(const Duration(days: 14));
      final transactions = [
        for (final category in ['Food', 'Transport', 'Shopping', 'Bills']) ...[
          _expense(category, 100, priorWeek),
          _expense(category, 500, today.subtract(const Duration(days: 1))),
        ],
      ];

      final candidates = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 0,
        now: today,
        maxCandidates: 3,
      );

      expect(candidates.length, lessThanOrEqualTo(3));
    });
  });

  group('excluding already-active quests', () {
    test('does not re-suggest a general quest type that is already active', () {
      final candidates = generateQuestCandidates(
        allTransactions: const [],
        currentStreak: 1,
        activeQuests: [_activeQuest(QuestType.streak, null, today)],
        now: today,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.type, QuestType.count);
    });

    test('does not re-suggest an already-active category quest', () {
      final priorWeek = today.subtract(const Duration(days: 14));
      final transactions = [
        _expense('Food', 100, priorWeek),
        _expense('Food', 500, today.subtract(const Duration(days: 1))),
      ];

      final candidatesWithNoActive = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 0,
        now: today,
      );
      final foodCandidate = candidatesWithNoActive.firstWhere((c) => c.category == 'Food');

      final candidatesWithActive = generateQuestCandidates(
        allTransactions: transactions,
        currentStreak: 0,
        activeQuests: [_activeQuest(foodCandidate.type, 'Food', today)],
        now: today,
      );

      expect(candidatesWithActive.any((c) => c.category == 'Food'), isFalse);
    });
  });
}
