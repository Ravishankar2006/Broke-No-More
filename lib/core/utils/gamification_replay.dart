/// Recomputes all transaction-derived gamification state from scratch.
///
/// Pure Dart — no Flutter, Hive or Riverpod — for the same reason as
/// [xp_engine.dart] and [quest_engine.dart]: it must be unit-testable without
/// widget or provider scaffolding.
///
/// ## Why this exists
///
/// Until transactions became editable, XP was a pure accumulator: every log
/// added to `profile.currentXP` and nothing ever subtracted. That is unsound the
/// moment a transaction can be deleted, because the anti-abuse cap is derived
/// from the *live* row count (`TransactionRepository.countForDay`). Log ten,
/// delete ten, log ten again, and the cap never bites — an unbounded XP faucet.
///
/// Reversing a single log incrementally isn't possible either: nothing records
/// whether a given transaction was inside the day's first
/// [kMaxXpEligibleLogsPerDay], whether it was the one that advanced the streak,
/// or whether it pushed the day over budget. Reconstructing that means replaying
/// the history anyway — so replay it directly, and get idempotency for free.
///
/// ## What this owns, and what it doesn't
///
/// Recomputed here: XP, level, current streak, last logged day, budget-bonus
/// bookkeeping, and per-transaction XP.
///
/// **Ratcheted by the caller, never here:** unlocked badges, `longestStreak`
/// (the PRD says it never resets), and completed quests. Those may already have
/// fired a celebration; revoking them would be worse than being slightly
/// generous. This function reports [ReplayResult.longestStreakSeen] as an
/// observation — the caller is responsible for taking the max against the stored
/// value.
///
/// **Simulated from a fixed seed:** streak-freeze state. It is tempting to carry
/// the live profile's freeze count in as a starting value, but that is unsound:
/// the stored value was itself produced by an earlier replay, so a 2-day gap
/// that consumed a freeze once would find none available on the next replay and
/// retroactively break a streak that had already been awarded. Instead the walk
/// always starts from a full allowance at `joinDate` and re-derives the whole
/// freeze history, which makes the result a pure function of the transaction
/// list and therefore idempotent.
library;

import '../../models/transaction.dart';
import 'date_helpers.dart';
import 'xp_engine.dart';

/// Everything [replayGamification] needs. Deliberately a value object with no
/// repository access so the engine stays pure and trivially testable.
class ReplayInput {
  const ReplayInput({
    required this.transactions,
    required this.joinDate,
    required this.monthlyBudget,
    required this.asOf,
  });

  /// Every transaction, in any order — this function sorts internally.
  final List<Transaction> transactions;

  /// Seeds the streak walk. A fresh profile has `lastLoggedDate == joinDate`
  /// and `currentStreak == 0`, and replay reproduces that starting point.
  final DateTime joinDate;

  /// Budget in force. Applied retroactively to every historical day, because
  /// there is no budget-change history to consult — see the class docs on
  /// [ReplayResult.daysUnderBudgetCount].
  final double? monthlyBudget;

  /// "Now", injectable so tests don't depend on the wall clock. Days after this
  /// are not replayed: a future-dated transaction earns nothing until its day
  /// actually arrives, at which point a later replay picks it up.
  final DateTime asOf;
}

class ReplayResult {
  const ReplayResult({
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.longestStreakSeen,
    required this.lastLoggedDay,
    required this.daysUnderBudgetCount,
    required this.lastBudgetBonusDate,
    required this.streakFreezesLeft,
    required this.lastFreezeResetDate,
    required this.xpByTransactionId,
  });

  final int totalXp;
  final int level;
  final int currentStreak;

  /// The high-water mark *observed during this replay*. The caller must take
  /// `max(storedLongestStreak, longestStreakSeen)` rather than assigning it
  /// directly — deleting history must never lower a record.
  final int longestStreakSeen;

  /// Day of the most recent transaction, or null when there are none.
  ///
  /// Note this is genuinely different from the value the old incremental path
  /// stored: that one recorded the wall-clock moment the user pressed save, so
  /// deleting today's only transaction left the profile claiming a live streak
  /// while the streak calendar — which reads the transaction list — showed today
  /// empty. Both now derive from the same source.
  final DateTime? lastLoggedDay;

  /// Approximate: depends on the budget in force on each historical day, and no
  /// such history is kept. Acceptable for a single-user offline app; a
  /// budget-change log would be the fix if it ever mattered.
  final int daysUnderBudgetCount;

