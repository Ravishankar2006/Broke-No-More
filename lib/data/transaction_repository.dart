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

  Future<Transaction> add({
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    required DateTime timestamp,
  }) async {
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
    await _box.put(transaction.id, transaction);
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

  /// Writes every transaction in [transactions] by id, overwriting any
  /// existing row with the same id. Used by CSV import, which resolves
  /// conflicts itself before calling this — the repository doesn't decide
  /// what counts as a conflict.
  Future<void> putAll(Iterable<Transaction> transactions) {
    return _box.putAll({for (final t in transactions) t.id: t});
  }

  /// Wipes every transaction — the JSON backup restore's write path, which
  /// replaces the box wholesale rather than merging.
  Future<void> clear() => _box.clear();

  List<Transaction> forDay(DateTime day) {
    return _box.values.where((t) => isSameDay(t.timestamp, day)).toList();
  }

  /// How many rows currently carry [category] — `category` is a
  /// denormalized string (PRD design), so a rename in Profile > Manage
  /// categories otherwise leaves every past row still pointing at the old
  /// name. Used to ask "rename in N existing transactions too?" before
  /// [renameCategory] actually rewrites them.
  int countForCategory(String category) =>
      _box.values.where((t) => t.category == category).length;

  /// Rewrites every row's `category` from [oldName] to [newName]. Returns
  /// the number of rows touched. A fresh [Transaction] per row, not
  /// in-place mutation — same reasoning as [update]: box-bound instances
  /// are shared with `transactionsProvider`'s state list.
  Future<int> renameCategory(String oldName, String newName) async {
    final matching = _box.values
        .where((t) => t.category == oldName)
        .toList(growable: false);
    if (matching.isEmpty) return 0;

    final renamed = [
      for (final t in matching)
        Transaction(
          id: t.id,
          amount: t.amount,
          type: t.type,
          category: newName,
          note: t.note,
          timestamp: t.timestamp,
          loggedAt: t.loggedAt,
          isQuickLog: t.isQuickLog,
          xpAwarded: t.xpAwarded,
        ),
    ];
    await putAll(renamed);
    return renamed.length;
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
    for (final t in transactions.where(
      (t) => t.type == TransactionType.expense,
    )) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }
}
