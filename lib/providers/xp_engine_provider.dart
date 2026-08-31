import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/streak_reminder_service.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/date_helpers.dart';
import '../core/utils/gamification_replay.dart';
import '../core/utils/quest_engine.dart';
import '../data/quest_repository.dart' show QuestCandidate;
import '../data/recurring_transaction_repository.dart';
import '../data/transaction_repository.dart';
import '../models/quest.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import 'badge_provider.dart';
import 'profile_provider.dart';
import 'quest_provider.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';

/// Result of any transaction mutation — lets the UI react to XP gains, badge
/// unlocks and level-ups without the orchestrator knowing about widgets.
class LogTransactionResult {
  const LogTransactionResult({
    required this.transaction,
    required this.xpGained,
    required this.newlyUnlockedBadges,
    required this.leveledUpTo,
    required this.completedQuests,
    required this.freezeConsumed,
  });

  /// The affected transaction; null for a delete.
  final Transaction? transaction;

  /// Change in total XP. Can be negative — editing an amount upward can revoke
  /// a budget bonus, and deleting revokes whatever the row earned. The UI should
  /// only celebrate a positive value.
  final int xpGained;

  final List<BadgeDefinition> newlyUnlockedBadges;

  /// Non-null only when the level went *up*. Levels can drop after a delete, but
  /// there is no "you lost a level" moment — that would be punitive, which the
  /// PRD rules out.
  final int? leveledUpTo;

  /// Quests that reached `completed` during this mutation, for celebration.
  final List<Quest> completedQuests;

  /// Whether this mutation's replay consumed a streak freeze to cover a
  /// missed day — see [_RecomputeOutcome.freezeConsumed] for how this is
  /// detected. Was computed and persisted since day one but never surfaced
  /// to the UI at all.
  final bool freezeConsumed;
}

/// Result of a bulk [XpEngineOrchestrator.importTransactions] call — the
/// same downstream fields as [LogTransactionResult], but for a batch of rows
/// rather than one.
class ImportResult {
  const ImportResult({
    required this.importedCount,
    required this.xpGained,
    required this.newlyUnlockedBadges,
    required this.leveledUpTo,
    required this.completedQuests,
  });

  final int importedCount;
  final int xpGained;
  final List<BadgeDefinition> newlyUnlockedBadges;
  final int? leveledUpTo;
  final List<Quest> completedQuests;
}

/// What [XpEngineOrchestrator._recomputeAndPersist] produces — the shared
/// tail both a single mutation and a bulk import build their own public
/// result type from.
class _RecomputeOutcome {
  const _RecomputeOutcome({
    required this.totals,
    required this.newlyUnlockedBadges,
    required this.completedQuests,
    required this.freezeConsumed,
  });

  final GamificationTotals totals;
  final List<BadgeDefinition> newlyUnlockedBadges;
  final List<Quest> completedQuests;

  /// True when this replay's `streakFreezesLeft` dropped from the
  /// pre-mutation value *within the same weekly window* (same
  /// `lastFreezeResetDate`) — the only way the count can decrease other
  /// than the weekly reset, which this rules out by comparing the reset
  /// date too. Reliable for the common case (a single new same-or-later
  /// day added on top of already-replayed history); a backdated edit that
  /// retroactively changes an earlier day's gap evaluation could in theory
  /// confuse a single before/after diff, same caveat the replay's own docs
  /// give for its other approximations.
  final bool freezeConsumed;
}

/// Orchestrates every mutation to the transaction log.
///
/// All three entry points — [logTransaction], [updateTransaction],
/// [deleteTransaction] — funnel through the same [_mutate], which replays
/// the gamification state from the full transaction list rather than
/// accumulating deltas. See [replayGamification] for why an incremental approach
/// isn't sound once transactions can be edited or deleted.
///
/// Because create and mutate share one path, they cannot drift apart: there is
/// exactly one implementation of "what is this user's XP".
class XpEngineOrchestrator {
  XpEngineOrchestrator(this._ref);

  final Ref _ref;

  /// Serialises every gamification-affecting mutation through one queue.
  /// Edit and delete can be triggered by rapid taps on a list row, and two
  /// overlapping replays would both read the pre-mutation profile and race
  /// to write it back.
  ///
  /// Previously a boolean `_busy` flag rejected a second concurrent call
  /// outright (`throw StateError`), which the UI could only surface as a
  /// "please try again" snackbar for something that should just work. A
  /// queue instead runs the second call right after the first completes.
  Future<void> _queue = Future.value();

