import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/recurrence_engine.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

const _uuid = Uuid();

class RecurringTransactionRepository {
  Box<RecurringTransaction> get _box =>
      Hive.box<RecurringTransaction>(HiveBoxes.recurringTransactions);

  List<RecurringTransaction> getAll() => _box.values.toList(growable: false);

  Future<RecurringTransaction> add({
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final rule = RecurringTransaction(
      id: _uuid.v4(),
      amount: amount,
      type: type,
      category: category,
      note: note,
      frequency: frequency,
      startDate: startDate,
      nextDueDate: startDate,
      endDate: endDate,
    );
    await _box.put(rule.id, rule);
    return rule;
  }

  /// Editing the schedule (frequency/start date) resets the cursor back to
  /// the new start date — the old cursor position belonged to the old
  /// schedule and carrying it over could skip or repeat occurrences.
  /// Editing everything else (amount, category, note, end date) leaves the
  /// cursor untouched.
  Future<void> update(
    RecurringTransaction rule, {
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final scheduleChanged =
        frequency != rule.frequency || startDate != rule.startDate;
    rule
      ..amount = amount
      ..type = type
      ..category = category
      ..note = note
      ..frequency = frequency
      ..startDate = startDate
      ..endDate = endDate;
    if (scheduleChanged) {
      rule.nextDueDate = startDate;
    }
    await rule.save();
  }

  Future<void> setActive(RecurringTransaction rule, bool isActive) async {
    rule.isActive = isActive;
    await rule.save();
  }

  Future<void> delete(String id) => _box.delete(id);

  /// The one checkpoint (run at app startup, no backend to run this on a
  /// schedule) for turning due recurring rules into real transactions.
  ///
  /// Deliberately runs *before* `repairGamificationState` in `main.dart`:
  /// once new rows land in the transactions box, the full replay that
  /// follows picks them up like any other transaction — no separate XP/
  /// quest/badge recompute needed here.
  Future<void> materializeDue({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final rules = getAll().where((r) => r.isActive).toList();
    if (rules.isEmpty) return;

    final newTransactions = <Transaction>[];
    final touchedRules = <RecurringTransaction>[];

    for (final rule in rules) {
      final result = materializeOccurrences(
        nextDueDate: rule.nextDueDate,
        frequency: rule.frequency,
        now: effectiveNow,
        endDate: rule.endDate,
      );

      for (final due in result.dueDates) {
        newTransactions.add(Transaction(
          id: _uuid.v4(),
          amount: rule.amount,
          type: rule.type,
          category: rule.category,
          note: rule.note,
          timestamp: due,
          // The moment this was actually recorded, not the (possibly
          // long-past) date it conceptually occurred on — same rule
          // TransactionRepository.update follows for a backdated edit.
          loggedAt: effectiveNow,
          // Never a quick log: these weren't logged within 30 minutes of
          // the expense by definition of being auto-generated.
          isQuickLog: false,
        ));
      }

      final reachedEnd =
          rule.endDate != null && result.nextDueDate.isAfter(rule.endDate!);
      if (result.dueDates.isNotEmpty || reachedEnd) {
        rule.nextDueDate = result.nextDueDate;
        if (reachedEnd) rule.isActive = false;
        touchedRules.add(rule);
      }
    }

    if (newTransactions.isNotEmpty) {
      await TransactionRepository().putAll(newTransactions);
    }
    for (final rule in touchedRules) {
      await rule.save();
    }
  }
}
