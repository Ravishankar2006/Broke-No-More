import 'package:broke_no_more/core/utils/badge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has no duplicate ids', () {
    final ids = kBadgeCatalog.map((b) => b.id).toSet();
    expect(ids.length, kBadgeCatalog.length);
  });

  group('evaluateNewlyUnlockedBadges', () {
    test('unlocks the first-log badge on the very first transaction', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 1,
        currentStreak: 1,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      expect(unlocked.map((b) => b.id), contains('first_log'));
    });

    test('does not re-unlock badges already earned', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 1,
        currentStreak: 1,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {'first_log'},
      );
      expect(unlocked, isEmpty);
    });

    test('unlocks every threshold crossed at once', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 10,
        currentStreak: 1,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      expect(unlocked.map((b) => b.id), containsAll(['first_log', 'logs_10']));
    });

    test('streak badge unlocks at its threshold', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 0,
        currentStreak: 7,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      final ids = unlocked.map((b) => b.id);
      expect(ids, containsAll(['streak_3', 'streak_7']));
      expect(ids, isNot(contains('streak_30')));
    });

    test('level badge unlocks at its threshold', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 0,
        currentStreak: 0,
        level: 5,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      expect(unlocked.map((b) => b.id), contains('level_5'));
    });

    test('quest badge unlocks at its threshold', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 0,
        currentStreak: 0,
        level: 1,
        questsCompleted: 1,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      expect(unlocked.map((b) => b.id), contains('quest_first'));
    });

    test('budget badge unlocks at its threshold', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 0,
        currentStreak: 0,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 7,
        alreadyUnlockedIds: {},
      );
      expect(unlocked.map((b) => b.id), contains('budget_week'));
    });

    test('nothing unlocks below every threshold', () {
      final unlocked = evaluateNewlyUnlockedBadges(
        transactionCount: 0,
        currentStreak: 0,
        level: 1,
        questsCompleted: 0,
        daysUnderBudget: 0,
        alreadyUnlockedIds: {},
      );
      expect(unlocked, isEmpty);
    });
  });
}
