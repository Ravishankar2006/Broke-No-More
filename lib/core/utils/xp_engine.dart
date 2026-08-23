/// Pure XP/streak/level logic — no Flutter or Riverpod dependency, per the
/// PRD's key design decision (section 8), so it stays independently
/// unit-testable. Callers (providers) own persistence and orchestration.
library;

import 'date_helpers.dart';

/// XP awarded for logging any transaction.
const int kBaseLogXp = 5;

/// Extra XP for logging within [kQuickLogWindowMinutes] of the transaction's
/// own timestamp.
const int kQuickLogBonusXp = 5;

/// XP awarded once per calendar day the streak advances.
const int kStreakDayXp = 10;

/// XP awarded for staying under the daily budget.
const int kUnderBudgetXp = 15;

const int kQuickLogWindowMinutes = 30;

/// Streak freezes granted per 7-day window. See [shouldResetWeeklyFreeze].
const int kWeeklyStreakFreezeAllowance = 1;

/// Anti-abuse cap: only the first [kMaxXpEligibleLogsPerDay] logs in a
/// calendar day earn transaction-logging XP (base + quick-log bonus).
const int kMaxXpEligibleLogsPerDay = 10;

/// XP earned from logging a single transaction, given how many
/// XP-eligible transactions were already logged today ([logsAlreadyToday],
/// not counting this one) and whether this one qualifies as a quick log.
int calculateTransactionLogXp({
  required int logsAlreadyToday,
  required bool isQuickLog,
}) {
  if (logsAlreadyToday >= kMaxXpEligibleLogsPerDay) return 0;
  return kBaseLogXp + (isQuickLog ? kQuickLogBonusXp : 0);
}

/// Total XP required to *complete* level [n] and advance to level n+1.
/// xpForLevel(n) = 100 * n * (n + 1) / 2
int xpForLevel(int n) => 100 * n * (n + 1) ~/ 2;

/// Level implied by a given total XP. Everyone starts at level 1 with 0 XP;
/// xp >= xpForLevel(k) means level k has been completed.
int levelForXp(int xp) {
  var level = 1;
  while (xpForLevel(level) <= xp) {
    level++;
  }
  return level;
}

/// XP already consumed by the current level, and XP needed for the next —
/// used to render the XP progress bar.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get fraction => xpForNextLevel == 0 ? 0 : xpIntoLevel / xpForNextLevel;
}

LevelProgress levelProgressForXp(int xp) {
  final level = levelForXp(xp);
  final floor = level == 1 ? 0 : xpForLevel(level - 1);
  final ceil = xpForLevel(level);
  return LevelProgress(
    level: level,
    xpIntoLevel: xp - floor,
    xpForNextLevel: ceil - floor,
  );
}

/// Result of evaluating a new log against the current streak state.
class StreakResult {
  const StreakResult({
    required this.newStreak,
    required this.freezesLeft,
    required this.freezeUsed,
    required this.streakBroken,
    required this.streakAdvancedToday,
  });

  final int newStreak;
  final int freezesLeft;
  final bool freezeUsed;
  final bool streakBroken;

  /// True only when this evaluation is what pushed the streak forward for
  /// today (i.e. today's XP/streak-day reward should be granted).
  final bool streakAdvancedToday;
}

/// Evaluates how logging today affects the streak.
///
/// - Same day as [lastLogged]: streak already counted for today, no change.
/// - Exactly 1 day gap: streak continues, increments by 1.
/// - Exactly 2 day gap with a freeze available: the missed day is covered by
///   a streak freeze, streak still increments by 1.
/// - Any larger gap (or a 2-day gap with no freeze left): streak resets to 1.
StreakResult evaluateStreak({
  required DateTime lastLogged,
  required DateTime today,
  required int currentStreak,
  required int freezesLeft,
}) {
  final gap = daysBetween(lastLogged, today);

  if (gap <= 0) {
    return StreakResult(
      newStreak: currentStreak == 0 ? 1 : currentStreak,
      freezesLeft: freezesLeft,
      freezeUsed: false,
      streakBroken: false,
      streakAdvancedToday: currentStreak == 0,
    );
  }

  if (gap == 1) {
    return StreakResult(
      newStreak: currentStreak + 1,
      freezesLeft: freezesLeft,
      freezeUsed: false,
      streakBroken: false,
      streakAdvancedToday: true,
    );
  }

  if (gap == 2 && freezesLeft > 0) {
    return StreakResult(
      newStreak: currentStreak + 1,
      freezesLeft: freezesLeft - 1,
      freezeUsed: true,
      streakBroken: false,
      streakAdvancedToday: true,
    );
  }

  return StreakResult(
    newStreak: 1,
    freezesLeft: freezesLeft,
    freezeUsed: false,
    streakBroken: true,
    streakAdvancedToday: true,
  );
}

/// Whether today's "stay under daily budget" XP bonus should be granted:
/// only once per calendar day, and only when a budget is actually set.
bool shouldAwardDailyBudgetBonus({
  required double? monthlyBudget,
  required double spentToday,
  required DateTime? lastBudgetBonusDate,
  required DateTime today,
}) {
  if (monthlyBudget == null || monthlyBudget <= 0) return false;
  if (lastBudgetBonusDate != null && isSameDay(lastBudgetBonusDate, today)) {
    return false;
  }
  final dailyBudget = monthlyBudget / 30;
  return spentToday <= dailyBudget;
}

/// Whether the weekly streak-freeze allowance should reset: once per 7-day
/// window from [lastFreezeResetDate]. (Open question in the PRD — v1 treats
/// it as a rolling 7-day reset back up to 1, not accumulating.)
bool shouldResetWeeklyFreeze({
  required DateTime lastFreezeResetDate,
  required DateTime today,
}) {
  return daysBetween(lastFreezeResetDate, today) >= 7;
}
