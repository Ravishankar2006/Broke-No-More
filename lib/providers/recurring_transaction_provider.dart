import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recurring_transaction_repository.dart';
import '../models/recurring_transaction.dart';

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
  return RecurringTransactionRepository();
});

class RecurringTransactionsNotifier
    extends Notifier<List<RecurringTransaction>> {
  @override
  List<RecurringTransaction> build() {
    return ref.watch(recurringTransactionRepositoryProvider).getAll();
  }

  void refresh() {
    state = ref.read(recurringTransactionRepositoryProvider).getAll();
  }
}

final recurringTransactionsProvider = NotifierProvider<
    RecurringTransactionsNotifier, List<RecurringTransaction>>(
  RecurringTransactionsNotifier.new,
);
