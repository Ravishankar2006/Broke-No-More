import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/date_helpers.dart';
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
      isQuickLog: isWithinMinutesOf(timestamp, now, 30),
    );
    _box.put(transaction.id, transaction);
    return transaction;
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
