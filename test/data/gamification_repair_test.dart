import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/data/badge_repository.dart';
import 'package:broke_no_more/data/gamification_repair.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/data/quest_repository.dart';
import 'package:broke_no_more/data/transaction_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/xp_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Guards the single most load-bearing untested invariant in the app: the
/// boot-time repair pass (`repairGamificationState`, run before anything is
/// watching — see its own doc comment) and the live orchestrator's
/// `_recomputeAndPersist` (run after every mutation) are two independent
/// implementations of "replay the transaction list into XP/streak/quests/
/// badges". `combineXpWithQuests`'s doc comment says outright that if they
/// ever compute differently, one silently erases XP the other granted — and
/// nothing but this test enforces they don't.
///
/// Rather than asserting on one hand-picked scenario, this feeds both an
/// identical, varied seed — a multi-day streak with gaps, a same-day
/// XP-cap overflow, quick logs, income, a monthly budget, and one quest of
/// each type — into two fresh, independent Hive instances, and asserts
/// every field either path can touch ends up identical.
void main() {
  late DateTime now;
  late DateTime joinDate;

  setUp(() {
    now = DateTime.now();
    joinDate = now.subtract(const Duration(days: 12));
  });

  // Every transaction is dated at least 1 day before `now`, so which exact
  // wall-clock instant `asOf` lands on inside `repairGamificationState` vs.
  // the orchestrator's `updateMonthlyBudget` never matters — both always see
  // the same set of "past" days.
  DateTime at(int daysAgo, int hour, [int minute = 0]) {
    final base = now.subtract(Duration(days: daysAgo));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  List<Transaction> buildTransactions() {
    final list = <Transaction>[
      Transaction(
        id: 't1',
        amount: 80,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: at(10, 9),
        loggedAt: at(10, 9),
        isQuickLog: true,
      ),
      Transaction(
        id: 't2',
        amount: 40,
        type: TransactionType.expense,
        category: 'Transport',
        timestamp: at(10, 18),
        loggedAt: at(10, 19),
        isQuickLog: false,
      ),
      Transaction(
        id: 't3',
        amount: 500,
        type: TransactionType.income,
        category: 'Salary',
        timestamp: at(8, 10),
        loggedAt: at(8, 10),
        isQuickLog: true,
      ),
      Transaction(
        id: 't4',
        amount: 60,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: at(5, 12),
        loggedAt: at(5, 12),
        isQuickLog: false,
      ),
      Transaction(
        id: 't5',
        amount: 20,
        type: TransactionType.expense,
        category: 'Entertainment',
        timestamp: at(3, 8),
        loggedAt: at(3, 30),
        isQuickLog: false,
      ),
    ];

    // Day -6: 11 same-day logs, so the 10-logs/day XP-eligibility cap
    // (kMaxXpEligibleLogsPerDay) actually bites during replay.
    for (var i = 0; i < 11; i++) {
      list.add(
        Transaction(
          id: 'cap$i',
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          timestamp: at(6, 8, i),
          loggedAt: at(6, 8, i),
          isQuickLog: true,
        ),
      );
    }

    list.addAll([
      Transaction(
        id: 't6',
        amount: 45,
        type: TransactionType.expense,
        category: 'Shopping',
        timestamp: at(2, 14),
        loggedAt: at(2, 40),
        isQuickLog: false,
      ),
      Transaction(
        id: 't7',
        amount: 25,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: at(1, 9),
        loggedAt: at(1, 9),
        isQuickLog: true,
      ),
    ]);

    return list;
  }

  List<Quest> buildQuests() {
    return [
      // Satisfiable by the seed above — settles as `completed` in both
      // paths, exercising the quest-XP fold in `combineXpWithQuests`.
      Quest(
        id: 'q_count',
        title: 'Log 3 transactions',
        type: QuestType.count,
        targetValue: 3,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 2)),
        xpReward: 60,
      ),
      // Stays active — proves both paths agree on leaving it untouched too,
      // not just on completions.
      Quest(
        id: 'q_avoid',
        title: 'No Entertainment for 3 days',
        type: QuestType.categoryAvoid,
        targetValue: 3,
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
        xpReward: 75,
        category: 'Entertainment',
      ),
      // budgetLimit quests never resolve to `completed` inside a replay
      // (only `QuestRepository.expireOverdueQuests` does that) — included to
      // prove both paths agree on *not* completing it early.
      Quest(
        id: 'q_budget',
        title: 'Keep Food under 200',
        type: QuestType.budgetLimit,
        targetValue: 200,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 2)),
        xpReward: 50,
        category: 'Food',
      ),
    ];
  }

  Future<void> seed() async {
    final profile = UserProfile(
      id: kLocalProfileKey,
      name: 'Test',
      avatarId: '🦊',
      joinDate: joinDate,
      monthlyBudget: 3000,
    );
    await Hive.box<UserProfile>(HiveBoxes.profile)
        .put(kLocalProfileKey, profile);
    await TransactionRepository().putAll(buildTransactions());
    for (final q in buildQuests()) {
      await Hive.box<Quest>(HiveBoxes.quests).put(q.id, q);
    }
  }

  Future<_Snapshot> runRepairPath() async {
    final dir = await Directory.systemTemp.createTemp('repair_parity_a');
    Hive.init(dir.path);
    _registerAdapters();
    await _openBoxes();

    await seed();
    await repairGamificationState();
    final snapshot = _Snapshot.capture();

    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
    return snapshot;
  }

  Future<_Snapshot> runOrchestratorPath() async {
    final dir = await Directory.systemTemp.createTemp('repair_parity_b');
    Hive.init(dir.path);
    _registerAdapters();
    await _openBoxes();

    await seed();
    final container = ProviderContainer();
    // A same-value budget "change" still routes through the full
    // `_recomputeAndPersist` pipeline without perturbing the seeded
    // transaction list — the orchestrator's closest equivalent to a
    // from-scratch replay, since every other entry point requires an actual
    // transaction mutation.
    await container
        .read(xpEngineOrchestratorProvider)
        .updateMonthlyBudget(3000);
    container.dispose();
    final snapshot = _Snapshot.capture();

    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
    return snapshot;
  }

  test('repairGamificationState and the live orchestrator agree on every '
      'field, given the same transactions/profile/quests', () async {
    final fromRepair = await runRepairPath();
    final fromOrchestrator = await runOrchestratorPath();

    expect(fromRepair, fromOrchestrator);
  });
}

