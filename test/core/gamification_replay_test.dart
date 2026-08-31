import 'package:broke_no_more/core/utils/gamification_replay.dart';
import 'package:broke_no_more/core/utils/quest_engine.dart';
import 'package:broke_no_more/core/utils/xp_engine.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// All dates are anchored to this so nothing depends on the wall clock.
final join = DateTime(2026, 1, 1);
DateTime day(int n) => DateTime(2026, 1, 1).add(Duration(days: n));

var _seq = 0;

Transaction tx({
  required int onDay,
  double amount = 100,
  TransactionType type = TransactionType.expense,
  String category = 'Food',
  bool isQuickLog = false,
  String? id,
  DateTime? loggedAt,
}) {
  _seq++;
  return Transaction(
    id: id ?? 't$_seq',
    amount: amount,
    type: type,
    category: category,
    timestamp: day(onDay).add(const Duration(hours: 12)),
    // Distinct and increasing, so intra-day ordering is deterministic.
    loggedAt: loggedAt ?? day(onDay).add(Duration(hours: 12, seconds: _seq)),
    isQuickLog: isQuickLog,
  );
}

ReplayResult replay(
  List<Transaction> transactions, {
  double? monthlyBudget,
  int asOfDay = 30,
}) {
  return replayGamification(
    ReplayInput(
      transactions: transactions,
      joinDate: join,
      monthlyBudget: monthlyBudget,
      asOf: day(asOfDay),
    ),
  );
}

