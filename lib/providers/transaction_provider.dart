import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../models/transaction.dart' as model;

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class TransactionsNotifier extends Notifier<List<model.Transaction>> {
  @override
  List<model.Transaction> build() {
    return ref.watch(transactionRepositoryProvider).getAll();
  }

  void refresh() {
    state = ref.read(transactionRepositoryProvider).getAll();
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<model.Transaction>>(
  TransactionsNotifier.new,
);

final todaysTransactionsProvider = Provider<List<model.Transaction>>((ref) {
  final today = DateTime.now();
  return ref
      .watch(transactionsProvider)
      .where((t) =>
          t.timestamp.year == today.year &&
          t.timestamp.month == today.month &&
          t.timestamp.day == today.day)
      .toList();
});

final todaysSpendProvider = Provider<double>((ref) {
  return ref
      .watch(todaysTransactionsProvider)
      .where((t) => t.type == model.TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
});