  /// Chains [action] onto the queue and returns its result. The queue's own
  /// continuation must never itself throw, or every mutation enqueued after
  /// a failed one would reject immediately without [action] ever running —
  /// so failures are swallowed on the *queue* side while still propagating
  /// through the [Future] returned to the caller.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<LogTransactionResult> logTransaction({
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required DateTime timestamp,
  }) {
    return _enqueue(
      () => _mutate((repo) async {
        return await repo.add(
          amount: amount,
          type: type,
          category: category,
          note: note,
          timestamp: timestamp,
        );
      }),
    );
  }

  /// Applies an edit. Omitted fields keep their current value; pass
  /// [clearNote] to remove a note rather than passing null, which is
  /// indistinguishable from "unchanged".
  Future<LogTransactionResult> updateTransaction({
    required String id,
    double? amount,
    TransactionType? type,
    String? category,
    String? note,
    bool clearNote = false,
    DateTime? timestamp,
  }) {
    return _enqueue(
      () => _mutate((repo) async {
        final existing = repo.getById(id);
        if (existing == null) {
          throw StateError('updateTransaction: no transaction with id $id');
        }
        return repo.update(
          existing,
          amount: amount,
          type: type,
          category: category,
          note: note,
          clearNote: clearNote,
          timestamp: timestamp,
        );
      }),
    );
  }

  Future<LogTransactionResult> deleteTransaction(String id) {
    return _enqueue(
      () => _mutate((repo) async {
        await repo.delete(id);
        return null;
      }),
    );
  }

  /// Deletes every id in [ids] as one mutation — History's multi-select bulk
  /// delete. Deliberately one [_mutate] call (one replay) rather than N
  /// calls to [deleteTransaction], which would replay the whole
  /// transaction list once per row and flash through N intermediate XP
  /// states the user never actually held.
  Future<LogTransactionResult> deleteTransactions(List<String> ids) {
    return _enqueue(
      () => _mutate((repo) async {
        for (final id in ids) {
          await repo.delete(id);
        }
        return null;
      }),
    );
  }

  /// Writes [transactions] back exactly as they were — the delete
  /// snackbar's Undo action. Reuses [TransactionRepository.putAll] (already
  /// built for "here are exact rows, write them back") rather than
  /// re-creating them through [logTransaction], which would mint new ids
  /// and could double-count anti-abuse-cap XP for the day.
  Future<LogTransactionResult> restoreTransactions(
    List<Transaction> transactions,
  ) {
    return _enqueue(
      () => _mutate((repo) async {
        await repo.putAll(transactions);
        return transactions.isEmpty ? null : transactions.first;
      }),
    );
  }

  /// Writes a batch of externally-sourced transactions (CSV import) and
  /// recomputes everything downstream, same as a single log — the only
  /// difference is [TransactionRepository.putAll] replaces the single-row
  /// `change` closure [_mutate] takes.
  ///
  /// [transactions] must already be conflict-resolved by the caller: any id
  /// also present on the device is overwritten outright. Nothing here decides
  /// what counts as a conflict.
  Future<ImportResult> importTransactions(List<Transaction> transactions) {
    return _enqueue(() async {
      final now = DateTime.now();
      final transactionRepo = _ref.read(transactionRepositoryProvider);

      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError('import attempted before a profile exists');
      }
      final beforeQuestIds = _completedQuestIds();

      await transactionRepo.putAll(transactions);
      _ref.read(transactionsProvider.notifier).refresh();

      final outcome = await _recomputeAndPersist(
        now: now,
        before: before,
        beforeQuestIds: beforeQuestIds,
      );

      return ImportResult(
        importedCount: transactions.length,
        xpGained: outcome.totals.totalXp - before.currentXP,
        newlyUnlockedBadges: outcome.newlyUnlockedBadges,
        leveledUpTo: outcome.totals.level > before.level
            ? outcome.totals.level
            : null,
        completedQuests: outcome.completedQuests,
      );
    });
  }

  /// Changes (or clears, when [monthlyBudget] is null) the monthly budget and
  /// immediately recomputes everything that depends on it.
  ///
  /// Previously a budget edit just wrote the new value and stopped — XP,
  /// `daysUnderBudgetCount` and the Budget Boss badge all stayed stale until
  /// the user's next transaction, silently jumping only then.
  Future<void> updateMonthlyBudget(double? monthlyBudget) {
    return _enqueue(() async {
      final now = DateTime.now();
      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError(
          'updateMonthlyBudget attempted before a profile exists',
        );
      }
      final beforeQuestIds = _completedQuestIds();

      final withNewBudget = before.copyWith(
        monthlyBudget: monthlyBudget,
        clearMonthlyBudget: monthlyBudget == null,
      );

      await _recomputeAndPersist(
        now: now,
        before: withNewBudget,
        beforeQuestIds: beforeQuestIds,
      );
    });
  }

  /// Persists an accepted quest candidate, then runs the same recompute
  /// every other mutation does — currently a no-op for XP/streak/badges
  /// (a freshly accepted quest always starts at zero progress), but this
  /// keeps quest acceptance on the single entry point every other
  /// gamification-affecting action goes through, rather than writing to the
  /// quests box directly and hoping nothing downstream ever comes to depend
  /// on accept-time state.
  Future<Quest> acceptQuest(QuestCandidate candidate, {int? durationDays}) {
    return _enqueue(() async {
      final now = DateTime.now();
      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError('acceptQuest attempted before a profile exists');
      }
      final beforeQuestIds = _completedQuestIds();

      final quest = await _ref
          .read(questRepositoryProvider)
          .accept(candidate, now: now, durationDays: durationDays);
      _ref.read(questsProvider.notifier).refresh();

      await _recomputeAndPersist(
        now: now,
        before: before,
        beforeQuestIds: beforeQuestIds,
      );
      return quest;
    });
  }

  /// Expires quests whose `endDate` has passed and recomputes everything
  /// downstream — unlike a simple time-driven flip, this can itself grant
  /// XP: a `budgetLimit` quest resolves to `completed` (never `expired`)
  /// right here, per [QuestRepository.expireOverdueQuests]. Skipping the
  /// recompute after calling that directly (as `quests_screen.dart` used
  /// to, on screen open) left that reward stranded in the quests box,
  /// invisible in the profile's XP until the next app restart happened to
  /// run `repairGamificationState`. `main.dart`'s boot sequence still calls
  /// [QuestRepository.expireOverdueQuests] directly, which is fine there
  /// only because `repairGamificationState` always runs immediately after
  /// in the same sequence; any mid-session caller must use this instead.
  Future<void> expireOverdueQuests() {
    return _enqueue(() async {
      final now = DateTime.now();
      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError(
          'expireOverdueQuests attempted before a profile exists',
        );
      }
      final anyChanged = await _ref
          .read(questRepositoryProvider)
          .expireOverdueQuests(now: now);
      // No-op on the common case where nothing was actually overdue — the
      // recompute below is real disk I/O the app has no reason to pay for
      // every time the Quests screen just happens to open.
      if (!anyChanged) return;

      final beforeQuestIds = _completedQuestIds();
      _ref.read(questsProvider.notifier).refresh();

      await _recomputeAndPersist(
        now: now,
        before: before,
        beforeQuestIds: beforeQuestIds,
      );
    });
  }

  /// Turns due recurring rules into real transactions and recomputes
  /// everything downstream. `main.dart`'s boot sequence calls
  /// [RecurringTransactionRepository.materializeDue] directly instead,
  /// which is only safe there because `repairGamificationState` always runs
  /// immediately after — this is the version any future mid-session caller
  /// (a manual refresh action, say) must use instead.
  Future<void> materializeRecurring() {
    return _enqueue(() async {
      final now = DateTime.now();
      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError(
          'materializeRecurring attempted before a profile exists',
        );
      }
      final beforeQuestIds = _completedQuestIds();

      await _ref
          .read(recurringTransactionRepositoryProvider)
          .materializeDue(now: now);
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(recurringTransactionsProvider.notifier).refresh();

      await _recomputeAndPersist(
        now: now,
        before: before,
        beforeQuestIds: beforeQuestIds,
      );
    });
  }

  /// Rewrites [oldName] to [newName] across every transaction and recurring
  /// rule that references it, then recomputes downstream state.
  ///
  /// `Transaction.category` and `RecurringTransaction.category` are both
  /// denormalized strings (PRD design) — renaming a category in Profile >
  /// Manage categories otherwise leaves every past row, and every future
  /// occurrence a recurring rule generates, still pointing at the old name.
  /// Routed through the orchestrator (not the repositories directly)
  /// because a category rename can change what an active `categoryAvoid`/
  /// `budgetLimit` quest sees when it filters transactions by category —
  /// without the recompute here, such a quest would stay wrong until
  /// whatever the next unrelated mutation happened to be.
  Future<void> renameCategory(String oldName, String newName) {
    return _enqueue(() async {
      final now = DateTime.now();
      final before = _ref.read(profileProvider);
      if (before == null) {
        throw StateError('renameCategory attempted before a profile exists');
      }
      final beforeQuestIds = _completedQuestIds();

      await _ref
          .read(transactionRepositoryProvider)
          .renameCategory(oldName, newName);
      await _ref
          .read(recurringTransactionRepositoryProvider)
          .renameCategory(oldName, newName);
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(recurringTransactionsProvider.notifier).refresh();

      await _recomputeAndPersist(
        now: now,
        before: before,
        beforeQuestIds: beforeQuestIds,
      );
    });
  }

  /// Runs [change] against the box, then recomputes and persists everything
  /// downstream of the transaction list. Callers must already be running
  /// inside [_enqueue] — this does no serialisation of its own.
  Future<LogTransactionResult> _mutate(
    Future<Transaction?> Function(TransactionRepository repo) change,
  ) async {
    final now = DateTime.now();
    final transactionRepo = _ref.read(transactionRepositoryProvider);

    final before = _ref.read(profileProvider);
    if (before == null) {
      throw StateError(
        'transaction mutation attempted before a profile exists',
      );
    }
    final beforeQuestIds = _completedQuestIds();

    final touched = await change(transactionRepo);
    _ref.read(transactionsProvider.notifier).refresh();

    final outcome = await _recomputeAndPersist(
      now: now,
      before: before,
      beforeQuestIds: beforeQuestIds,
    );

    return LogTransactionResult(
      transaction: touched,
      xpGained: outcome.totals.totalXp - before.currentXP,
      newlyUnlockedBadges: outcome.newlyUnlockedBadges,
      leveledUpTo: outcome.totals.level > before.level
          ? outcome.totals.level
          : null,
      completedQuests: outcome.completedQuests,
      freezeConsumed: outcome.freezeConsumed,
    );
  }

  /// Shared by [_mutate] and [importTransactions]: replays gamification
  /// state from the (already-mutated) transaction list, advances quests,
  /// folds in quest XP, unlocks badges, and persists the profile.
  ///
  /// Step order is load-bearing: badges depend on the replayed level *and*
  /// the replayed quest-completion count, so quests must settle before
  /// badges are evaluated.
  Future<_RecomputeOutcome> _recomputeAndPersist({
    required DateTime now,
    required UserProfile before,
    required Set<String> beforeQuestIds,
  }) async {
    final transactionRepo = _ref.read(transactionRepositoryProvider);
    final profileRepo = _ref.read(profileRepositoryProvider);

    // 1. Replay gamification from the full list.
    final all = _ref.read(transactionsProvider);
    final replay = replayGamification(
      ReplayInput(
        transactions: all,
        joinDate: before.joinDate,
        monthlyBudget: before.monthlyBudget,
        asOf: now,
      ),
    );
    await transactionRepo.writeBackXp(replay.xpByTransactionId);

    // 2. Replay quests (before badges — badges count completions).
    await _replayQuests(
      transactions: all,
      currentStreak: replay.currentStreak,
      asOf: now,
    );

    // 2b. Fold quest-completion XP into the transaction-derived total —
    // must happen after quests have settled, so a quest that just
    // completed this mutation is already counted.
    final totals = combineXpWithQuests(
      transactionXp: replay.totalXp,
      quests: _ref.read(questsProvider),
    );

    // 3. Unlock any newly-eligible badges. Additive only.
    final newlyUnlockedBadges = await _unlockEligibleBadges(
      transactionCount: all.length,
      currentStreak: replay.currentStreak,
      level: totals.level,
      daysUnderBudget: replay.daysUnderBudgetCount,
      now: now,
    );

    // 4. Persist the profile, ratcheting anything that must never regress.
    final updated = before.copyWith(
      currentXP: totals.totalXp,
      level: totals.level,
      currentStreak: replay.currentStreak,
      longestStreak: math.max(before.longestStreak, replay.longestStreakSeen),
      lastLoggedDate: replay.lastLoggedDay ?? before.joinDate,
      streakFreezesLeft: replay.streakFreezesLeft,
      lastFreezeResetDate: replay.lastFreezeResetDate,
      lastBudgetBonusDate: replay.lastBudgetBonusDate,
      daysUnderBudgetCount: replay.daysUnderBudgetCount,
      badgeIds: newlyUnlockedBadges.isEmpty
          ? before.badgeIds
          : [...before.badgeIds, ...newlyUnlockedBadges.map((b) => b.id)],
    );
    await profileRepo.save(updated);
    _ref.read(profileProvider.notifier).setProfile(updated);

    await _syncReminder(updated, replay.lastLoggedDay, now);

    final completedQuests = _ref
        .read(questsProvider)
        .where(
          (q) =>
              q.status == QuestStatus.completed &&
              !beforeQuestIds.contains(q.id),
        )
        .toList(growable: false);

    final freezeConsumed =
        replay.streakFreezesLeft < before.streakFreezesLeft &&
        replay.lastFreezeResetDate == before.lastFreezeResetDate;

    return _RecomputeOutcome(
      totals: totals,
      newlyUnlockedBadges: newlyUnlockedBadges,
      completedQuests: completedQuests,
      freezeConsumed: freezeConsumed,
    );
  }

  Set<String> _completedQuestIds() {
    return _ref
        .read(questsProvider)
        .where((q) => q.status == QuestStatus.completed)
        .map((q) => q.id)
        .toSet();
  }

  Future<void> _replayQuests({
    required List<Transaction> transactions,
    required int currentStreak,
    required DateTime asOf,
  }) async {
    final questRepo = _ref.read(questRepositoryProvider);

    for (final quest in questRepo.getAll()) {
      final update = replayQuest(
        quest: quest,
        transactions: transactions,
        currentStreak: currentStreak,
        asOf: asOf,
      );
      if (quest.currentProgress == update.progress &&
          quest.status == update.status) {
        continue;
      }
      quest.currentProgress = update.progress;
      quest.status = update.status;
      await quest.save();
    }
    _ref.read(questsProvider.notifier).refresh();
  }

  /// Keeps the evening streak reminder consistent with the replayed state.
  /// Deleting today's only transaction has to re-arm the nag it previously
  /// cancelled, or the user silently loses a day.
  Future<void> _syncReminder(
    UserProfile profile,
    DateTime? lastLoggedDay,
    DateTime now,
  ) async {
    if (!profile.remindersEnabled) return;
    final loggedToday = lastLoggedDay != null && isSameDay(lastLoggedDay, now);
    if (loggedToday) {
      await StreakReminderService.instance.cancelToday();
    } else {
      await StreakReminderService.instance.scheduleTonightReminder(
        currentStreak: profile.currentStreak,
      );
    }
  }

  Future<List<BadgeDefinition>> _unlockEligibleBadges({
    required int transactionCount,
    required int currentStreak,
    required int level,
    required int daysUnderBudget,
    required DateTime now,
  }) async {
    final badgeRepo = _ref.read(badgeRepositoryProvider);
    final questRepo = _ref.read(questRepositoryProvider);
    final questsCompleted = questRepo
        .getAll()
        .where((q) => q.status == QuestStatus.completed)
        .length;

    final newlyUnlocked = evaluateNewlyUnlockedBadges(
      transactionCount: transactionCount,
      currentStreak: currentStreak,
      level: level,
      questsCompleted: questsCompleted,
      daysUnderBudget: daysUnderBudget,
      alreadyUnlockedIds: badgeRepo.unlockedIds,
    );

    for (final def in newlyUnlocked) {
      await badgeRepo.unlock(def, now: now);
    }
    if (newlyUnlocked.isNotEmpty) {
      _ref.read(badgesProvider.notifier).refresh();
    }
    return newlyUnlocked;
  }
}

final xpEngineOrchestratorProvider = Provider<XpEngineOrchestrator>((ref) {
  return XpEngineOrchestrator(ref);
});
