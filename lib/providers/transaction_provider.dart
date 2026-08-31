import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../data/transaction_repository.dart';
import '../models/transaction.dart' as model;

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Newest-first. Sorted once here rather than by each consumer — several
/// screens used to independently copy-and-sort the full list on every
/// build (`recentTransactionsProvider` and history's search both used to
/// pay for this per keystroke/build); sorting once per mutation and letting
/// Riverpod cache the result fixes all of them at once.
List<model.Transaction> _newestFirst(List<model.Transaction> transactions) {
  return [...transactions]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

class TransactionsNotifier extends Notifier<List<model.Transaction>> {
  @override
  List<model.Transaction> build() {
    return _newestFirst(ref.watch(transactionRepositoryProvider).getAll());
  }

  void refresh() {
    state = _newestFirst(ref.read(transactionRepositoryProvider).getAll());
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<model.Transaction>>(
      TransactionsNotifier.new,
    );

/// The [n] most recent transactions. Cheap regardless of history size since
/// `transactionsProvider` is already sorted — this just takes a prefix,
/// recomputed only when the transaction list actually changes rather than on
/// every rebuild of whatever widget calls it.
final recentTransactionsProvider =
    Provider.family<List<model.Transaction>, int>((ref, n) {
      return ref.watch(transactionsProvider).take(n).toList(growable: false);
    });

/// How many category names [recentCategoryNamesProvider] returns.
const int kRecentCategoryCount = 5;

/// Category names in most-recently-used order, deduped, capped at
/// [kRecentCategoryCount] — backs the log sheet's "Recent" shortcut row so
/// the common case (the same handful of categories over and over) doesn't
/// need a scroll through the full grid every time.
final recentCategoryNamesProvider =
    Provider.family<List<String>, model.TransactionType>((ref, type) {
      final seen = <String>{};
      final result = <String>[];
      for (final t in ref.watch(transactionsProvider)) {
        if (t.type != type) continue;
        if (seen.add(t.category)) {
          result.add(t.category);
          if (result.length >= kRecentCategoryCount) break;
        }
      }
      return result;
    });

/// Calendar days with at least one logged transaction, truncated to
/// midnight. Backs the streak calendar's day-membership checks.
final loggedDaysProvider = Provider<Set<DateTime>>((ref) {
  return ref
      .watch(transactionsProvider)
      .map((t) => startOfDay(t.timestamp))
      .toSet();
});

/// Total expense amount logged so far this calendar month.
final monthToDateSpendProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(transactionsProvider)
      .where(
        (t) =>
            t.type == model.TransactionType.expense &&
            t.timestamp.year == now.year &&
            t.timestamp.month == now.month,
      )
      .fold(0.0, (sum, t) => sum + t.amount);
});

/// Total expense amount across the entire logged history.
final totalSpentProvider = Provider<double>((ref) {
  return ref
      .watch(transactionsProvider)
      .where((t) => t.type == model.TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final todaysTransactionsProvider = Provider<List<model.Transaction>>((ref) {
  final today = DateTime.now();
  return ref
      .watch(transactionsProvider)
      .where(
        (t) =>
            t.timestamp.year == today.year &&
            t.timestamp.month == today.month &&
            t.timestamp.day == today.day,
      )
      .toList();
});

final todaysSpendProvider = Provider<double>((ref) {
  return ref
      .watch(todaysTransactionsProvider)
      .where((t) => t.type == model.TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
});