  final DateTime? lastBudgetBonusDate;
  final int streakFreezesLeft;
  final DateTime lastFreezeResetDate;

  /// XP attributable to each transaction, keyed by id. Transactions dated after
  /// [ReplayInput.asOf], or beyond the daily cap, map to 0.
  final Map<String, int> xpByTransactionId;
}

/// Replays [input] and returns the resulting gamification state.
///
/// Cost is one sort plus two linear passes with no I/O — the transactions box is
/// already fully in memory (`Hive.openBox`, not `LazyBox`). The one thing that
/// would wreck this is calling the repository's per-day helpers inside the day
/// loop; each rescans the whole box, turning an O(N log N) walk into O(N·days).
/// Hence the single grouping pass below.
ReplayResult replayGamification(ReplayInput input) {
  final asOfDay = startOfDay(input.asOf);

  // Group by transaction day in one pass, ignoring anything dated in the future.
  final byDay = <DateTime, List<Transaction>>{};
  final xpById = <String, int>{};
  for (final t in input.transactions) {
    xpById[t.id] = 0; // default; future-dated rows keep this
    final day = startOfDay(t.timestamp);
    if (day.isAfter(asOfDay)) continue;
    (byDay[day] ??= <Transaction>[]).add(t);
  }

  final days = byDay.keys.toList()..sort();

  var totalXp = 0;
  var currentStreak = 0;
  var longestStreakSeen = 0;
  var daysUnderBudget = 0;
  DateTime? lastBudgetBonusDate;
  // Seeded from joinDate, never from stored state — see the class docs.
  var freezesLeft = kWeeklyStreakFreezeAllowance;
  var freezeResetDate = startOfDay(input.joinDate);
  var lastLogged = startOfDay(input.joinDate);
  DateTime? lastLoggedDay;

  for (final day in days) {
    // Weekly freeze allowance. Single `if`, not a `while`, matching the live
    // path — harmless either way since the allowance caps at 1.
    if (shouldResetWeeklyFreeze(
      lastFreezeResetDate: freezeResetDate,
      today: day,
    )) {
      freezesLeft = kWeeklyStreakFreezeAllowance;
      freezeResetDate = day;
    }

    final streak = evaluateStreak(
      lastLogged: lastLogged,
      today: day,
      currentStreak: currentStreak,
      freezesLeft: freezesLeft,
    );
    if (streak.streakAdvancedToday) {
      totalXp += kStreakDayXp;
    }
    currentStreak = streak.newStreak;
    freezesLeft = streak.freezesLeft;

    // Intra-day order decides which logs fall inside the anti-abuse cap.
    // loggedAt can collide within a millisecond, so id is the stable tiebreak —
    // without it the cap could award XP to a different subset on each replay
    // and break idempotency.
    final sameDay = byDay[day]!
      ..sort((a, b) {
        final byLoggedAt = a.loggedAt.compareTo(b.loggedAt);
        return byLoggedAt != 0 ? byLoggedAt : a.id.compareTo(b.id);
      });

    for (var i = 0; i < sameDay.length; i++) {
      final t = sameDay[i];
      final xp = calculateTransactionLogXp(
        logsAlreadyToday: i,
        isQuickLog: t.isQuickLog,
      );
      totalXp += xp;
      xpById[t.id] = xp;
    }

    final spent = sameDay
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    if (shouldAwardDailyBudgetBonus(
      monthlyBudget: input.monthlyBudget,
      spentToday: spent,
      lastBudgetBonusDate: lastBudgetBonusDate,
      today: day,
    )) {
      totalXp += kUnderBudgetXp;
      lastBudgetBonusDate = day;
      daysUnderBudget += 1;
    }

    if (currentStreak > longestStreakSeen) {
      longestStreakSeen = currentStreak;
    }
    lastLogged = day;
    lastLoggedDay = day;
  }

  return ReplayResult(
    totalXp: totalXp,
    level: levelForXp(totalXp),
    currentStreak: currentStreak,
    longestStreakSeen: longestStreakSeen,
    lastLoggedDay: lastLoggedDay,
    daysUnderBudgetCount: daysUnderBudget,
    lastBudgetBonusDate: lastBudgetBonusDate,
    streakFreezesLeft: freezesLeft,
    lastFreezeResetDate: freezeResetDate,
    xpByTransactionId: xpById,
  );
}