void _registerAdapters() {
  if (Hive.isAdapterRegistered(0)) return;
  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(QuestTypeAdapter());
  Hive.registerAdapter(QuestStatusAdapter());
  Hive.registerAdapter(QuestAdapter());
  Hive.registerAdapter(BadgeAdapter());
  Hive.registerAdapter(CategoryRecordAdapter());
  Hive.registerAdapter(RecurrenceFrequencyAdapter());
  Hive.registerAdapter(RecurringTransactionAdapter());
}

Future<void> _openBoxes() async {
  await Hive.openBox<Transaction>(HiveBoxes.transactions);
  await Hive.openBox<UserProfile>(HiveBoxes.profile);
  await Hive.openBox<Quest>(HiveBoxes.quests);
  await Hive.openBox<Badge>(HiveBoxes.badges);
  await Hive.openBox<dynamic>(HiveBoxes.appState);
  await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
  await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
}

/// Every field either `repairGamificationState` or the orchestrator can
/// write, captured from disk after the run — plus a few they only ever
/// read/leave untouched, included as a belt-and-braces check. Equality and
/// `toString()` are keyed off the same field list, so a mismatch prints a
/// readable per-field diff instead of an opaque "not equal".
class _Snapshot {
  _Snapshot({
    required this.currentXP,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastLoggedDate,
    required this.streakFreezesLeft,
    required this.lastFreezeResetDate,
    required this.lastBudgetBonusDate,
    required this.daysUnderBudgetCount,
    required this.badgeIds,
    required this.unlockedBadgeIds,
    required this.questStates,
    required this.xpByTransactionId,
  });

  factory _Snapshot.capture() {
    final profile = ProfileRepository().current!;
    final quests = QuestRepository().getAll();
    final transactions = TransactionRepository().getAll();
    return _Snapshot(
      currentXP: profile.currentXP,
      level: profile.level,
      currentStreak: profile.currentStreak,
      longestStreak: profile.longestStreak,
      lastLoggedDate: profile.lastLoggedDate,
      streakFreezesLeft: profile.streakFreezesLeft,
      lastFreezeResetDate: profile.lastFreezeResetDate,
      lastBudgetBonusDate: profile.lastBudgetBonusDate,
      daysUnderBudgetCount: profile.daysUnderBudgetCount,
      badgeIds: List<String>.of(profile.badgeIds)..sort(),
      unlockedBadgeIds: List<String>.of(BadgeRepository().unlockedIds)..sort(),
      questStates: {
        for (final q in quests..sort((a, b) => a.id.compareTo(b.id)))
          q.id: '${q.status}:${q.currentProgress}',
      },
      xpByTransactionId: {
        for (final t in transactions..sort((a, b) => a.id.compareTo(b.id)))
          t.id: t.xpAwarded ?? -1,
      },
    );
  }

  final int currentXP;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime lastLoggedDate;
  final int streakFreezesLeft;
  final DateTime lastFreezeResetDate;
  final DateTime? lastBudgetBonusDate;
  final int daysUnderBudgetCount;
  final List<String> badgeIds;
  final List<String> unlockedBadgeIds;
  final Map<String, String> questStates;
  final Map<String, int> xpByTransactionId;

  @override
  String toString() =>
      'currentXP=$currentXP level=$level currentStreak=$currentStreak '
      'longestStreak=$longestStreak lastLoggedDate=$lastLoggedDate '
      'streakFreezesLeft=$streakFreezesLeft '
      'lastFreezeResetDate=$lastFreezeResetDate '
      'lastBudgetBonusDate=$lastBudgetBonusDate '
      'daysUnderBudgetCount=$daysUnderBudgetCount badgeIds=$badgeIds '
      'unlockedBadgeIds=$unlockedBadgeIds questStates=$questStates '
      'xpByTransactionId=$xpByTransactionId';

  @override
  bool operator ==(Object other) =>
      other is _Snapshot && toString() == other.toString();

  @override
  int get hashCode => toString().hashCode;
}
