import 'package:broke_no_more/core/utils/quest_engine.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  required double amount,
  required String category,
  TransactionType type = TransactionType.expense,
  DateTime? timestamp,
}) {
  return Transaction(
    id: 't',
    amount: amount,
    type: type,
    category: category,
    timestamp: timestamp ?? DateTime(2026, 8, 22),
    loggedAt: timestamp ?? DateTime(2026, 8, 22),
    isQuickLog: true,
  );
}

Quest _quest({
  required QuestType type,
  required int targetValue,
  String? category,
  int currentProgress = 0,
  DateTime? startDate,
}) {
  return Quest(
    id: 'q',
    title: 'test quest',
    type: type,
    targetValue: targetValue,
    currentProgress: currentProgress,
    startDate: startDate ?? DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 27),
    xpReward: 50,
  ).also((q) => q.category = category);
}

extension _Also<T> on T {
  T also(void Function(T) block) {
    block(this);
    return this;
  }
}

void main() {
  group('categoryAvoid', () {
    test('a matching-category expense fails the quest', () {
      final quest = _quest(type: QuestType.categoryAvoid, targetValue: 3, category: 'Food');
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 100, category: 'Food'),
        categorySpendSinceStart: 100,
        transactionCountSinceStart: 1,
        currentStreak: 2,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.failed);
    });

    test('an unrelated transaction advances days-survived progress', () {
      final quest = _quest(
        type: QuestType.categoryAvoid,
        targetValue: 3,
        category: 'Food',
        startDate: DateTime(2026, 8, 20),
      );
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 50, category: 'Transport'),
        categorySpendSinceStart: 0,
        transactionCountSinceStart: 1,
        currentStreak: 2,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.completed);
      expect(result.progress, 3);
    });
  });

  group('budgetLimit', () {
    test('exceeding the target fails the quest', () {
      final quest =
          _quest(type: QuestType.budgetLimit, targetValue: 500, category: 'Shopping');
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 200, category: 'Shopping'),
        categorySpendSinceStart: 600,
        transactionCountSinceStart: 3,
        currentStreak: 1,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.failed);
    });

    test('staying under target keeps the quest active', () {
      final quest =
          _quest(type: QuestType.budgetLimit, targetValue: 500, category: 'Shopping');
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 100, category: 'Shopping'),
        categorySpendSinceStart: 300,
        transactionCountSinceStart: 2,
        currentStreak: 1,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.active);
      expect(result.progress, 300);
    });

    test('irrelevant category is a no-op', () {
      final quest =
          _quest(type: QuestType.budgetLimit, targetValue: 500, category: 'Shopping');
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 100, category: 'Food'),
        categorySpendSinceStart: 300,
        transactionCountSinceStart: 2,
        currentStreak: 1,
        today: DateTime(2026, 8, 22),
      );
      expect(result, isNull);
    });
  });

  group('count', () {
    test('completes once the target count is reached', () {
      final quest = _quest(type: QuestType.count, targetValue: 5);
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 20, category: 'Food'),
        categorySpendSinceStart: 0,
        transactionCountSinceStart: 5,
        currentStreak: 1,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.completed);
    });
  });

  group('streak', () {
    test('completes once currentStreak reaches the target', () {
      final quest = _quest(type: QuestType.streak, targetValue: 7);
      final result = evaluateQuestAfterTransaction(
        quest: quest,
        transaction: _tx(amount: 20, category: 'Food'),
        categorySpendSinceStart: 0,
        transactionCountSinceStart: 1,
        currentStreak: 7,
        today: DateTime(2026, 8, 22),
      );
      expect(result!.status, QuestStatus.completed);
    });
  });

  test('non-active quests are left untouched', () {
    final quest = _quest(type: QuestType.count, targetValue: 5)
      ..status = QuestStatus.completed;
    final result = evaluateQuestAfterTransaction(
      quest: quest,
      transaction: _tx(amount: 20, category: 'Food'),
      categorySpendSinceStart: 0,
      transactionCountSinceStart: 5,
      currentStreak: 1,
      today: DateTime(2026, 8, 22),
    );
    expect(result, isNull);
  });
}
