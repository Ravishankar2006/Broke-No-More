import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/date_helpers.dart';
import '../core/utils/xp_engine.dart';
import '../models/transaction.dart';

const _uuid = Uuid();

class TransactionRepository {
  Box<Transaction> get _box => Hive.box<Transaction>(HiveBoxes.transactions);

  List<Transaction> getAll() => _box.values.toList(growable: false);

  Transaction add({
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required DateTime timestamp,
  }) {
    final now = DateTime.now();
    final transaction = Transaction(
      id: _uuid.v4(),
      amount: amount,
      type: type,
      category: category,
      note: note,
      timestamp: timestamp,
      loggedAt: now,
      isQuickLog: isWithinMinutesOf(timestamp, now, kQuickLogWindowMinutes),
    );
    _box.put(transaction.id, transaction);
    return transaction;
  }

  Transaction? getById(String id) => _box.get(id);

  /// Applies an edit by writing a *fresh* [Transaction] over the same key.
  ///
  /// Deliberately not `transaction.save()` with in-place field mutation, for
  /// three reasons:
  ///   - objects handed out by [getAll] are box-bound and shared with
  ///     `transactionsProvider`'s state list, so mutating one edits the list the
  ///     UI is mid-render against;
  ///   - it destroys the previous values, which an undo action needs;
  ///   - `save()` throws on a detached instance, so passing a copy around later
  ///     would fail at runtime rather than at compile time.
  /// Same rule ProfileRepository.save documents.
  ///
  /// [id] and [loggedAt] are preserved: `loggedAt` records when the user
  /// actually pressed save and is what orders logs within a day for the XP cap.
  ///
  /// `isQuickLog` is recomputed against the original [loggedAt], so backdating
  /// an entry loses the quick-log bonus — the anti-abuse-correct direction.
  Future<Transaction> update(
    Transaction existing, {
    double? amount,
    TransactionType? type,
    String? category,
    String? note,
    bool clearNote = false,
    DateTime? timestamp,
  }) async {
    final newTimestamp = timestamp ?? existing.timestamp;
    final updated = Transaction(
      id: existing.id,
      amount: amount ?? existing.amount,
      type: type ?? existing.type,
      category: category ?? existing.category,
      note: clearNote ? null : (note ?? existing.note),
      timestamp: newTimestamp,
      loggedAt: existing.loggedAt,
      isQuickLog: isWithinMinutesOf(
        newTimestamp,
        existing.loggedAt,
        kQuickLogWindowMinutes,
      ),
      xpAwarded: existing.xpAwarded,
    );
    await _box.put(updated.id, updated);
    return updated;
  }

  /// Writes back the XP a replay attributed to each transaction, touching only
  /// the rows whose value actually changed — appending one transaction usually
  /// dirties exactly one row, so this stays cheap regardless of history size.
  Future<void> writeBackXp(Map<String, int> xpByTransactionId) async {
    for (final entry in xpByTransactionId.entries) {
      final t = _box.get(entry.key);
      if (t == null || t.xpAwarded == entry.value) continue;
      t.xpAwarded = entry.value;
      await t.save();
    }
  }

  Future<void> delete(String id) => _box.delete(id);

  List<Transaction> forDay(DateTime day) {
    return _box.values.where((t) => isSameDay(t.timestamp, day)).toList();
  }

  int countForDay(DateTime day) => forDay(day).length;

  double totalSpentForDay(DateTime day) {
    return forDay(day)
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<Transaction> lastNDays(int n, {DateTime? from}) {
    final end = from ?? DateTime.now();
    final start = startOfDay(end).subtract(Duration(days: n - 1));
    return _box.values
        .where((t) => !startOfDay(t.timestamp).isBefore(start))
        .toList();
  }

  /// Total expense per category over the given transactions.
  Map<String, double> totalsByCategory(List<Transaction> transactions) {
    final totals = <String, double>{};
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }
}
