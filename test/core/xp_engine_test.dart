import 'package:broke_no_more/core/utils/xp_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateTransactionLogXp', () {
    test('base log XP with no quick-log bonus', () {
      expect(
        calculateTransactionLogXp(logsAlreadyToday: 0, isQuickLog: false),
        kBaseLogXp,
      );
    });

    test('adds quick-log bonus', () {
      expect(
        calculateTransactionLogXp(logsAlreadyToday: 0, isQuickLog: true),
        kBaseLogXp + kQuickLogBonusXp,
      );
    });

    test('caps out at kMaxXpEligibleLogsPerDay', () {
      expect(
        calculateTransactionLogXp(
          logsAlreadyToday: kMaxXpEligibleLogsPerDay,
          isQuickLog: true,
        ),
        0,
      );
    });
  });

  group('xpForLevel / levelForXp', () {
    test('level 1 is completed at 100 xp', () {
      expect(xpForLevel(1), 100);
    });

    test('a brand-new profile with 0 xp is level 1, not negative progress', () {
      expect(levelForXp(0), 1);
      final progress = levelProgressForXp(0);
      expect(progress.level, 1);
      expect(progress.xpIntoLevel, 0);
      expect(progress.xpForNextLevel, 100);
    });

    test('levelForXp advances once a level\'s threshold is reached', () {
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(levelForXp(299), 2);
      expect(levelForXp(300), 3);
    });

    test('levelProgressForXp reports progress into the current level', () {
      final progress = levelProgressForXp(xpForLevel(2) + 50);
      expect(progress.level, 3);
      expect(progress.xpIntoLevel, 50);
      expect(progress.xpForNextLevel, xpForLevel(3) - xpForLevel(2));
    });
  });

  group('evaluateStreak', () {
    final monday = DateTime(2026, 8, 17);
    final tuesday = DateTime(2026, 8, 18);
    final wednesday = DateTime(2026, 8, 19);
    final thursday = DateTime(2026, 8, 20);

    test('same-day log does not advance the streak again', () {
      final result = evaluateStreak(
        lastLogged: monday,
        today: monday,
        currentStreak: 3,
        freezesLeft: 1,
      );
      expect(result.newStreak, 3);
      expect(result.streakAdvancedToday, isFalse);
    });

    test('one-day gap advances the streak', () {
      final result = evaluateStreak(
        lastLogged: monday,
        today: tuesday,
        currentStreak: 3,
        freezesLeft: 1,
      );
      expect(result.newStreak, 4);
      expect(result.streakAdvancedToday, isTrue);
      expect(result.freezeUsed, isFalse);
    });

    test('two-day gap with a freeze available preserves the streak', () {
      final result = evaluateStreak(
        lastLogged: monday,
        today: wednesday,
        currentStreak: 3,
        freezesLeft: 1,
      );
      expect(result.newStreak, 4);
      expect(result.freezeUsed, isTrue);
      expect(result.freezesLeft, 0);
      expect(result.streakBroken, isFalse);
    });

    test('two-day gap with no freeze left breaks the streak', () {
      final result = evaluateStreak(
        lastLogged: monday,
        today: wednesday,
        currentStreak: 3,
        freezesLeft: 0,
      );
      expect(result.newStreak, 1);
      expect(result.streakBroken, isTrue);
    });

    test('gap greater than two days breaks the streak even with a freeze', () {
      final result = evaluateStreak(
        lastLogged: monday,
        today: thursday,
        currentStreak: 5,
        freezesLeft: 1,
      );
      expect(result.newStreak, 1);
      expect(result.streakBroken, isTrue);
      expect(result.freezeUsed, isFalse);
    });
  });

  group('dailyBudgetFor', () {
    test('prorates by the actual month length, not a flat /30', () {
      // February 2026 (non-leap) has 28 days: 2800/28 = 100/day, not
      // 2800/30 ≈ 93.33 — the mismatch that used to let Home's "on track"
      // pill disagree with whether the engine paid out the budget bonus.
      expect(dailyBudgetFor(2800, DateTime(2026, 2, 15)), 100);
    });

    test('a 31-day month gives a smaller daily share than a 30-day month', () {
      final jan = dailyBudgetFor(3100, DateTime(2026, 1, 15));
      final apr = dailyBudgetFor(3100, DateTime(2026, 4, 15));
      expect(jan, lessThan(apr));
    });
  });

  group('shouldAwardDailyBudgetBonus', () {
    final today = DateTime(2026, 8, 22);

    test('false when no budget is set', () {
      expect(
        shouldAwardDailyBudgetBonus(
          monthlyBudget: null,
          spentToday: 0,
          lastBudgetBonusDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('true when spend is within the daily share of the budget', () {
      expect(
        shouldAwardDailyBudgetBonus(
          monthlyBudget: 3000,
          spentToday: 50,
          lastBudgetBonusDate: null,
          today: today,
        ),
        isTrue,
      );
    });

    test('false once already awarded today', () {
      expect(
        shouldAwardDailyBudgetBonus(
          monthlyBudget: 3000,
          spentToday: 50,
          lastBudgetBonusDate: today,
          today: today,
        ),
        isFalse,
      );
    });
  });

  group('shouldResetWeeklyFreeze', () {
    test('false before 7 days have passed', () {
      expect(
        shouldResetWeeklyFreeze(
          lastFreezeResetDate: DateTime(2026, 8, 17),
          today: DateTime(2026, 8, 22),
        ),
        isFalse,
      );
    });

    test('true once 7 days have passed', () {
      expect(
        shouldResetWeeklyFreeze(
          lastFreezeResetDate: DateTime(2026, 8, 15),
          today: DateTime(2026, 8, 22),
        ),
        isTrue,
      );
    });
  });
}