void main() {
  setUp(() => _seq = 0);

  group('XP accounting', () {
    test('awards a streak day plus per-log XP for each logged day', () {
      final result = replay([tx(onDay: 0), tx(onDay: 1), tx(onDay: 2)]);

      // 3 days x (kStreakDayXp + one non-quick log).
      expect(result.totalXp, 3 * (kStreakDayXp + kBaseLogXp));
      expect(result.currentStreak, 3);
      expect(result.longestStreakSeen, 3);
      expect(result.lastLoggedDay, day(2));
    });

    test('grants the quick-log bonus only to quick logs', () {
      final result = replay([tx(onDay: 0, isQuickLog: true)]);
      expect(result.totalXp, kStreakDayXp + kBaseLogXp + kQuickLogBonusXp);
    });

    test('caps XP-eligible logs per day', () {
      final many = List.generate(
        kMaxXpEligibleLogsPerDay + 5,
        (_) => tx(onDay: 0, amount: 1),
      );
      final result = replay(many);

      expect(
        result.totalXp,
        kStreakDayXp + kMaxXpEligibleLogsPerDay * kBaseLogXp,
        reason: 'logs past the cap must earn nothing',
      );
      final earned = result.xpByTransactionId.values
          .where((xp) => xp > 0)
          .length;
      expect(earned, kMaxXpEligibleLogsPerDay);
    });

    test('caps by transaction day, not by when the log was entered', () {
      // The exploit this closes: the old path counted "logs already today"
      // against the wall clock while filtering by timestamp, so backdating
      // sidestepped the cap entirely.
      final backdated = List.generate(
        kMaxXpEligibleLogsPerDay + 5,
        (i) => tx(
          onDay: 3,
          amount: 1,
          // All entered "now", long after the day they're dated for.
          loggedAt: day(9).add(Duration(seconds: i)),
        ),
      );
      final result = replay(backdated);

      expect(
        result.totalXp,
        kStreakDayXp + kMaxXpEligibleLogsPerDay * kBaseLogXp,
        reason: 'backdating must not bypass the per-day cap',
      );
    });

    test('ignores transactions dated after asOf until that day arrives', () {
      final future = tx(onDay: 20);
      final before = replay([future], asOfDay: 10);
      expect(before.totalXp, 0);
      expect(before.xpByTransactionId[future.id], 0);
      expect(before.lastLoggedDay, isNull);

      final after = replay([future], asOfDay: 25);
      expect(after.totalXp, kStreakDayXp + kBaseLogXp);
    });
  });

  group('the delete-and-relog exploit', () {
    test('XP depends only on the surviving list, never on history', () {
      final original = List.generate(
        kMaxXpEligibleLogsPerDay,
        (_) => tx(onDay: 0, amount: 1),
      );
      final first = replay(original);

      // Delete all ten and log ten fresh ones on the same day. Under the old
      // accumulator this doubled the day's XP; under replay it must not move.
      final replacements = List.generate(
        kMaxXpEligibleLogsPerDay,
        (_) => tx(onDay: 0, amount: 1),
      );
      final second = replay(replacements);

      expect(second.totalXp, first.totalXp);
    });

    test('deleting a transaction removes exactly its contribution', () {
      final keep = tx(onDay: 0);
      final drop = tx(onDay: 0);

      final both = replay([keep, drop]);
      final onlyKeep = replay([keep]);

      expect(both.totalXp - onlyKeep.totalXp, kBaseLogXp);
    });
  });

  group('streak', () {
    test('a one-day gap continues the streak', () {
      final result = replay([tx(onDay: 0), tx(onDay: 1)]);
      expect(result.currentStreak, 2);
      expect(result.streakFreezesLeft, kWeeklyStreakFreezeAllowance);
    });

    test('a two-day gap consumes a freeze instead of breaking', () {
      final result = replay([tx(onDay: 0), tx(onDay: 2)]);
      expect(result.currentStreak, 2);
      expect(result.streakFreezesLeft, 0);
    });

    test('a three-day gap resets the streak', () {
      final result = replay([tx(onDay: 0), tx(onDay: 3)]);
      expect(result.currentStreak, 1);
    });

    test('freeze state is re-derived, not carried from stored state', () {
      // Regression guard. Seeding the freeze count from the profile meant the
      // stored value — already decremented by a previous replay — was fed back
      // in, so the same 2-day gap found no freeze the second time and
      // retroactively broke a streak the user had already been awarded.
      final transactions = [tx(onDay: 0), tx(onDay: 2)];

      final first = replay(transactions);
      final second = replay(transactions);

      expect(first.currentStreak, 2);
      expect(second.currentStreak, first.currentStreak);
      expect(second.streakFreezesLeft, first.streakFreezesLeft);
    });

    test('the weekly allowance refreshes, letting a later gap be absorbed', () {
      // Two 2-day gaps more than a week apart: both should be covered.
      final result = replay([
        tx(onDay: 0),
        tx(onDay: 2),
        tx(onDay: 12),
        tx(onDay: 14),
      ]);
      // day0 -> day2 freeze, day2 -> day12 resets streak, day12 -> day14 freeze.
      expect(result.currentStreak, 2);
    });

    test('lastLoggedDay follows the transaction list, not the clock', () {
      final today = tx(onDay: 5);
      final withToday = replay([tx(onDay: 4), today], asOfDay: 5);
      expect(withToday.lastLoggedDay, day(5));

      // Deleting the only transaction of the latest day must retract it.
      final without = replay([tx(onDay: 4)], asOfDay: 5);
      expect(without.lastLoggedDay, day(4));
    });

    test('an empty list returns to a pristine state', () {
      final result = replay([]);
      expect(result.totalXp, 0);
      expect(result.level, 1);
      expect(result.currentStreak, 0);
      expect(result.lastLoggedDay, isNull);
      expect(result.lastBudgetBonusDate, isNull);
    });
  });

  group('daily budget bonus', () {
    test('awards once per day when under the daily allowance', () {
      // 3000 prorated over January's 31 days ≈ 96.8/day.
      final result = replay([
        tx(onDay: 0, amount: 50),
        tx(onDay: 1, amount: 50),
      ], monthlyBudget: 3000);
      expect(result.daysUnderBudgetCount, 2);
      expect(result.lastBudgetBonusDate, day(1));
      expect(result.totalXp, 2 * (kStreakDayXp + kBaseLogXp + kUnderBudgetXp));
    });

    test('withholds the bonus on a day that went over', () {
      final result = replay([
        tx(onDay: 0, amount: 50),
        tx(onDay: 1, amount: 500),
      ], monthlyBudget: 3000);
      expect(result.daysUnderBudgetCount, 1);
      expect(result.lastBudgetBonusDate, day(0));
    });

    test('counts a day once regardless of how many logs it holds', () {
      final result = replay([
        tx(onDay: 0, amount: 10),
        tx(onDay: 0, amount: 10),
      ], monthlyBudget: 3000);
      expect(result.daysUnderBudgetCount, 1);
    });

    test('income does not count against the daily spend', () {
      final result = replay([
        tx(onDay: 0, amount: 5000, type: TransactionType.income),
      ], monthlyBudget: 3000);
      expect(result.daysUnderBudgetCount, 1);
    });

    test('no budget set means no bonus', () {
      final result = replay([tx(onDay: 0, amount: 1)]);
      expect(result.daysUnderBudgetCount, 0);
    });
  });

  group('determinism', () {
    test('is idempotent across repeated runs', () {
      final transactions = [
        tx(onDay: 0),
        tx(onDay: 0),
        tx(onDay: 2),
        tx(onDay: 3, type: TransactionType.income),
        tx(onDay: 9),
      ];

      final a = replay(transactions, monthlyBudget: 3000);
      final b = replay(transactions, monthlyBudget: 3000);

      expect(b.totalXp, a.totalXp);
      expect(b.level, a.level);
      expect(b.currentStreak, a.currentStreak);
      expect(b.longestStreakSeen, a.longestStreakSeen);
      expect(b.daysUnderBudgetCount, a.daysUnderBudgetCount);
      expect(b.streakFreezesLeft, a.streakFreezesLeft);
      expect(b.xpByTransactionId, a.xpByTransactionId);
    });

    test('is independent of input ordering', () {
      final transactions = [tx(onDay: 2), tx(onDay: 0), tx(onDay: 1)];
      final forward = replay(transactions);
      final reversed = replay(transactions.reversed.toList());

      expect(reversed.totalXp, forward.totalXp);
      expect(reversed.currentStreak, forward.currentStreak);
      expect(reversed.xpByTransactionId, forward.xpByTransactionId);
    });

    test('ties on loggedAt resolve by id so the cap is stable', () {
      final collide = DateTime(2026, 1, 1, 12);
      final transactions = List.generate(
        kMaxXpEligibleLogsPerDay + 3,
        (i) => tx(
          onDay: 0,
          id: 'id-${i.toString().padLeft(2, '0')}',
          loggedAt: collide,
        ),
      );

      final a = replay(transactions);
      final b = replay(transactions.reversed.toList());

      expect(
        b.xpByTransactionId,
        a.xpByTransactionId,
        reason: 'identical loggedAt must not make the cap order-dependent',
      );
    });

    test('longestStreakSeen observes the peak, not the final value', () {
      // Peaks at 3, then a long gap resets to 1.
      final result = replay([
        tx(onDay: 0),
        tx(onDay: 1),
        tx(onDay: 2),
        tx(onDay: 20),
      ], asOfDay: 25);

      expect(result.currentStreak, 1);
      expect(
        result.longestStreakSeen,
        3,
        reason: 'the caller ratchets against this, so it must report the peak',
      );
    });
  });

  group('level', () {
    test('tracks total XP through the level curve', () {
      expect(replay([]).level, 1);

      // Enough days to clear level 1 (100 XP).
      final week = List.generate(8, (i) => tx(onDay: i));
      final result = replay(week);
      expect(result.totalXp, 8 * (kStreakDayXp + kBaseLogXp));
      expect(result.level, levelForXp(result.totalXp));
      expect(result.level, greaterThan(1));
    });
  });

  group('replayQuest', () {
    Quest quest({
      required QuestType type,
      int target = 3,
      String? category,
      QuestStatus status = QuestStatus.active,
      int progress = 0,
      int startDay = 0,
      int endDay = 7,
    }) {
      return Quest(
        id: 'q1',
        title: 'q',
        type: type,
        targetValue: target,
        currentProgress: progress,
        startDate: day(startDay),
        endDate: day(endDay),
        xpReward: 50,
        status: status,
        category: category,
      );
    }

    test('categoryAvoid fails when an offending expense exists', () {
      final result = replayQuest(
        quest: quest(type: QuestType.categoryAvoid, category: 'Food'),
        transactions: [tx(onDay: 1, category: 'Food')],
        currentStreak: 1,
        asOf: day(2),
      );
      expect(result.status, QuestStatus.failed);
    });

    test('categoryAvoid recovers once the offending expense is removed', () {
      // The whole reason quest replay exists: the incremental path latched to
      // failed and never came back, so deleting the transaction left a quest
      // permanently failed with no evidence against it.
      final q = quest(
        type: QuestType.categoryAvoid,
        category: 'Food',
        status: QuestStatus.failed,
      );

      final result = replayQuest(
        quest: q,
        transactions: [tx(onDay: 1, category: 'Transport')],
        currentStreak: 1,
        asOf: day(1),
      );
      expect(result.status, QuestStatus.active);
    });

    test(
      'categoryAvoid does not fail on the transaction that prompted the '
      'suggestion — same-day spending logged before acceptance is exempt',
      () {
        // The starter candidate is generated *from* a recent expense — a
        // categoryAvoid quest accepted the same day must not immediately
        // fail because of the very transaction that led to the suggestion.
        final startDate = day(0).add(const Duration(hours: 15));
        final q = Quest(
          id: 'q1',
          title: 'q',
          type: QuestType.categoryAvoid,
          targetValue: 3,
          currentProgress: 0,
          startDate: startDate,
          endDate: day(3),
          xpReward: 100,
          category: 'Food',
        );

        Transaction foodExpenseAt(DateTime timestamp) => Transaction(
          id: 't-same-day',
          amount: 500,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: timestamp,
          loggedAt: timestamp,
          isQuickLog: false,
        );

        final beforeAcceptance = replayQuest(
          quest: q,
          transactions: [foodExpenseAt(day(0).add(const Duration(hours: 10)))],
          currentStreak: 1,
          asOf: day(0),
        );
        expect(beforeAcceptance.status, QuestStatus.active);

        final afterAcceptance = replayQuest(
          quest: q,
          transactions: [foodExpenseAt(day(0).add(const Duration(hours: 18)))],
          currentStreak: 1,
          asOf: day(0),
        );
        expect(afterAcceptance.status, QuestStatus.failed);
      },
    );

    test('categoryAvoid completes once the full window is clean', () {
      final result = replayQuest(
        quest: quest(
          type: QuestType.categoryAvoid,
          target: 3,
          category: 'Food',
        ),
        transactions: [tx(onDay: 1, category: 'Transport')],
        currentStreak: 1,
        asOf: day(2),
      );
      expect(result.progress, 3);
      expect(result.status, QuestStatus.completed);
    });

    test('completed quests are sticky', () {
      final result = replayQuest(
        quest: quest(
          type: QuestType.count,
          target: 5,
          status: QuestStatus.completed,
          progress: 5,
        ),
        transactions: const [],
        currentStreak: 0,
        asOf: day(3),
      );
      expect(result.status, QuestStatus.completed);
      expect(result.progress, 5);
    });

    test('expired quests are left alone', () {
      final result = replayQuest(
        quest: quest(type: QuestType.count, status: QuestStatus.expired),
        transactions: [tx(onDay: 1), tx(onDay: 2), tx(onDay: 3)],
        currentStreak: 3,
        asOf: day(9),
      );
      expect(result.status, QuestStatus.expired);
    });

    test('budgetLimit re-derives spend and can recover from failed', () {
      final failed = quest(
        type: QuestType.budgetLimit,
        target: 100,
        category: 'Food',
        status: QuestStatus.failed,
      );

      final over = replayQuest(
        quest: failed,
        transactions: [tx(onDay: 1, category: 'Food', amount: 250)],
        currentStreak: 1,
        asOf: day(2),
      );
      expect(over.status, QuestStatus.failed);
      expect(over.progress, 250);

      final under = replayQuest(
        quest: failed,
        transactions: [tx(onDay: 1, category: 'Food', amount: 40)],
        currentStreak: 1,
        asOf: day(2),
      );
      expect(under.status, QuestStatus.active);
      expect(under.progress, 40);
    });

    test('count ignores transactions outside the quest window', () {
      final result = replayQuest(
        quest: quest(type: QuestType.count, target: 3, startDay: 2, endDay: 4),
        transactions: [
          tx(onDay: 0), // before start
          tx(onDay: 3), // inside
          tx(onDay: 9), // after end
        ],
        currentStreak: 1,
        asOf: day(9),
      );
      expect(result.progress, 1);
      expect(result.status, QuestStatus.active);
    });

    test('streak quests read the replayed streak', () {
      final result = replayQuest(
        quest: quest(type: QuestType.streak, target: 3),
        transactions: const [],
        currentStreak: 4,
        asOf: day(3),
      );
      expect(result.progress, 3, reason: 'clamped to the target');
      expect(result.status, QuestStatus.completed);
    });
  });
}
